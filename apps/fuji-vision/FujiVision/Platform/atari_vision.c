/* atari_vision.c — visionOS platform shim for the Atari800 emulation core
 *
 * This file provides all PLATFORM_* functions and extern globals that the
 * portable C core expects from its host platform. It replaces atari_mac_sdl.c
 * (the macOS/SDL platform layer) with a minimal implementation suitable for
 * visionOS, where rendering and audio are handled in Swift via Metal and
 * AVAudioEngine respectively.
 *
 * THREADING MODEL:
 *   - The emulation loop runs on a dedicated pthread (started by Vision_Emulation_Start)
 *   - Frame output goes to Swift via a registered callback
 *   - Sound output goes through a lock-free ring buffer to AVAudioSourceNode
 *   - Input state is written from the Swift main thread (atomic writes)
 *
 * Linked C core files reference these globals as `extern`.
 */

#include "config.h"

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <stdatomic.h>
#include <sys/time.h>
#include <math.h>

/* Emulator core headers */
#include "atari.h"
#include "antic.h"
#include "gtia.h"
#include "pia.h"
#include "input.h"
#include "screen.h"
#include "sound.h"
#include "pokeysnd.h"
#include "akey.h"
#include "sio.h"
#include "colours.h"
#include "log.h"
#include "monitor.h"
#include "platform.h"
#include "ui.h"
#include "Atari800Core.h"
#include "platform_bridge.h"
#include "preferences_c.h"
#include "mac_diskled.h"

/* =========================================================================
   SECTION 1: Globals required by Atari800Core.c and other core files
   ========================================================================= */

/* Sound state — referenced as extern by Atari800Core.c */
int    sound_enabled  = 1;
int    sound_flags    = 0;       /* POKEYSND_BIT16 set in PLATFORM_Initialise */
int    sound_bits     = 16;
double sound_volume   = 1.0;

/* Speed / throttle — referenced as extern by Atari800Core.c */
int    speed_limit     = 1;
double emulationSpeed  = 1.0;
int    pauseEmulator   = 0;

/* Input state — these replace the definitions normally in input.c.
 * The Mac port moves them to the platform file; we do the same. */
int INPUT_key_code   = AKEY_NONE;
int INPUT_key_break  = 0;
int INPUT_key_shift  = 0;
int INPUT_key_consol = INPUT_CONSOL_NONE;  /* 0x07 = all released */

/* Joystick configuration */
int INPUT_joy_autofire[4] = {INPUT_AUTOFIRE_OFF, INPUT_AUTOFIRE_OFF,
                              INPUT_AUTOFIRE_OFF, INPUT_AUTOFIRE_OFF};
int INPUT_joy_block_opposite_directions = 1;
int INPUT_joy_multijoy = 0;

/* 5200 analog joystick */
int INPUT_joy_5200_min    = 6;
int INPUT_joy_5200_center = 114;
int INPUT_joy_5200_max    = 220;

/* Mouse emulation (not used on visionOS, but core references them) */
int INPUT_mouse_mode       = INPUT_MOUSE_OFF;
int INPUT_mouse_port       = 0;
int INPUT_mouse_delta_x    = 0;
int INPUT_mouse_delta_y    = 0;
int INPUT_mouse_buttons    = 0;
int INPUT_mouse_speed      = 3;
int INPUT_mouse_pot_min    = 1;
int INPUT_mouse_pot_max    = 228;
int INPUT_mouse_pen_ofs_h  = 42;
int INPUT_mouse_pen_ofs_v  = 2;
int INPUT_mouse_joy_inertia = 10;
int INPUT_cx85             = 0;
int INPUT_Invert_Axis      = 0;

