/* EmulatorMetalView.m
 * Phase 5: MTKView-based Metal renderer for Atari800MacX.
 *
 * Rendering model
 * ───────────────
 * The emulator runs on the main thread.  Every time PLATFORM_DisplayScreen()
 * fires it calls Mac_MetalPresent(), which:
 *   1. Uploads the new BGRA8 pixel data into a cached MTLTexture.
 *   2. Calls [view draw] for an immediate, synchronous Metal frame submission.
 *
 * The MTKView is set to paused=YES / enableSetNeedsDisplay=NO so it never
 * draws spontaneously — the emulator loop drives all frame output.
 */

#import "EmulatorMetalView.h"
#import <Metal/Metal.h>
#import <simd/simd.h>

/* ── Module-level singleton ─────────────────────────────────────────────── */

static EmulatorMetalView *g_metalView = nil;

/* ── EmulatorMetalView implementation ──────────────────────────────────── */

@implementation EmulatorMetalView {
    id<MTLDevice>              _device;
    id<MTLCommandQueue>        _commandQueue;
    id<MTLRenderPipelineState> _pipeline;
    id<MTLTexture>             _texture;       // cached, recreated only on size change

    /* Current frame state written by presentPixels:, read by drawInMTKView: */
    simd_float4  _quadRect;   /* { left, bottom, right, top } NDC */
    int          _scanlines;  /* 0 = off, non-zero = on */
}

@synthesize scanlinesEnabled = _scanlinesEnabled;

/* ── Initialization ─────────────────────────────────────────────────────── */

- (instancetype)initWithFrame:(CGRect)frame {
    _device = MTLCreateSystemDefaultDevice();
    NSAssert(_device, @"EmulatorMetalView: no Metal device");

    self = [super initWithFrame:frame device:_device];
    if (!self) return nil;

    [self _setupMetal];
    return self;
}

- (void)_setupMetal {
    _commandQueue = [_device newCommandQueue];

    /* Load shaders from the default library (Shaders.metal compiled by Xcode). */
    NSError *err = nil;
    id<MTLLibrary> lib = [_device newDefaultLibraryWithBundle:[NSBundle mainBundle]
                                                        error:&err];
    NSAssert(lib, @"EmulatorMetalView: failed to load shader library: %@", err);

    id<MTLFunction> vf = [lib newFunctionWithName:@"emulatorVertex"];
    id<MTLFunction> ff = [lib newFunctionWithName:@"emulatorFragment"];
    NSAssert(vf && ff, @"EmulatorMetalView: shader functions not found");

    MTLRenderPipelineDescriptor *rpd = [MTLRenderPipelineDescriptor new];
    rpd.vertexFunction   = vf;
    rpd.fragmentFunction = ff;
    rpd.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    _pipeline = [_device newRenderPipelineStateWithDescriptor:rpd error:&err];
    NSAssert(_pipeline, @"EmulatorMetalView: pipeline creation failed: %@", err);

    /* MTKView configuration: emulator loop drives rendering, not the display link. */
    self.device                  = _device;
    self.delegate                = self;
    self.paused                  = YES;
    self.enableSetNeedsDisplay   = NO;
    self.colorPixelFormat        = MTLPixelFormatBGRA8Unorm;
    self.clearColor              = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    self.framebufferOnly         = YES;

    /* Initial quad: fill entire drawable. */
    _quadRect = (simd_float4){ -1.0f, -1.0f, 1.0f, 1.0f };
    _scanlines = 0;
}

/* ── Frame upload + present ─────────────────────────────────────────────── */

- (void)presentPixels:(const unsigned int *)pixels
                srcW:(int)srcW srcH:(int)srcH
               quadL:(float)quadL quadB:(float)quadB
               quadR:(float)quadR quadT:(float)quadT {
    /* Recreate the texture only when dimensions change (rare: mode switches). */
    if (!_texture ||
        (NSUInteger)srcW != _texture.width ||
        (NSUInteger)srcH != _texture.height) {

        MTLTextureDescriptor *td =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                               width:(NSUInteger)srcW
                                                              height:(NSUInteger)srcH
                                                           mipmapped:NO];
        td.usage       = MTLTextureUsageShaderRead;
        td.storageMode = MTLStorageModeShared;  /* CPU-writable, GPU-readable */
        _texture = [_device newTextureWithDescriptor:td];
        NSAssert(_texture, @"EmulatorMetalView: texture allocation failed (%d×%d)", srcW, srcH);
    }

    /* Upload pixels. */
    MTLRegion region = MTLRegionMake2D(0, 0, (NSUInteger)srcW, (NSUInteger)srcH);
    [_texture replaceRegion:region
                mipmapLevel:0
                  withBytes:pixels
                bytesPerRow:(NSUInteger)(srcW * 4)];

    /* Store rendering parameters for drawInMTKView:. */
    _quadRect  = (simd_float4){ quadL, quadB, quadR, quadT };
    _scanlines = _scanlinesEnabled ? 1 : 0;

    /* Synchronous draw — we are already on the main thread. */
    [self draw];
}

/* ── MTKViewDelegate ────────────────────────────────────────────────────── */

- (void)drawInMTKView:(MTKView *)view {
    if (!_texture) return;

    id<MTLCommandBuffer> cmdBuf = [_commandQueue commandBuffer];
    if (!cmdBuf) return;

    MTLRenderPassDescriptor *rpd = view.currentRenderPassDescriptor;
    if (!rpd) { [cmdBuf commit]; return; }

    id<MTLRenderCommandEncoder> enc =
        [cmdBuf renderCommandEncoderWithDescriptor:rpd];

    [enc setRenderPipelineState:_pipeline];

    /* Vertex buffer 0: quad NDC rect { L, B, R, T }. */
    [enc setVertexBytes:&_quadRect length:sizeof(_quadRect) atIndex:0];

    /* Fragment texture 0: BGRA8 Atari frame. */
    [enc setFragmentTexture:_texture atIndex:0];

    /* Fragment buffer 0: scanlines flag. */
    [enc setFragmentBytes:&_scanlines length:sizeof(_scanlines) atIndex:0];

    /* Draw a fullscreen quad as a triangle strip (4 vertices). */
    [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip
            vertexStart:0
            vertexCount:4];

    [enc endEncoding];
    [cmdBuf presentDrawable:view.currentDrawable];
    [cmdBuf commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    /* Nothing to do: the NDC quad is recomputed each frame by the C layer. */
    (void)view; (void)size;
}

@end

/* ── C-callable bridge ──────────────────────────────────────────────────── */

void Mac_MetalViewCreate(void *nsWindow, int w, int h) {
    NSWindow *window = (__bridge NSWindow *)nsWindow;

    CGRect frame = CGRectMake(0, 0, (CGFloat)w, (CGFloat)h);
    g_metalView = [[EmulatorMetalView alloc] initWithFrame:frame];

    /* Replace SDL's contentView with the Metal view.
     * SDL keeps the NSWindow for event delivery; we own the visual layer. */
    window.contentView = g_metalView;
}

void Mac_MetalPresent(const unsigned int *pixels,
                      int srcW, int srcH,
                      float quadL, float quadB,
                      float quadR, float quadT) {
    if (!g_metalView) return;
    [g_metalView presentPixels:pixels
                          srcW:srcW srcH:srcH
                         quadL:quadL quadB:quadB
                         quadR:quadR quadT:quadT];
}

void Mac_MetalSetScanlines(int enabled) {
    if (g_metalView)
        g_metalView.scanlinesEnabled = (BOOL)enabled;
}

void Mac_MetalViewDestroy(void) {
    g_metalView = nil;
}
