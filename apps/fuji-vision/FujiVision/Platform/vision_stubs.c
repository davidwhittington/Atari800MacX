/* vision_stubs.c — Stub implementations for macOS-specific symbols
 *
 * The C core and bridge files reference functions and variables normally
 * defined in macOS Objective-C files (ControlManager.m, DisplayManager.m,
 * MediaManager.m, atari_mac_sdl.c, etc.). This file provides no-op stubs
 * so the visionOS port links without those files.
 *
 * Each stub is annotated with the source file that normally provides it.
 */

#include "config.h"
#include <stdio.h>
#include "atari.h"
#include "cartridge.h"

/* ── From atari_mac_sdl.c ─────────────────────────────────────────────── */

/* Called by atari.c Atari800_Warmstart — checks if Help key is pressed */
int Atari_Help_Key_Pressed(void)
{
    return 0;  /* No Help key on visionOS */
}

/* Called by atari.c — flag for Help function key state */
int helpFunctionPressed = 0;

/* Called by emuio.c — flag for speed limit change requests */
int requestLimitChange = 0;

/* Called by esc.c — FujiNet WiFi adapter emulation flag */
int fujinet_enabled = 0;

/* Called by atari.c Atari800_Warmstart — resets capslock tracking */
void MacCapsLockStateReset(void)
{
    /* No-op: no physical capslock on visionOS */
}

/* Called by atari.c Atari800_Warmstart — resets sound subsystem */
void MacSoundReset(void)
{
    /* No-op: sound reset handled by Vision_Sound_Reset() */
}

/* Called by ultimate1mb.c — updates window title with machine info */
void CreateWindowCaption(void)
{
    /* No-op: visionOS uses SwiftUI title, not window caption */
}

/* Called by preferences_c.h/Atari800Core.c — loads preferences */
int loadMacPrefs(int firstTime)
{
    (void)firstTime;
    /* Preferences loaded via commitPrefs() in preferences_vision.c */
    return 1;  /* success */
}

/* ── From ControlManager.m ────────────────────────────────────────────── */

/* Called by log.c — prints a message to the control/debug console */
void ControlManagerMessagePrint(char *string)
{
    /* Route to stdout for now; Phase V6 could display in SwiftUI */
    if (string)
        printf("[Atari800] %s", string);
}

/* ── From MediaManager.m ──────────────────────────────────────────────── */

/* Called by atari.c — lets user select cartridge type for ambiguous files */
int MediaManagerCartSelect(int nKbytes)
{
    (void)nKbytes;
    /* Auto-detect: return 0 to use first matching type */
    return 0;
}

/* Called by cartridge.c — prompts user to save dirty cartridge image */
int MediaManagerDirtyCartridgeSave(CARTRIDGE_image_t *cart)
{
    (void)cart;
    /* Don't save on visionOS — cartridge images are read-only */
    return 0;
}

/* ── From DisplayManager.m ────────────────────────────────────────────── */

/* Called by af80.c — disables AF80 80-column display mode */
void SetDisplayManagerDisableAF80(void)
{
    /* No-op: visionOS rendering handles display modes uniformly */
}

/* Called by bit3.c — disables Bit3 80-column display mode */
void SetDisplayManagerDisableBit3(void)
{
    /* No-op: visionOS rendering handles display modes uniformly */
}

/* ── From input.c / atari_mac_sdl.c ──────────────────────────────────── */

/* Called by pokey.c every scanline — handles light pen/gun input */
void INPUT_Scanline(void)
{
    /* No-op: no light pen/gun on visionOS */
}

/* Called by pia.c — selects active joystick in multijoy mode */
void INPUT_SelectMultiJoy(int no)
{
    (void)no;
    /* No-op: multijoy not supported on visionOS */
}

/* ── From BreakpointsController.m (mac_monitor.c dependencies) ──────── */

/* Called by mac_monitor.c — maps condition number to breakpoint index */
int BreakpointsControllerGetBreakpointNumForConditionNum(int condNum)
{
    (void)condNum;
    return -1;  /* No breakpoint GUI on visionOS */
}

/* Called by mac_monitor.c — marks breakpoint table as needing refresh */
void BreakpointsControllerSetDirty(void)
{
    /* No-op: no breakpoint GUI on visionOS */
}

/* ── From ControlManager.m (additional functions) ─────────────────────── */

/* Called by mac_monitor.c — shows dual-panel error dialog */
void ControlManagerDualError(char *msg1, char *msg2)
{
    (void)msg1;
    (void)msg2;
    /* No-op: no error dialog on visionOS */
}

/* Called by mac_monitor.c — printf to monitor console */
void ControlManagerMonitorPrintf(const char *fmt, ...)
{
    (void)fmt;
    /* No-op: no monitor console on visionOS */
}

/* Called by mac_monitor.c — marks label table as needing refresh */
void ControlManagerMonitorSetLabelsDirty(void)
{
    /* No-op: no monitor GUI on visionOS */
}

/* ── From AppKit (NSBeep) ─────────────────────────────────────────────── */

/* Called by mac_monitor.c — plays system beep sound */
void NSBeep(void)
{
    /* No-op: no system beep on visionOS */
}
