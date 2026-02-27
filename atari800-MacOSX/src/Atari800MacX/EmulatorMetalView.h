/* EmulatorMetalView.h
 * Phase 5: MTKView-based Metal renderer for Atari800MacX.
 *
 * The ObjC class is the MTKView subclass that owns the Metal pipeline.
 * The C bridge functions below are called from the plain-C file atari_mac_sdl.c.
 */

#pragma once

/* ── Objective-C interface ──────────────────────────────────────────────── */

#ifdef __OBJC__
#import <MetalKit/MetalKit.h>

@interface EmulatorMetalView : MTKView <MTKViewDelegate>

/** Toggle CRT-style scanline darkening (every other output row dims to 70%). */
@property (nonatomic) BOOL scanlinesEnabled;

/**
 * Upload a new Atari frame and render it immediately (synchronous).
 *
 * @param pixels  BGRA8 pixel data, srcW × srcH packed rows (no padding).
 * @param srcW    Width of the Atari frame in pixels.
 * @param srcH    Height of the Atari frame in pixels.
 * @param quadL   NDC left   edge of the rendered quad (-1 = left of drawable).
 * @param quadB   NDC bottom edge of the rendered quad (-1 = bottom of drawable).
 * @param quadR   NDC right  edge of the rendered quad (+1 = right of drawable).
 * @param quadT   NDC top    edge of the rendered quad (+1 = top of drawable).
 */
- (void)presentPixels:(const unsigned int *)pixels
                srcW:(int)srcW srcH:(int)srcH
               quadL:(float)quadL quadB:(float)quadB
               quadR:(float)quadR quadT:(float)quadT;

@end

#endif  /* __OBJC__ */

/* ── C-callable bridge (used from atari_mac_sdl.c) ───────────────────────
 *
 * These wrap the ObjC class in plain-C so that atari_mac_sdl.c (compiled as
 * C, not ObjC) can call them.  The pattern mirrors Atari800Window.h.
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Create the EmulatorMetalView and install it as the NSWindow's contentView.
 * Call once after Atari800WindowCreate().
 *
 * @param nsWindow  The NSWindow* obtained via SDL_GetWindowWMInfo (cast to void*).
 * @param w         Initial window width  in points.
 * @param h         Initial window height in points.
 */
void Mac_MetalViewCreate(void *nsWindow, int w, int h);

/**
 * Upload a new frame and present it.  Called every emulator frame from
 * Atari_DisplayScreen() in atari_mac_sdl.c.
 *
 * @param pixels        BGRA8 pixel data (MetalFrameBuffer), srcW × srcH.
 * @param srcW / srcH   Atari screen dimensions for this frame.
 * @param quadL/B/R/T   NDC quad bounds — (-1,-1,1,1) fills the entire view.
 */
void Mac_MetalPresent(const unsigned int *pixels,
                      int srcW, int srcH,
                      float quadL, float quadB,
                      float quadR, float quadT);

/** Enable (1) or disable (0) scanline darkening. */
void Mac_MetalSetScanlines(int enabled);

/** Destroy the view (called on app shutdown). */
void Mac_MetalViewDestroy(void);

#ifdef __cplusplus
}
#endif
