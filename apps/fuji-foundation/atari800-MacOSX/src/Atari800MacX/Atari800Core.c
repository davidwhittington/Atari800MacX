/* Atari800Core.c - C implementation of the Atari800Core public interface.
   Part of Atari800MacX — Phase 2 modernization (emulation core isolation).

   This file is the ONLY C-layer bridge between the macOS GUI (via
   Atari800Engine.m) and the emulation core.  It must not import AppKit,
   Foundation, or any other Objective-C framework header.
*/

#include "Atari800Core.h"

#include <stdlib.h>
#include <string.h>

/* Emulator core headers — C only, no ObjC */
#include "atari.h"
#include "antic.h"
#include "gtia.h"
#include "pia.h"
#include "screen.h"
#include "sio.h"
#include "cartridge.h"
#include "cassette.h"
#include "binload.h"
#include "statesav.h"
#include "akey.h"
#include "mac_diskled.h"
#include "mac_colours.h"
#include "pokeysnd.h"
#include "preferences_c.h"

/* -------------------------------------------------------------------------
   Globals defined in atari_mac_sdl.c that we need to influence.
   The Mac SDL front-end owns these; we reference them as extern here.
   ------------------------------------------------------------------------- */
extern int    sound_enabled;
extern double sound_volume;
extern int    speed_limit;
extern double emulationSpeed;

/* -------------------------------------------------------------------------
   Input state (joystick)
   INPUT_key_code is defined in atari_mac_sdl.c (platform port for the key)
   We declare it extern so we can set it from outside the SDL file.
   ------------------------------------------------------------------------- */
extern int INPUT_key_code;

/* Per-port joystick stick and trigger values.
   PIA_PORT_input and GTIA_TRIG are the hardware registers in pia.c / gtia.c. */
static unsigned char s_stick[4] = {0x0F, 0x0F, 0x0F, 0x0F}; /* centre */
static unsigned char s_trig[4]  = {1, 1, 1, 1};              /* released */

/* -------------------------------------------------------------------------
   Internal ARGB8888 frame buffer.
   Allocated once on first use; 384 × 240 × 4 bytes.
   ------------------------------------------------------------------------- */
#define CORE_FRAME_W  Screen_WIDTH   /* 384 */
#define CORE_FRAME_H  Screen_HEIGHT  /* 240 */

static uint8_t *s_argb_buffer = NULL;

static void ensure_argb_buffer(void)
{
    if (!s_argb_buffer) {
        s_argb_buffer = (uint8_t *)malloc(CORE_FRAME_W * CORE_FRAME_H * 4);
    }
}

/* Convert the emulator's indexed-colour Screen_atari to ARGB8888 using
   colortable[].  colortable[] values are 0x00RRGGBB; we write 0xFFRRGGBB. */
static void convert_screen_to_argb(void)
{
    if (!s_argb_buffer || !Screen_atari) return;

    const unsigned char *src = (const unsigned char *)Screen_atari;
    uint8_t *dst = s_argb_buffer;
    int n = CORE_FRAME_W * CORE_FRAME_H;

    for (int i = 0; i < n; i++) {
        unsigned int rgb = (unsigned int)colortable[src[i]];
        dst[0] = (uint8_t)((rgb >> 16) & 0xFF); /* R */
        dst[1] = (uint8_t)((rgb >>  8) & 0xFF); /* G */
        dst[2] = (uint8_t)( rgb        & 0xFF); /* B */
        dst[3] = 0xFF;                           /* A */
        dst += 4;
    }
}

/* -------------------------------------------------------------------------
   Lifecycle
   ------------------------------------------------------------------------- */

int Atari800Core_Initialize(void)
{
    /* prefsArgc / prefsArgv are built by preferences_c.c before this is
       called.  Atari800_Initialise() parses them to configure ROMs, patches,
       machine type, etc.  It also calls Colours_Initialise() which fills
       colortable[] with the default palette. */
    extern int    prefsArgc;
    extern char  *prefsArgv[];

    int argc = prefsArgc;
    if (!Atari800_Initialise(&argc, prefsArgv)) {
        return 0;
    }

    ensure_argb_buffer();
    return s_argb_buffer ? 1 : 0;
}