/* Display globals */
int    full_display       = 3;
int    must_display       = 0;
int    SCALE_MODE         = 0;
int    WIDTH_MODE         = 1;     /* DEFAULT_WIDTH_MODE */
int    PLATFORM_80col     = 0;
int    useBuiltinPalette  = 1;
int    adjustPalette      = 0;
int    paletteBlack       = 0;
int    paletteWhite       = 0xf0;
int    paletteIntensity   = 80;
int    paletteColorShift  = 40;

/* clearCurrentMedia is defined in preferences_vision.c */

/* Request flags — the visionOS port handles most of these through
 * direct Atari800Core_* calls, but the core may reference some. */
int requestPrefsChange = 0;

/* =========================================================================
   SECTION 2: Sound ring buffer (lock-free SPSC)
   ========================================================================= */

static uint8_t  s_sound_buffer[VISION_SOUND_BUFFER_SIZE];
static atomic_int s_sound_write_pos = 0;
static atomic_int s_sound_read_pos  = 0;

/* Callback tick for SYNCHRONIZED_SOUND speed adjustment */
static atomic_uint s_callback_tick = 0;

int Vision_Sound_Write(const uint8_t *data, int nbytes)
{
    int wr = atomic_load_explicit(&s_sound_write_pos, memory_order_relaxed);
    int rd = atomic_load_explicit(&s_sound_read_pos, memory_order_acquire);

    int available = VISION_SOUND_BUFFER_SIZE - ((wr - rd + VISION_SOUND_BUFFER_SIZE)
                                                 & (VISION_SOUND_BUFFER_SIZE - 1)) - 1;
    if (nbytes > available)
        nbytes = available;

    for (int i = 0; i < nbytes; i++) {
        s_sound_buffer[(wr + i) & (VISION_SOUND_BUFFER_SIZE - 1)] = data[i];
    }

    atomic_store_explicit(&s_sound_write_pos,
                          (wr + nbytes) & (VISION_SOUND_BUFFER_SIZE - 1),
                          memory_order_release);
    return nbytes;
}

int Vision_Sound_Read(uint8_t *dest, int nbytes)
{
    int rd = atomic_load_explicit(&s_sound_read_pos, memory_order_relaxed);
    int wr = atomic_load_explicit(&s_sound_write_pos, memory_order_acquire);

    int available = (wr - rd + VISION_SOUND_BUFFER_SIZE)
                    & (VISION_SOUND_BUFFER_SIZE - 1);
    if (nbytes > available)
        nbytes = available;

    for (int i = 0; i < nbytes; i++) {
        dest[i] = s_sound_buffer[(rd + i) & (VISION_SOUND_BUFFER_SIZE - 1)];
    }

    atomic_store_explicit(&s_sound_read_pos,
                          (rd + nbytes) & (VISION_SOUND_BUFFER_SIZE - 1),
                          memory_order_release);
    return nbytes;
}

int Vision_Sound_Available(void)
{
    int wr = atomic_load_explicit(&s_sound_write_pos, memory_order_acquire);
    int rd = atomic_load_explicit(&s_sound_read_pos, memory_order_acquire);
    return (wr - rd + VISION_SOUND_BUFFER_SIZE) & (VISION_SOUND_BUFFER_SIZE - 1);
}

void Vision_Sound_Reset(void)
{
    atomic_store(&s_sound_write_pos, 0);
    atomic_store(&s_sound_read_pos, 0);
}

void Vision_Sound_SetCallbackTick(uint32_t tick)
{
    atomic_store_explicit(&s_callback_tick, tick, memory_order_release);
}

uint32_t Vision_Sound_GetCallbackTick(void)
{
    return atomic_load_explicit(&s_callback_tick, memory_order_acquire);
}

/* =========================================================================
   SECTION 3: Frame delivery callback
   ========================================================================= */

static VisionFrameReadyCallback s_frame_callback = NULL;

void Vision_Platform_SetFrameCallback(VisionFrameReadyCallback callback)
{
    s_frame_callback = callback;
}

/* =========================================================================
   SECTION 4: PLATFORM_* functions (called by the emulation core)
   ========================================================================= */

