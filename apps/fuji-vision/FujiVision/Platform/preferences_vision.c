/* preferences_vision.c — visionOS replacement for preferences_c.c
 *
 * The macOS preferences_c.c is deeply tied to SDL (keyboard scancodes,
 * joystick mappings) and ObjC callbacks (ReturnPreferences, SaveMedia).
 * This file provides the same interface (getPrefStorage, commitPrefs, etc.)
 * with sensible defaults for visionOS, without any SDL dependency.
 *
 * preferences_c.h declares the ATARI800MACX_PREF struct and function prototypes.
 * Atari800Core.c calls commitPrefs() and getPrefStorage().
 */

#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "atari.h"
#include "cartridge.h"
#include "cassette.h"
#include "cfg.h"
#include "input.h"
#include "memory.h"
#include "pokeysnd.h"
#include "preferences_c.h"
#include "sio.h"
#include "xep80.h"
#include "af80.h"
#include "bit3.h"
#include "esc.h"
#include "rdevice.h"
#include "pbi_bb.h"
#include "pbi_mio.h"
#include "pclink.h"
#include "ultimate1mb.h"
#include "side2.h"
#include "binload.h"

/* ── Globals referenced by Atari800Core.c ──────────────────────────────── */

/* NOTE: prefsArgc / prefsArgv are defined in atari_vision.c to avoid
 * duplicate symbols. They are declared extern here. */
extern int   prefsArgc;
extern char *prefsArgv[];

/* Prefs storage flag */
int clearCurrentMedia = 0;

extern int useBuiltinPalette;
extern int adjustPalette;
extern int paletteBlack;
extern int paletteWhite;
extern int paletteIntensity;
extern int paletteColorShift;
extern int sound_enabled;
extern double sound_volume;
extern int speed_limit;
extern double emulationSpeed;

/* Devices path for H: drive (referenced by devices.c) */
extern char Devices_h_exe_path[];

/* ── Static prefs struct with sensible defaults ────────────────────────── */

static ATARI800MACX_PREF prefs;
static int prefs_initialized = 0;

static void init_default_prefs(void)
{
    if (prefs_initialized) return;
    memset(&prefs, 0, sizeof(prefs));

    /* Display defaults */
    prefs.scaleFactor = 2;
    prefs.scaleFactorFloat = 2.0;
    prefs.widthMode = 1;     /* DEFAULT_WIDTH_MODE */
    prefs.scaleMode = 0;     /* NORMAL_SCALE */
    prefs.tvMode = 0;        /* NTSC */
    prefs.refreshRatio = 1;
    prefs.spriteCollisions = 1;
    prefs.artifactingMode = 0;
    prefs.useBuiltinPalette = 1;
    prefs.blackLevel = 0;
    prefs.whiteLevel = 0xf0;
    prefs.intensity = 80;
    prefs.colorShift = 40;
    prefs.showFPS = 0;
    prefs.scanlineTransparency = 0.9;

    /* Machine defaults — XL/XE */
    prefs.atariType = 1;  /* Atari800_MACHINE_XLXE */
    prefs.disableBasic = 1;

    /* Sound defaults */
    prefs.enableSound = 1;
    prefs.soundVolume = 1.0;
    prefs.enableStereo = 0;
    prefs.enable16BitSound = 1;
    prefs.enableConsoleSound = 1;
    prefs.enableSerioSound = 1;

    /* Speed */
    prefs.speedLimit = 1;
    prefs.emulationSpeed = 1.0;

    /* SIO patches */
    prefs.enableSioPatch = 1;

    /* ROM defaults — use built-in Altirra ROMs */
    prefs.useAltirraOSBRom = 1;
    prefs.useAltirraXLRom = 1;
    prefs.useAltirraBasicRom = 1;
    prefs.useAltirra5200Rom = 1;
    prefs.useAltirra1200XLRom = 1;
    prefs.useAltirraXEGSRom = 1;

    prefs_initialized = 1;
}

/* ── Public API (matches preferences_c.h) ──────────────────────────────── */

ATARI800MACX_PREF *getPrefStorage(void)
{
    init_default_prefs();
    return &prefs;
}

void commitPrefs(void)
{
    init_default_prefs();

    /* Build argc/argv from the current prefs struct.
     * This mirrors what the macOS preferences_c.c does — it constructs
     * command-line-style arguments that Atari800_Initialise() parses. */
    prefsArgc = 0;
    prefsArgv[prefsArgc++] = "FujiVision";

    /* Machine type */
    switch (prefs.atariType) {
        case 0: prefsArgv[prefsArgc++] = "-atari"; break;
        case 1: prefsArgv[prefsArgc++] = "-xl"; break;
        case 2: prefsArgv[prefsArgc++] = "-5200"; break;
    }

    /* TV mode */
    if (prefs.tvMode == 1)
        prefsArgv[prefsArgc++] = "-pal";
    else
        prefsArgv[prefsArgc++] = "-ntsc";

    /* Use Altirra built-in ROMs */
    if (prefs.useAltirraOSBRom)
        prefsArgv[prefsArgc++] = "-atari-osb-builtin";
    if (prefs.useAltirraXLRom)
        prefsArgv[prefsArgc++] = "-atari-xlxe-builtin";
    if (prefs.useAltirraBasicRom)
        prefsArgv[prefsArgc++] = "-basic-builtin";
    if (prefs.useAltirra5200Rom)
        prefsArgv[prefsArgc++] = "-5200-builtin";

    /* Disable BASIC */
    if (prefs.disableBasic)
        prefsArgv[prefsArgc++] = "-nobasic";

    /* SIO patch */
    if (prefs.enableSioPatch)
        prefsArgv[prefsArgc++] = "-hreadonly";

    /* Apply globals */
    sound_enabled = prefs.enableSound;
    sound_volume = prefs.soundVolume;
    speed_limit = prefs.speedLimit;
    emulationSpeed = prefs.emulationSpeed;
}

void saveMediaPrefs(void)
{
    /* No persistent media prefs on visionOS yet (Phase V6) */
}

void savePrefs(void)
{
    /* No persistent prefs on visionOS yet (Phase V6) */
}