void Atari800Core_RunFrame(void)
{
    /* Push the current joystick state into the hardware registers before
       running the frame.  (The SDL front-end does the same thing in its
       main loop just before calling Atari800_Frame().) */
    PIA_PORT_input[0] = (unsigned char)((s_stick[1] << 4) | s_stick[0]);
    PIA_PORT_input[1] = (unsigned char)((s_stick[3] << 4) | s_stick[2]);
    GTIA_TRIG[0] = s_trig[0];
    GTIA_TRIG[1] = s_trig[1];
    GTIA_TRIG[2] = s_trig[2];
    GTIA_TRIG[3] = s_trig[3];

    Atari800_Frame();

    /* Convert the freshly-rendered indexed-colour frame to ARGB8888. */
    convert_screen_to_argb();

    /* Advance the disk LED state machine. */
    LED_Frame();
}

void Atari800Core_WarmReset(void)
{
    Atari800_Warmstart();
}

void Atari800Core_ColdReset(void)
{
    Atari800_Coldstart();
}

void Atari800Core_Shutdown(void)
{
    Atari800_Exit(0);

    free(s_argb_buffer);
    s_argb_buffer = NULL;
}

/* -------------------------------------------------------------------------
   Machine configuration
   ------------------------------------------------------------------------- */

void Atari800Core_SetMachineModel(Atari800Core_MachineModel model)
{
    Atari800_SetMachineType((int)model);
    Atari800_InitialiseMachine();
}

Atari800Core_MachineModel Atari800Core_GetMachineModel(void)
{
    return (Atari800Core_MachineModel)Atari800_machine_type;
}

/* -------------------------------------------------------------------------
   Frame buffer
   ------------------------------------------------------------------------- */

const uint8_t *Atari800Core_GetFrameBuffer(int *outWidth, int *outHeight)
{
    if (outWidth)  *outWidth  = CORE_FRAME_W;
    if (outHeight) *outHeight = CORE_FRAME_H;
    return s_argb_buffer;
}

/* -------------------------------------------------------------------------
   Media — disk drives
   ------------------------------------------------------------------------- */

int Atari800Core_MountDisk(int drive, const char *path)
{
    if (drive < 1 || drive > SIO_MAX_DRIVES) return 0;
    return SIO_Mount(drive, path, 0 /* read-write */);
}

void Atari800Core_UnmountDisk(int drive)
{
    if (drive < 1 || drive > SIO_MAX_DRIVES) return;
    SIO_Dismount(drive);
}

int Atari800Core_IsDiskMounted(int drive)
{
    if (drive < 1 || drive > SIO_MAX_DRIVES) return 0;
    return (SIO_drive_status[drive - 1] != SIO_OFF &&
            SIO_drive_status[drive - 1] != SIO_NO_DISK) ? 1 : 0;
}

const char *Atari800Core_GetDiskPath(int drive)
{
    if (drive < 1 || drive > SIO_MAX_DRIVES) return NULL;
    if (!Atari800Core_IsDiskMounted(drive)) return NULL;
    return SIO_filename[drive - 1];
}

/* -------------------------------------------------------------------------
   Media — cartridge
   ------------------------------------------------------------------------- */

int Atari800Core_InsertCartridge(const char *path)
{
    return CARTRIDGE_InsertAutoReboot(path) >= 0 ? 1 : 0;
}

int Atari800Core_InsertCartridge2(const char *path)
{
    return CARTRIDGE_Insert_Second(path) >= 0 ? 1 : 0;
}

void Atari800Core_RemoveCartridge(void)
{
    CARTRIDGE_RemoveAutoReboot();
}

void Atari800Core_RemoveCartridge2(void)
{
    CARTRIDGE_Remove_Second();
}