void PLATFORM_Initialise(int *argc, char *argv[])
{
    (void)argc;
    (void)argv;

    /* Initialize POKEY sound engine */
    sound_flags = POKEYSND_BIT16;
    if (POKEYSND_Init(POKEYSND_FREQ_17_EXACT,
                       44100,
                       1,  /* num_pokeys: 1 for mono, overridden if stereo */
                       sound_flags)) {
        sound_enabled = 1;
    }
}

int PLATFORM_Exit(int run_monitor)
{
    if (run_monitor) {
        /* On visionOS we don't have a text-mode monitor; just return 0 to quit */
        return 0;
    }
    return 0;
}

int PLATFORM_Keyboard(void)
{
    /* INPUT_key_code is set atomically by the Swift input layer */
    return INPUT_key_code;
}

void PLATFORM_DisplayScreen(void)
{
    /* Deliver the frame to the Swift rendering layer */
    if (s_frame_callback) {
        int w, h;
        const uint8_t *pixels = Atari800Core_GetFrameBuffer(&w, &h);
        if (pixels) {
            s_frame_callback(pixels, w, h);
        }
    }
}

int PLATFORM_PORT(int num)
{
    /* Not called — we write PIA_PORT_input[] directly in Atari800Core_RunFrame */
    (void)num;
    return 0xFF;
}

int PLATFORM_TRIG(int num)
{
    /* Not called — we write GTIA_TRIG[] directly in Atari800Core_RunFrame */
    (void)num;
    return 1;
}

void PLATFORM_Switch80Col(void)
{
    PLATFORM_80col = !PLATFORM_80col;
}

#ifdef SYNCHRONIZED_SOUND
double PLATFORM_AdjustSpeed(void)
{
    /* Estimate audio buffer gap to throttle emulation speed.
     * If the ring buffer is getting too full, slow down.
     * If it's getting too empty, speed up slightly. */
    int available = Vision_Sound_Available();
    int target = VISION_SOUND_BUFFER_SIZE / 4;  /* target 25% fill */
    int spread = VISION_SOUND_BUFFER_SIZE / 8;

    if (available > target + spread)
        return 0.95;   /* slow down — buffer too full */
    else if (available < target - spread)
        return 1.05;   /* speed up — buffer draining */
    else
        return 1.0;    /* on target */
}
#endif

/* =========================================================================
   SECTION 5: INPUT_* stubs (replacing input.c implementations)
   ========================================================================= */

/* The Mac port stubs these out because it manages input directly.
 * The visionOS port does the same — input comes from GCController/SwiftUI. */

void INPUT_Frame(void)
{
    /* No-op: joystick state is pushed into PIA/GTIA by Atari800Core_RunFrame */
}

void INPUT_Initialise(int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
}

void INPUT_Exit(void)
{
    /* No-op */
}

void INPUT_DrawMousePointer(void)
{
    /* No-op: no mouse pointer on visionOS */
}

void INPUT_CenterMousePointer(void)
{
    /* No-op */
}

/* =========================================================================
   SECTION 6: Sound_Update (SYNCHRONIZED_SOUND path)
   ========================================================================= */

void Sound_Update(void)
{
    if (!sound_enabled)
        return;

    /* POKEYSND_Process fills a buffer with audio samples.
     * We write them into the ring buffer for AVAudioSourceNode to consume. */
    unsigned int sndbufsize = 44100 / 60;  /* ~735 samples per frame */
    if (POKEYSND_stereo_enabled)
        sndbufsize *= 2;   /* stereo: double the samples */

    unsigned int nbytes = sndbufsize * (sound_bits / 8);
    uint8_t tempbuf[8192];  /* generous temp buffer */

    if (nbytes > sizeof(tempbuf))
        nbytes = sizeof(tempbuf);

    POKEYSND_Process(tempbuf, sndbufsize);

    /* Apply volume scaling */
    if (sound_volume < 1.0 && sound_bits == 16) {
        int16_t *samples = (int16_t *)tempbuf;
        int count = nbytes / 2;
        for (int i = 0; i < count; i++) {
            samples[i] = (int16_t)(samples[i] * sound_volume);
        }
    }

    Vision_Sound_Write(tempbuf, nbytes);
}

