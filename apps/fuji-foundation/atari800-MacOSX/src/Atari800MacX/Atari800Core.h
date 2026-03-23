/* Atari800Core.h - Public C interface between the emulation core and the macOS GUI layer.
   Part of Atari800MacX — Phase 2 modernization (emulation core isolation).

   RULES:
     - GUI code (Objective-C / Swift) must only call functions declared in this file.
     - The emulation core (C) must never import AppKit, Foundation, or Cocoa headers.
     - All cross-boundary calls go through this header.

   THREADING:
     - Atari800Core_RunFrame() is called from the dedicated emulation thread (~60 Hz).
     - All other functions must be called from the main thread unless noted otherwise.
     - The frame buffer accessors are thread-safe via internal double-buffering.
*/

#ifndef ATARI800CORE_H_
#define ATARI800CORE_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------
   Machine models (mirrors Atari800_MACHINE_* in atari.h without exposing it)
   ------------------------------------------------------------------------- */

typedef enum {
    Atari800Core_Model800   = 0,   /* Atari 400/800                    */
    Atari800Core_ModelXLXE  = 1,   /* Atari 600XL / 800XL / 130XE etc. */
    Atari800Core_Model5200  = 2,   /* Atari 5200 SuperSystem            */
} Atari800Core_MachineModel;

/* -------------------------------------------------------------------------
   Lifecycle
   ------------------------------------------------------------------------- */

/* Initialize the emulation core. Must be called once on the main thread before
   any other Atari800Core_* function. Returns 1 on success, 0 on failure. */
int Atari800Core_Initialize(void);

/* Run a single emulated frame. Called from the emulation thread at ~60 Hz.
   After this returns, the front frame buffer is ready for display. */
void Atari800Core_RunFrame(void);

/* Warm-reset the emulated machine (equivalent to pressing the Reset button). */
void Atari800Core_WarmReset(void);

/* Cold-reset the emulated machine (equivalent to power-cycling). */
void Atari800Core_ColdReset(void);

/* Shut down the emulation core cleanly. Must be called before process exit. */
void Atari800Core_Shutdown(void);

/* -------------------------------------------------------------------------
   Machine configuration
   ------------------------------------------------------------------------- */

/* Set the machine model. Takes effect on the next cold reset. */
void Atari800Core_SetMachineModel(Atari800Core_MachineModel model);

/* Query the currently active machine model. */
Atari800Core_MachineModel Atari800Core_GetMachineModel(void);

/* -------------------------------------------------------------------------
   Frame buffer — display output
   ------------------------------------------------------------------------- */

/* Returns a pointer to the most-recently-completed ARGB8888 pixel buffer.
   Width and height are written to *outWidth and *outHeight.
   This pointer is valid until the next call to Atari800Core_RunFrame().
   Safe to call from the display/render thread immediately after RunFrame. */
const uint8_t *Atari800Core_GetFrameBuffer(int *outWidth, int *outHeight);

/* -------------------------------------------------------------------------
   Media — disk drives (D1:–D8:)
   ------------------------------------------------------------------------- */

/* Mount a disk image file into drive slot (1–8).
   Returns 1 on success, 0 on failure (file not found, bad format, etc.). */
int Atari800Core_MountDisk(int drive, const char *path);

/* Unmount the disk currently in drive slot (1–8). */
void Atari800Core_UnmountDisk(int drive);

/* Returns 1 if drive slot (1–8) has a disk mounted, 0 otherwise. */
int Atari800Core_IsDiskMounted(int drive);

/* Returns the path of the image mounted in drive slot (1–8), or NULL if empty.
   The returned pointer is owned by the core; do not free it. */
const char *Atari800Core_GetDiskPath(int drive);

/* -------------------------------------------------------------------------
   Media — cartridge
   ------------------------------------------------------------------------- */

/* Insert a cartridge image. Returns 1 on success, 0 on failure. */
int Atari800Core_InsertCartridge(const char *path);

/* Insert a second (pass-through) cartridge. Returns 1 on success. */
int Atari800Core_InsertCartridge2(const char *path);

/* Remove the currently inserted cartridge. */
void Atari800Core_RemoveCartridge(void);

/* Remove the second cartridge. */
void Atari800Core_RemoveCartridge2(void);

/* -------------------------------------------------------------------------
   Media — cassette
   ------------------------------------------------------------------------- */

/* Mount a cassette image. Returns 1 on success. */
int Atari800Core_MountCassette(const char *path);

/* Unmount the cassette. */
void Atari800Core_UnmountCassette(void);

/* -------------------------------------------------------------------------
   Media — executables
   ------------------------------------------------------------------------- */

