/* config.h — visionOS build configuration for Fuji-Vision
 *
 * Derived from fuji-foundation's macOS config.h with these changes:
 *   - Removed: MACOSX, ATARI800MACX, NETSIO (macOS-specific)
 *   - Removed: R_IO_DEVICE, R_SERIAL, R_NETWORK (no serial on visionOS)
 *   - Added: VISIONOS 1
 *   - Fixed: stray comment terminators on MONITOR_ASSEMBLER, MONITOR_TRACE, SHOW_DISK_LED
 *
 * This file is found FIRST via HEADER_SEARCH_PATHS ordering so that the
 * portable C core's `#include "config.h"` picks up the visionOS version.
 */

#ifndef CONFIG_H_FUJIVISION
#define CONFIG_H_FUJIVISION

/* ── visionOS platform identifier ──────────────────────────────────────── */
#define VISIONOS 1

/* ATARI800MACX and MACOSX are needed because many C core files (cartridge.h,
 * devices.h, gtia.c, sio.c, etc.) use these guards for features and struct
 * members specific to the Mac port family. Both must be defined for the
 * portable C core to compile with all expected code paths enabled.
 * visionOS-specific behavior diverges via #ifdef VISIONOS where needed. */
#define ATARI800MACX
#define MACOSX

/* ── POSIX / C library feature tests ───────────────────────────────────── */

#define HAVE_MKSTEMP 1
#define HAVE_FDOPEN 1
#define HAVE_VPRINTF 1
#define HAVE_SNPRINTF 1
#define RETSIGTYPE void
#define TIME_WITH_SYS_TIME 1
#define HAVE_TIME 1
#define HAVE_LOCALTIME 1

/* visionOS is always little-endian ARM64 */
#undef WORDS_BIGENDIAN

#define SIZEOF_LONG 4

/* system() is unavailable on visionOS — stub it out via macro.
 * devices.c calls system() unconditionally in its print handler. */
static inline int vision_system_stub(const char *cmd) { (void)cmd; return -1; }
#define system(cmd) vision_system_stub(cmd)

/* Standard POSIX functions available on visionOS */
#define HAVE_GETCWD 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_USLEEP 1
#define HAVE_SELECT 1
#define HAVE_STRNCPY 1
#define HAVE_STRDUP 1
#define HAVE_STRERROR 1
#define HAVE_STRSTR 1
#define HAVE_STRCASECMP 1
#define HAVE_STRTOL 1
#define HAVE_DIRENT_H 1
#define HAVE_TIME_H 1
#define HAVE_RENAME 1
#define HAVE_UNLINK 1
#define HAVE_OPENDIR 1
#define HAVE_MKDIR 1
#define HAVE_RMDIR 1
#define HAVE_FSTAT 1
#define HAVE_STAT 1
#define HAVE_CHMOD 1
/* HAVE_SYSTEM intentionally omitted — system() unavailable on visionOS */
#define HAVE_REWIND 1
#define HAVE_SYS_STAT_H 1
#define HAVE_ERRNO_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_UNISTD_H 1

/* Libraries available */
#define HAVE_LIBM 1
#define HAVE_LIBZ 1

/* ── Unaligned access OK on ARM64 ─────────────────────────────────────── */
#define WORDS_UNALIGNED_OK 1

/* ── Monitor / debugger features ───────────────────────────────────────── */
#undef CRASH_MENU
#define MONITOR_BREAK
#define MONITOR_BREAKPOINTS
#define MONITOR_HINTS 1
#define MONITOR_ASSEMBLER
#define MONITOR_TRACE

/* ── Sound configuration ───────────────────────────────────────────────── */
#define SOUND 1
#define SOUND_GAIN 1
#define VOL_ONLY_SOUND
#define CONSOLE_SOUND
#define SERIO_SOUND
#define INTERPOLATE_SOUND
#define STEREO
#define STEREO_SOUND
#define SYNCHRONIZED_SOUND

/* ── Display configuration ─────────────────────────────────────────────── */
#define SHOW_DISK_LED
#define CYCLE_EXACT
#define NEW_CYCLE_EXACT
#define SIGNED_SAMPLES
#undef PAGED_ATTRIB
#define BITPL_SCR
#define SNAILMETER

/* ── Expansion hardware ────────────────────────────────────────────────── */
#define XEP80_EMULATION
#define AF80
#define AF80_EMULATION
#define BIT3
#define BIT3_EMULATION
#define PBI_MIO
#define PBI_BB
#define ULTIMATE_1MB
#define SIDE2
#define PCLINK
#define EMUOS_ALTIRRA 1

/* ── D: device (hard disk) simulation ──────────────────────────────────── */
#define D_PATCH

/* ── Misc ──────────────────────────────────────────────────────────────── */
#define DONT_USE_RTCONFIGUPDATE
#define monitor Atari_monitor

#endif /* CONFIG_H_FUJIVISION */