/* -------------------------------------------------------------------------
   Media — cassette
   ------------------------------------------------------------------------- */

int Atari800Core_MountCassette(const char *path)
{
    return CASSETTE_Insert(path) ? 1 : 0;
}

void Atari800Core_UnmountCassette(void)
{
    CASSETTE_Remove();
}

/* -------------------------------------------------------------------------
   Media — executables
   ------------------------------------------------------------------------- */

int Atari800Core_LoadExecutable(const char *path)
{
    return BINLOAD_Loader(path) ? 1 : 0;
}

/* -------------------------------------------------------------------------
   Save states
   ------------------------------------------------------------------------- */

int Atari800Core_SaveState(const char *path)
{
    return StateSav_SaveAtariState(path, "wb", 1 /* verbose */) ? 1 : 0;
}

int Atari800Core_LoadState(const char *path)
{
    return StateSav_ReadAtariState(path, "rb") ? 1 : 0;
}

/* -------------------------------------------------------------------------
   Keyboard input
   ------------------------------------------------------------------------- */

void Atari800Core_KeyDown(int akey)
{
    INPUT_key_code = akey;
}

void Atari800Core_KeyUp(void)
{
    INPUT_key_code = AKEY_NONE;
}

/* -------------------------------------------------------------------------
   Joystick input
   ------------------------------------------------------------------------- */

void Atari800Core_JoystickUpdate(int port,
                                  Atari800Core_JoyDirection direction,
                                  int fire)
{
    if (port < 0 || port > 3) return;
    s_stick[port] = (unsigned char)(direction & 0x0F);
    s_trig[port]  = fire ? 0 : 1; /* 0 = pressed, 1 = released in GTIA */
}

/* -------------------------------------------------------------------------
   Console keys — delegate to INPUT_key_consol in atari_mac_sdl.c
   (declared extern; the SDL main loop reads it each frame)
   ------------------------------------------------------------------------- */

extern int INPUT_key_consol;

void Atari800Core_ConsoleKeyDown(int key)
{
    /* key is an AKEY_* constant; map to a consol bit-clear */
    (void)key; /* forwarded via INPUT_key_code in the existing SDL layer */
    INPUT_key_code = key;
}

void Atari800Core_ConsoleKeyUp(int key)
{
    (void)key;
    INPUT_key_code = AKEY_NONE;
}

/* -------------------------------------------------------------------------
   Speed / throttle
   ------------------------------------------------------------------------- */

void Atari800Core_SetSpeed(double multiplier)
{
    emulationSpeed = multiplier;
}

void Atari800Core_SetSpeedLimitEnabled(int enabled)
{
    speed_limit = enabled ? 1 : 0;
}

/* -------------------------------------------------------------------------
   Audio
   ------------------------------------------------------------------------- */

void Atari800Core_SetAudioEnabled(int enabled)
{
    sound_enabled = enabled ? 1 : 0;
}

void Atari800Core_SetAudioVolume(double volume)
{
    sound_volume = volume;
}

void Atari800Core_SetStereoEnabled(int enabled)
{
    POKEYSND_stereo_enabled = enabled ? 1 : 0;
}

/* -------------------------------------------------------------------------
   Display
   ------------------------------------------------------------------------- */

void Atari800Core_SetTVMode(int mode)
{
    Atari800_SetTVMode(mode == 1 ? Atari800_TV_PAL : Atari800_TV_NTSC);
}

void Atari800Core_SetArtifactingMode(int mode)
{
    ANTIC_artif_mode = mode;
    ANTIC_UpdateArtifacting();
}

/* -------------------------------------------------------------------------
   Preferences bridge
   ------------------------------------------------------------------------- */

void Atari800Core_ApplyPreferences(void)
{
    commitPrefs();
}

/* -------------------------------------------------------------------------
   Disk LED query
   ------------------------------------------------------------------------- */

int Atari800Core_GetDiskLEDStatus(void)
{
    return led_status;
}

int Atari800Core_GetDiskLEDSector(void)
{
    return led_sector;
}
