/* FujiVision-Bridging-Header.h — Imports C headers into Swift
 *
 * This bridging header exposes the C emulation core API and the
 * visionOS platform bridge to Swift. No Objective-C layer is needed;
 * Swift calls C functions directly through this header.
 *
 * Build setting: SWIFT_OBJC_BRIDGING_HEADER = FujiVision/FujiVision-Bridging-Header.h
 */

#ifndef FUJIVISION_BRIDGING_HEADER_H
#define FUJIVISION_BRIDGING_HEADER_H

/* Core emulation API — lifecycle, media, input, display, audio */
#import "Atari800Core.h"

/* visionOS platform bridge — frame callback, sound ring buffer, thread control */
#import "platform_bridge.h"

/* Atari key constants (AKEY_NONE, AKEY_RETURN, etc.) */
#import "akey.h"

#endif /* FUJIVISION_BRIDGING_HEADER_H */