/* Load and run an Atari executable (.xex/.com/.exe). Returns 1 on success. */
int Atari800Core_LoadExecutable(const char *path);

/* -------------------------------------------------------------------------
   Save states
   ------------------------------------------------------------------------- */

/* Save the current machine state to a file. Returns 1 on success. */
int Atari800Core_SaveState(const char *path);

/* Load a previously saved machine state. Returns 1 on success. */
int Atari800Core_LoadState(const char *path);

/* -------------------------------------------------------------------------
   Keyboard input

   akey values are defined in akey.h (AKEY_* constants from the emulator core).
   The GUI must include akey.h to get these constants.
   ------------------------------------------------------------------------- */

/* Signal a key-down event. akey is an AKEY_* constant from akey.h. */
void Atari800Core_KeyDown(int akey);

/* Signal a key-up event (clears the held key). */
void Atari800Core_KeyUp(void);

/* -------------------------------------------------------------------------
   Joystick / gamepad input

   port: 0–3 (joystick port number)
   direction: bitmask of Atari800Core_JoyDir values
   fire: 1 = button pressed, 0 = released
   ------------------------------------------------------------------------- */

typedef enum {
    Atari800Core_JoyCenter    = 0x0F,
    Atari800Core_JoyUp        = 0x0E,
    Atari800Core_JoyDown      = 0x0D,
    Atari800Core_JoyLeft      = 0x0B,
    Atari800Core_JoyRight     = 0x07,
    Atari800Core_JoyUpLeft    = 0x0A,
    Atari800Core_JoyUpRight   = 0x06,
    Atari800Core_JoyDownLeft  = 0x09,
    Atari800Core_JoyDownRight = 0x05,
} Atari800Core_JoyDirection;

void Atari800Core_JoystickUpdate(int port, Atari800Core_JoyDirection direction, int fire);

/* -------------------------------------------------------------------------
   Console keys (Start, Select, Option, Reset)
   ------------------------------------------------------------------------- */

void Atari800Core_ConsoleKeyDown(int key);   /* key: AKEY_HELP, AKEY_START, etc. */
void Atari800Core_ConsoleKeyUp(int key);

/* -------------------------------------------------------------------------
   Speed / throttle
   ------------------------------------------------------------------------- */

/* Set emulation speed as a multiplier: 1.0 = normal, 2.0 = double, 0.5 = half. */
void Atari800Core_SetSpeed(double multiplier);

/* Enable or disable the speed limiter (1 = limited to ~60fps, 0 = as fast as possible). */
void Atari800Core_SetSpeedLimitEnabled(int enabled);

/* -------------------------------------------------------------------------
   Audio
   ------------------------------------------------------------------------- */

/* Enable or disable audio output. */
void Atari800Core_SetAudioEnabled(int enabled);

/* Set audio volume [0.0, 1.0]. */
void Atari800Core_SetAudioVolume(double volume);

/* Enable or disable POKEY stereo mode. */
void Atari800Core_SetStereoEnabled(int enabled);

/* -------------------------------------------------------------------------
   Display
   ------------------------------------------------------------------------- */

/* TV system: 0 = NTSC, 1 = PAL. Takes effect on next frame. */
void Atari800Core_SetTVMode(int mode);

/* Artifacting mode [0–n], values correspond to the ArtifactingMode preference.
   0 = none, higher values = different NTSC artifact emulation modes. */
void Atari800Core_SetArtifactingMode(int mode);

/* -------------------------------------------------------------------------
   Preferences bridge — batch apply from ATARI800MACX_PREF struct

   These are provided for compatibility with the existing Preferences system.
   They delegate to the commitPrefs() / getPrefStorage() C functions already
   defined in preferences_c.h. New code should call individual setters above.
   ------------------------------------------------------------------------- */
#include "preferences_c.h"

/* Apply all settings from the preference struct to the live emulator state.
   Wraps the existing commitPrefs() function. */
void Atari800Core_ApplyPreferences(void);

/* -------------------------------------------------------------------------
   Disk activity LED query (for GUI status display)

   These mirror mac_diskled.h but provide a typed interface for GUI callers.
   ------------------------------------------------------------------------- */

/* Returns the current LED status (0 = off, 1–9 = read, 10–18 = write).
   Corresponds to led_status in mac_diskled.h. */
int Atari800Core_GetDiskLEDStatus(void);

/* Returns the current sector number being accessed (>0 when active). */
int Atari800Core_GetDiskLEDSector(void);

#ifdef __cplusplus
}
#endif

#endif /* ATARI800CORE_H_ */
