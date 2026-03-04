/* platform_bridge.h — C↔Swift callback declarations for Fuji-Vision
 *
 * This header defines the interface between the C emulation thread and
 * the Swift UI/rendering layer. Both sides include this header:
 *   - C code includes it directly
 *   - Swift imports it via FujiVision-Bridging-Header.h
 *
 * THREADING:
 *   - Functions prefixed Vision_Platform_ are called FROM the C emulation thread.
 *   - Functions prefixed Vision_Input_ are called FROM the Swift main thread.
 *   - The sound ring buffer is lock-free (single producer, single consumer).
 */

#ifndef PLATFORM_BRIDGE_H
#define PLATFORM_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ── Frame delivery (C → Swift) ────────────────────────────────────────── */

/* Called by PLATFORM_DisplayScreen() after each emulated frame.
 * pixels: ARGB8888 data from Atari800Core_GetFrameBuffer()
 * width/height: frame dimensions (typically 384x240)
 * Implemented in Swift (EmulatorSession). */
typedef void (*VisionFrameReadyCallback)(const uint8_t *pixels, int width, int height);

/* Register the Swift-side frame callback. Called once during init. */
void Vision_Platform_SetFrameCallback(VisionFrameReadyCallback callback);

/* ── Sound ring buffer (C emulation thread → AVAudioEngine render thread) ─ */

/* Ring buffer capacity in bytes. Must be power of 2.
 * 16384 bytes = ~185ms at 44100 Hz stereo 16-bit. */
#define VISION_SOUND_BUFFER_SIZE  16384

/* Write audio samples into the ring buffer. Called from Sound_Update()
 * on the emulation thread. Returns number of bytes actually written. */
int Vision_Sound_Write(const uint8_t *data, int nbytes);

/* Read audio samples from the ring buffer. Called from AVAudioSourceNode
 * render callback on the audio thread. Returns number of bytes read. */
int Vision_Sound_Read(uint8_t *dest, int nbytes);

/* Query how many bytes are available for reading. */
int Vision_Sound_Available(void);

/* Reset the ring buffer (flush all data). */
void Vision_Sound_Reset(void);

/* ── Emulation thread control (Swift → C) ──────────────────────────────── */

/* Start/stop the emulation thread. Implemented in atari_vision.c. */
void Vision_Emulation_Start(void);
void Vision_Emulation_Stop(void);
int  Vision_Emulation_IsRunning(void);

/* ── Speed adjustment for synchronized sound ───────────────────────────── */

/* Returns the current audio gap estimate for PLATFORM_AdjustSpeed().
 * The AVAudioEngine callback updates this value each time it fires. */
void Vision_Sound_SetCallbackTick(uint32_t tick);
uint32_t Vision_Sound_GetCallbackTick(void);

#ifdef __cplusplus
}
#endif

#endif /* PLATFORM_BRIDGE_H */