/* NOTE: Sound_Pause() and Sound_Continue() are defined in mac_screen.c
 * (as empty stubs). We do NOT redefine them here to avoid duplicate symbols. */

void Sound_Exit(void)
{
    Vision_Sound_Reset();
}

/* =========================================================================
   SECTION 7: Emulation thread management
   ========================================================================= */

static pthread_t s_emu_thread;
static atomic_int s_emu_running = 0;

static void *emulation_thread_func(void *arg)
{
    (void)arg;

    /* Initialize the core */
    if (!Atari800Core_Initialize()) {
        Log_print("Vision: Atari800Core_Initialize() failed");
        atomic_store(&s_emu_running, 0);
        return NULL;
    }

    /* Main emulation loop */
    while (atomic_load(&s_emu_running)) {
        if (!pauseEmulator) {
            Atari800Core_RunFrame();
        } else {
            usleep(16000);  /* ~60Hz idle when paused */
        }

        /* Basic frame timing when speed_limit is on */
        if (speed_limit) {
            usleep(16000);  /* ~60fps — refined by PLATFORM_AdjustSpeed in sync sound */
        }
    }

    Atari800Core_Shutdown();
    return NULL;
}

void Vision_Emulation_Start(void)
{
    if (atomic_load(&s_emu_running))
        return;

    atomic_store(&s_emu_running, 1);
    pthread_create(&s_emu_thread, NULL, emulation_thread_func, NULL);
}

void Vision_Emulation_Stop(void)
{
    if (!atomic_load(&s_emu_running))
        return;

    atomic_store(&s_emu_running, 0);
    pthread_join(s_emu_thread, NULL);
}

int Vision_Emulation_IsRunning(void)
{
    return atomic_load(&s_emu_running);
}

void Vision_Emulation_SetPaused(int paused)
{
    pauseEmulator = paused;
}

int Vision_Emulation_IsPaused(void)
{
    return pauseEmulator;
}

/* =========================================================================
   SECTION 8: Console key helpers (called from Swift)
   ========================================================================= */

void Vision_Input_ConsoleKeyDown(int key)
{
    /* Console keys work by CLEARING bits: 0x07 = all released.
     * key values match INPUT_CONSOL_* masks: 1=Start, 2=Select, 4=Option */
    INPUT_key_consol &= ~key;
}

void Vision_Input_ConsoleKeyUp(int key)
{
    /* Release by SETTING the bit back */
    INPUT_key_consol |= key;
}

/* =========================================================================
   SECTION 9: UI stubs (the core calls UI_* functions we must provide)
   ========================================================================= */

int UI_SelectCartType(int k)
{
    /* On visionOS, auto-detect cart type. Return the suggested type. */
    return k;
}

int UI_Initialise(int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    return TRUE;
}

void UI_Run(void)
{
    /* No-op: UI is handled entirely in SwiftUI */
}

/* =========================================================================
   SECTION 9: Misc stubs for symbols the core references
   ========================================================================= */

/* preferences_c.c references these in the Mac build; provide stubs */
int prefsArgc = 0;
char *prefsArgv[1] = { NULL };

/* mac_screen.c Screen_* globals — the visionOS port links mac_screen.c
 * from fuji-foundation which provides these. If not, uncomment below:
 *
 * ULONG *Screen_atari = NULL;
 * int Screen_visible_x1 = 24;
 * int Screen_visible_y1 = 0;
 * int Screen_visible_x2 = 360;
 * int Screen_visible_y2 = 240;
 */
