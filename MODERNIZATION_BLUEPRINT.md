# Atari800MacX — Modernization Blueprint
## GUI & Xcode Porting Plan

**Project:** Atari800MacX v6.1.2
**Author:** Modernization Plan
**Date:** February 2026
**Branch:** `claude/modernize-gui-xcode-plan-yG4Gu`

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Assessment](#2-current-state-assessment)
3. [Modernization Goals](#3-modernization-goals)
4. [High-Level Architecture](#4-high-level-architecture)
5. [Phase 1 — Xcode Project Modernization](#5-phase-1--xcode-project-modernization)
6. [Phase 2 — Emulation Core Isolation](#6-phase-2--emulation-core-isolation)
7. [Phase 3 — NIB to XIB Migration](#7-phase-3--nib-to-xib-migration)
8. [Phase 4 — AppKit API Modernization](#8-phase-4--appkit-api-modernization)
9. [Phase 5 — Metal Rendering Pipeline](#9-phase-5--metal-rendering-pipeline)
10. [Phase 6 — Swift/Objective-C Interoperability](#10-phase-6--swiftobjective-c-interoperability)
11. [Phase 7 — SwiftUI for New Panels](#11-phase-7--swiftui-for-new-panels)
12. [Phase 8 — Dependency Modernization](#12-phase-8--dependency-modernization)
13. [Phase 9 — Code Signing & Notarization](#13-phase-9--code-signing--notarization)
14. [Testing Strategy](#14-testing-strategy)
15. [Risk Assessment](#15-risk-assessment)
16. [Phased Rollout Summary](#16-phased-rollout-summary)

---

## 1. Executive Summary

Atari800MacX is a mature, feature-rich Atari 800 emulator for macOS with a native Cocoa frontend wrapping a cross-platform C emulation core. The codebase was built starting in 2002 and has accumulated layers that target macOS 10.4–10.12, use NIB-based Interface Builder files, rely on deprecated OpenGL APIs, and carry an Xcode project configuration frozen at object version 46 (circa Xcode 9).

This blueprint defines a phased, backward-compatible path to modernize the project for:

- **Xcode 15+ / macOS 14+ Sonoma** native development
- **Metal** rendering to replace deprecated OpenGL
- **Modern AppKit** patterns replacing deprecated controls and APIs
- **Swift interoperability** for future maintainability
- **SwiftUI** for new preference panels and secondary windows
- **Swift Package Manager** integration for dependencies
- Full **notarization** and App Store readiness

The emulation core (C) is intentionally left unchanged. All modernization effort targets the GUI layer and build infrastructure.

---

## 2. Current State Assessment

### 2.1 Build System

| Item | Current State | Issue |
|------|---------------|-------|
| Xcode objectVersion | 46 (Xcode 9, 2017) | Cannot use modern build features |
| xcconfig target | macOS 10.4 (ppc/i386) | Dead code; confuses modern Xcode |
| Deployment target | macOS 10.12 Sierra | 4 major versions behind minimum practical |
| Architecture | `ONLY_ACTIVE_ARCH = YES` | Good; already set |
| Code signing | "Apple Development" | Needs hardened runtime for notarization |

### 2.2 GUI Framework

| Component | Current | Problem |
|-----------|---------|---------|
| Interface files | NIB bundles (binary) | Cannot diff in version control; deprecated workflow |
| Main entry | `NSMainNibFile` key in Info.plist | Deprecated in favor of `NSPrincipalClass` + Storyboard |
| Rendering | OpenGL via `NSOpenGLView` | Deprecated since macOS 10.14; removed from future macOS |
| Carbon.framework | Linked as dependency | Removed in macOS 15 (Sequoia) |
| Touch Bar | `NSTouchBarDelegate` present | Hardware discontinued; low priority |

### 2.3 Source Layout

```
src/Atari800MacX/       ← Objective-C GUI layer (~153 files)
    *.m / *.h           ← Controllers, views, data sources
    *.nib/              ← Binary interface files (9 NIB bundles)
    SDL2.framework/     ← Embedded SDL2 for event loop
src/*.c / *.h           ← C emulation core (~154 files)
    atari.c, antic.c, gtia.c, pokey*.c, memory*, ...
```

### 2.4 Key Deprecated APIs in Use

- `NSOpenGLView` / `NSOpenGLContext` / `NSOpenGLPixelFormat` — removed macOS 14+
- `Carbon.framework` (`HIToolbox`, `CarbonCore`) — removed macOS 15
- `NSSoundView` — deprecated macOS 10.9
- `NSMatrix` (radio button grouping) — deprecated macOS 10.8
- `NSDrawer` — deprecated macOS 10.13
- `IKImageView` (Image Kit) — deprecated macOS 10.14
- `NSOpenPanel` / `NSSavePanel` delegate methods (pre-block API) — deprecated
- Manual memory management patterns (retain/release) mixed with ARC

---

## 3. Modernization Goals

### Must Have (Non-Negotiable)
- Build cleanly on Xcode 15+ with zero warnings
- macOS 13 Ventura as minimum deployment target
- No deprecated framework linkage at build time
- Full Apple notarization support (hardened runtime)
- Metal-based display rendering (replace OpenGL)
- XIB or Storyboard interface files (replace NIBs)

### Should Have
- Full ARC compliance across all Objective-C files
- Swift interoperability bridge in place
- SwiftUI-based Preferences window
- Swift Package Manager for SDL3 or alternative

### Nice to Have
- Swift reimplementation of selected controllers
- iOS/iPadOS companion target (sharing the C core)
- Async/await patterns for file I/O operations

---

## 4. High-Level Architecture

The modernized architecture maintains the proven layered design while replacing outdated bridges:

```
┌─────────────────────────────────────────────────────────────┐
│                    macOS Application Bundle                  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              GUI Layer (AppKit + SwiftUI)            │   │
│  │                                                     │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────┐  │   │
│  │  │  Main Window  │  │  Preferences │  │ Debugger │  │   │
│  │  │  (AppKit/MTK) │  │  (SwiftUI)   │  │ Windows  │  │   │
│  │  └──────┬───────┘  └──────┬───────┘  └────┬─────┘  │   │
│  │         │                 │                │        │   │
│  │  ┌──────▼─────────────────▼────────────────▼─────┐  │   │
│  │  │           Swift/ObjC Bridge Layer              │  │   │
│  │  │   EmulatorState  |  InputRouter  |  MediaBridge│  │   │
│  │  └──────────────────────┬──────────────────────┘  │   │
│  └─────────────────────────┼────────────────────────┘    │
│                            │                              │
│  ┌─────────────────────────▼────────────────────────┐    │
│  │         C Emulation Core (Unchanged)              │    │
│  │  atari.c | antic.c | gtia.c | pokeysnd.c | ...   │    │
│  └──────────────────────────────────────────────────┘    │
│                                                           │
│  ┌──────────────────────┐  ┌────────────────────────┐    │
│  │  Metal Renderer      │  │  SDL3 (via SPM or pkg)  │    │
│  │  (MTKView + shaders) │  │  (input + audio)        │    │
│  └──────────────────────┘  └────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Phase 1 — Xcode Project Modernization

**Goal:** Build system that compiles cleanly on Xcode 15+ with no legacy noise.
**Risk:** Low — structural changes only, no source edits.
**Estimated effort:** 1–2 days

### 5.1 Upgrade Project Format

Edit `project.pbxproj`:
- Change `objectVersion` from `46` to `56` (Xcode 14/15 format)
- Add `LastUpgradeCheck = 1500` to the project attributes block
- Set `ENABLE_USER_SCRIPT_SANDBOXING = NO` if custom scripts are present

### 5.2 Retire the Legacy xcconfig

`Atari800MacX.xcconfig` references `MacOSX10.4u.sdk`, `GCC_VERSION = 4.0`, and `ppc`/`i386` architecture tokens. These have been meaningless since Xcode 10.

**Action:** Replace with a modern `Atari800MacX.xcconfig`:

```
// Atari800MacX.xcconfig — Modern

MACOSX_DEPLOYMENT_TARGET = 13.0
SWIFT_VERSION = 5.9

// Compiler
CLANG_ENABLE_OBJC_ARC = YES
CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES
CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES
GCC_WARN_UNUSED_VARIABLE = YES
GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE

// Hardened Runtime (required for notarization)
ENABLE_HARDENED_RUNTIME = YES

// Search paths
FRAMEWORK_SEARCH_PATHS = $(inherited) $(SRCROOT)/Frameworks
HEADER_SEARCH_PATHS = $(inherited) $(SRCROOT)/Frameworks/SDL3.xcframework/Headers

// Symbols
DEAD_CODE_STRIPPING = YES
STRIP_SWIFT_SYMBOLS = YES
```

### 5.3 Deployment Target & SDK

- Set `MACOSX_DEPLOYMENT_TARGET = 13.0` in project build settings
- Remove the legacy `10.4u` SDK reference from both Debug and Release configurations
- Add `SWIFT_VERSION = 5.9` now so Swift files can be added incrementally

### 5.4 Remove Carbon.framework

Carbon is removed in macOS 15 Sequoia. Audit and remove:

1. In Xcode Link Binary phase: remove `Carbon.framework`
2. Search all `.m` / `.h` files for `#import <Carbon/Carbon.h>` and `HIToolbox`, `AEDesc`, etc.
3. Replace any used Carbon APIs:
   - `GetCurrentEventKeyModifiers()` → `[NSEvent modifierFlags]`
   - `DispatchEvent()` → AppKit event queue
   - File Manager APIs → `NSURL` / `NSFileManager`
4. Verify with `EXCLUDED_FRAMEWORKS = Carbon` to confirm no transitive dependency

### 5.5 Build Phase Cleanup

- Remove duplicate keyedobjects-*.nib variants from the Copy Resources phase (keep only the single canonical version per NIB)
- Consolidate headers into Public/Private/Project classifications
- Add a **SwiftLint** run-script phase (optional, enforces style incrementally)

### 5.6 Scheme Configuration

- Create separate **Debug**, **Release**, and **Profile** schemes
- Profile scheme should enable Metal Performance HUD and GPU Frame Capture
- Enable Thread Sanitizer on Debug for finding race conditions between emulator and UI threads

---

## 6. Phase 2 — Emulation Core Isolation

**Goal:** Define a clean, stable C interface that the GUI depends on — no direct reach into emulator internals.
**Risk:** Medium — requires adding header files without touching emulator logic.
**Estimated effort:** 3–5 days

### 6.1 Audit Existing Bridge Files

These files already bridge C and Objective-C:
- `mac_colours.h` — color table access
- `mac_diskled.h` — disk activity LED
- `mac_rdevice.h` — R-device (networking)
- `preferences_c.h` — C-side preferences

Formalize these as the **only** cross-boundary headers.

### 6.2 Create `Atari800Core.h` — Public C API

Create a single umbrella header `src/Atari800MacX/Atari800Core.h`:

```c
// Atari800Core.h
// Public interface between the C emulation core and the macOS GUI layer.
// GUI code must only call functions declared here.

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// --- Lifecycle ---
int  Atari800Core_Initialize(void);
void Atari800Core_RunFrame(void);
void Atari800Core_Shutdown(void);

// --- State ---
typedef enum {
    ATARI_MODEL_800,
    ATARI_MODEL_XL,
    ATARI_MODEL_XE,
    ATARI_MODEL_5200,
} Atari800Model;

void Atari800Core_SetModel(Atari800Model model);
Atari800Model Atari800Core_GetModel(void);

// --- Frame Buffer ---
// Returns pointer to ARGB8888 pixel data, width*height pixels.
const uint8_t* Atari800Core_GetFrameBuffer(int *outWidth, int *outHeight);

// --- Media ---
int  Atari800Core_MountDisk(int drive, const char *path);
void Atari800Core_UnmountDisk(int drive);
int  Atari800Core_InsertCartridge(const char *path);
void Atari800Core_RemoveCartridge(void);

// --- Input ---
void Atari800Core_KeyDown(int akey);
void Atari800Core_KeyUp(int akey);
void Atari800Core_JoystickUpdate(int port, int direction, int fire);

// --- Save States ---
int  Atari800Core_SaveState(const char *path);
int  Atari800Core_LoadState(const char *path);

#ifdef __cplusplus
}
#endif
```

### 6.3 Thread Safety Contract

Document and enforce threading rules:
- The **emulation thread** calls `Atari800Core_RunFrame()` at ~60 Hz
- The **main thread** owns all AppKit/SwiftUI calls
- The **bridge layer** (`DisplayManager`, `SoundManager`) marshals across threads using lock-free ring buffers or dispatch queues
- Add `OS_UNFAIR_LOCK`-based locking around shared state in the bridge

### 6.4 Wrap in an Objective-C Class

Create `Atari800Engine.h/.m` as the Objective-C façade over `Atari800Core.h`:

```objc
// Atari800Engine.h
@interface Atari800Engine : NSObject

+ (instancetype)sharedEngine;

- (BOOL)startWithError:(NSError **)error;
- (void)stop;
- (void)runOneFrame;          // call from emulation thread

// Frame access (thread-safe)
- (CVPixelBufferRef)currentFramePixelBuffer; // for Metal upload

// Media
- (BOOL)mountDiskURL:(NSURL *)url drive:(NSInteger)drive error:(NSError **)error;
- (void)unmountDrive:(NSInteger)drive;

// Input
- (void)sendKeyDown:(NSInteger)akey;
- (void)sendKeyUp:(NSInteger)akey;

@end
```

This class becomes the **only** point of contact between Swift/Objective-C GUI code and the C core.

---

## 7. Phase 3 — NIB to XIB Migration

**Goal:** Convert all 9 NIB bundles to XIB source files for version-control diffing, Interface Builder editing in modern Xcode, and storyboard-readiness.
**Risk:** Low-Medium — automated conversion is available but requires visual validation.
**Estimated effort:** 2–3 days

### 7.1 NIB Inventory

| NIB File | Window/Panel | Priority |
|----------|-------------|---------|
| `SDLMain.nib` | Main application window | High |
| `Preferences.nib` | Preferences (700+ outlets) | High |
| `ControlManager.nib` | Input controls | Medium |
| `MediaManager.nib` | Media management | Medium |
| `DiskEditorWindow.nib` | Disk editor | Medium |
| `SectorEditorWindow.nib` | Sector editor | Low |
| `AboutBox.nib` | About dialog | Low |
| `PrintOutput.nib` | Print output | Low |
| `PrintOutputConfirm.nib` | Print confirm | Low |

### 7.2 Conversion Process

For each NIB:

1. **Open in Xcode Interface Builder** (Xcode will prompt to upgrade)
2. File → Save As → select `.xib` format
3. Remove the old `.nib` bundle from the Xcode project
4. Add the new `.xib` file to the project and Copy Resources phase
5. Update `NSNibName` string references in the corresponding controller's `+initialize` or `windowNibName` if applicable
6. Run the app and visually verify every control, binding, and outlet

### 7.3 Prune Version-Specific NIB Variants

The repository currently contains:
- `keyedobjects-101201.nib` (macOS 10.12)
- `keyedobjects-101300.nib` (macOS 10.13)
- `keyedobjects.nib`

After converting to XIBs targeting macOS 13+, delete all variant NIBs. A single XIB compiles at build time, so runtime variants are unnecessary.

### 7.4 Localization Update

- Update `en.lproj/InfoPlist.strings` to use modern locale identifier format
- Replace `CFBundleDevelopmentRegion = English` with `en` in `Info.plist`
- Prepare `.strings` files for each XIB (Xcode can generate these)

---

## 8. Phase 4 — AppKit API Modernization

**Goal:** Replace all deprecated AppKit APIs with supported equivalents.
**Risk:** Medium — requires testing each replaced control carefully.
**Estimated effort:** 5–8 days

### 8.1 Replace NSMatrix (Radio Groups)

`NSMatrix` is deprecated since macOS 10.8. The Preferences window uses it for radio button groups.

**Migration:**
```objc
// OLD: NSMatrix with NSRadioModeMatrix
@property (weak) IBOutlet NSMatrix *videoModeMatrix;

// NEW: Individual NSButton (radio style) + shared action
@property (weak) IBOutlet NSButton *videoModeNTSCButton;
@property (weak) IBOutlet NSButton *videoModePALButton;
```

In XIB: set each button `buttonType = NSButtonTypeRadio` and connect to the same IBAction. Manage selection state manually or bind to a shared integer preference.

### 8.2 Replace NSOpenGLView (see Phase 5)

Covered in the Metal rendering phase. The `DisplayManager` is the primary consumer.

### 8.3 Modernize File Panels

Replace delegate-based `NSOpenPanel` patterns with block-based API:

```objc
// OLD
NSOpenPanel *panel = [NSOpenPanel openPanel];
[panel beginSheetForDirectory:nil file:nil types:types
               modalForWindow:window modalDelegate:self
               didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
                  contextInfo:nil];

// NEW
NSOpenPanel *panel = [NSOpenPanel openPanel];
panel.allowedContentTypes = @[UTTypeATRDiskImage, UTTypeXEXExecutable];
[panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
    if (result == NSModalResponseOK) {
        [self loadMediaFromURL:panel.URL];
    }
}];
```

Define `UTType` constants for all Atari file types in `Info.plist` using the modern `UTExportedTypeDeclarations` key.

### 8.4 Replace NSDrawer (if present)

Search for any `NSDrawer` usage — deprecated since 10.13. Replace with:
- `NSSplitViewController` for side panels
- `NSPopover` for transient detail views
- An `NSPanel` for floating windows

### 8.5 ARC Compliance Audit

Run the Xcode ARC migration tool (`Edit → Convert → To Objective-C ARC`) on all GUI `.m` files one module at a time:

Priority order:
1. `AboutBox.m` — simple, low risk
2. `KeyMapper.m` — utility, low dependencies
3. `MediaManager.m` — medium complexity
4. `Preferences.m` — most complex, 700+ outlets, do last
5. `DisplayManager.m` — touches emulator thread, requires care

Files interfacing directly with C emulator code (`SoundManager.m`, `DisplayManager.m`) should use `__bridge` casts carefully.

### 8.6 Modernize NSUserDefaults

Replace string-keyed defaults with typed Swift constants (Phase 6), but for now:

```objc
// Create a Preferences key constants header
// PreferenceKeys.h
static NSString * const PrefVideoMode     = @"VideoMode";
static NSString * const PrefAudioEnabled  = @"AudioEnabled";
static NSString * const PrefJoystickPort1 = @"JoystickPort1";
// ... etc. for all 176+ keys
```

This eliminates stringly-typed bugs and prepares for Swift migration.

### 8.7 Touch Bar

The MacBook Touch Bar was discontinued with the 2021 MacBook Pro models. Existing `NSTouchBarDelegate` code in `Atari800WindowController` compiles cleanly and can be left as-is since it's compile-time conditional. No action required.

---

## 9. Phase 5 — Metal Rendering Pipeline

**Goal:** Replace `NSOpenGLView`/`OpenGL.framework` with a `MTKView`-based Metal pipeline.
**Risk:** High — core rendering path, requires correctness validation.
**Estimated effort:** 5–10 days

### 9.1 Why Metal

- `OpenGL.framework` is deprecated since macOS 10.14 and will be removed
- Metal has lower driver overhead, better frame pacing, and native HDR support
- `MTKView` integrates cleanly with AppKit and the CVDisplayLink

### 9.2 Architecture

```
Emulator Thread                    Main Thread
─────────────────                  ─────────────────────────────
Atari800Core_RunFrame()
    ↓
writes to framebuffer[back]        MTKView displayLink fires
    ↓                              reads framebuffer[front]
swaps front/back buffers  ──────►  uploads texture via MTLBuffer
                                       ↓
                               renders fullscreen quad with shader
                                       ↓
                               applies scanline/artifact effects
                                       ↓
                               MTKView presents drawable
```

### 9.3 Implementation Steps

**Step 1 — Create `EmulatorMetalView.m/h`**

```objc
@interface EmulatorMetalView : MTKView <MTKViewDelegate>

@property (nonatomic) CGSize emulatorResolution; // 336 x 240 or 320 x 192 etc.
@property (nonatomic) BOOL   scanlinesEnabled;
@property (nonatomic) float  brightness;
@property (nonatomic) float  saturation;

- (void)updateWithPixelBuffer:(const uint8_t *)pixels
                        width:(NSInteger)width
                       height:(NSInteger)height;

@end
```

**Step 2 — Define Vertex and Fragment Shaders**

Create `Shaders.metal`:

```metal
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Fullscreen quad vertex shader
vertex VertexOut emulatorVertex(uint vid [[vertex_id]]) {
    const float2 positions[] = {
        {-1, -1}, {1, -1}, {-1, 1}, {1, 1}
    };
    const float2 texCoords[] = {
        {0, 1}, {1, 1}, {0, 0}, {1, 0}
    };
    VertexOut out;
    out.position = float4(positions[vid], 0, 1);
    out.texCoord = texCoords[vid];
    return out;
}

// Fragment shader with optional scanlines and color correction
fragment float4 emulatorFragment(VertexOut in         [[stage_in]],
                                 texture2d<float> tex  [[texture(0)]],
                                 constant float &brightness [[buffer(0)]],
                                 constant float &saturation [[buffer(1)]],
                                 constant bool  &scanlines  [[buffer(2)]]) {
    constexpr sampler s(filter::nearest);  // pixel-perfect by default
    float4 color = tex.sample(s, in.texCoord);

    // Scanline effect
    if (scanlines && fmod(in.position.y, 2.0) < 1.0) {
        color.rgb *= 0.75;
    }

    // Brightness / saturation adjustment
    float lum = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    color.rgb = mix(float3(lum), color.rgb, saturation) * brightness;

    return color;
}
```

**Step 3 — Migrate DisplayManager**

- Replace `NSOpenGLContext` with `id<MTLDevice>` and `MTKView`
- Replace `SDL_GL_SwapWindow` or manual OpenGL flush with `MTKView` delegate pattern
- Use a `MTLTexture` of `MTLPixelFormatBGRA8Unorm` matching the emulator's ARGB8888 output
- Upload pixel data each frame via `MTLBuffer` → `replaceRegion:mipmapLevel:withBytes:bytesPerRow:`

**Step 4 — Pixel Scaling Modes**

Implement via shader sampler:
- `filter::nearest` — integer 1x/2x/3x/4x scaling (pixel-perfect)
- `filter::linear` — smooth bilinear interpolation
- Custom Scale2x/Scale3x — implement in compute shader or as a two-pass render

**Step 5 — CVDisplayLink Integration**

```objc
// In EmulatorMetalView
- (void)setupDisplayLink {
    self.paused = YES;
    self.enableSetNeedsDisplay = NO;
    // Use MTKView's preferredFramesPerSecond = 60
    // or override with CVDisplayLink for precise timing
}
```

### 9.4 Remove OpenGL

After Metal pipeline is validated:
1. Remove `OpenGL.framework` from Link Binary With Libraries
2. Delete `mac_gl.h`, any `GL/gl.h` imports
3. Remove `LIBGL` or SDL OpenGL render driver hints from SDL initialization

---

## 10. Phase 6 — Swift/Objective-C Interoperability

**Goal:** Add Swift to the project incrementally without rewriting existing Objective-C.
**Risk:** Low — Swift/ObjC interop is well-supported.
**Estimated effort:** 1–2 days for bridge setup, then incremental

### 10.1 Add Swift to the Project

1. Create a new Swift file (e.g., `Atari800App.swift`) — Xcode generates the bridge header automatically
2. Xcode creates `Atari800MacX-Bridging-Header.h`
3. Add imports to the bridging header:
   ```objc
   #import "Atari800Engine.h"
   #import "DisplayManager.h"
   #import "SoundManager.h"
   #import "MediaManager.h"
   #import "Preferences.h"
   #import "PreferenceKeys.h"
   ```

### 10.2 Expose Objective-C to Swift

Annotate key Objective-C classes for clean Swift usage:

```objc
// Atari800Engine.h
NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(EmulatorEngine)
@interface Atari800Engine : NSObject

+ (instancetype)sharedEngine NS_SWIFT_NAME(shared);
- (BOOL)startWithError:(NSError **)error;
- (void)mountDisk:(NSURL *)url drive:(NSInteger)drive
            error:(NSError *_Nullable *_Nullable)error NS_SWIFT_NAME(mount(_:drive:));

@end

NS_ASSUME_NONNULL_END
```

### 10.3 Swift Preference Models

Create `PreferenceModel.swift` using `@Observable` (Swift 5.9+):

```swift
import Observation

@Observable
final class PreferenceModel {
    // Video
    var videoMode: VideoMode = .ntsc
    var scalingMode: ScalingMode = .integer2x
    var scanlinesEnabled: Bool = false
    var brightness: Double = 1.0

    // Audio
    var audioEnabled: Bool = true
    var audioVolume: Double = 1.0
    var stereoEnabled: Bool = false

    // Emulation
    var machineModel: MachineModel = .atari800XL
    var speedLimit: Bool = true

    // Persist to NSUserDefaults
    func save() { /* ... */ }
    func load() { /* ... */ }
}
```

---

## 11. Phase 7 — SwiftUI for New Panels

**Goal:** Build new preference panels and secondary windows in SwiftUI while AppKit hosts the main emulator window.
**Risk:** Low-Medium — SwiftUI can be isolated to specific windows.
**Estimated effort:** 5–10 days per major panel

### 11.1 Strategy: NSHostingView Embedding

SwiftUI views are embedded in AppKit windows using `NSHostingController`:

```swift
// In AppDelegate or a coordinator:
let prefsModel = PreferenceModel()
let prefsView = PreferencesView(model: prefsModel)
let hostingController = NSHostingController(rootView: prefsView)

let window = NSWindow(contentViewController: hostingController)
window.title = "Preferences"
window.styleMask = [.titled, .closable, .resizable]
window.makeKeyAndOrderFront(nil)
```

The main emulation window (`Atari800Window`) remains `NSWindow` with a `MTKView` — SwiftUI is not used for real-time rendering.

### 11.2 Preferences Window

The Preferences NIB has 700+ outlet connections across many tabs. Rebuild it in SwiftUI grouped by tab:

```swift
struct PreferencesView: View {
    @Bindable var model: PreferenceModel

    var body: some View {
        TabView {
            VideoPreferencesTab(model: model)
                .tabItem { Label("Video", systemImage: "display") }

            AudioPreferencesTab(model: model)
                .tabItem { Label("Audio", systemImage: "speaker.wave.2") }

            InputPreferencesTab(model: model)
                .tabItem { Label("Input", systemImage: "gamecontroller") }

            MachinePreferencesTab(model: model)
                .tabItem { Label("Machine", systemImage: "cpu") }

            PeripheralsPreferencesTab(model: model)
                .tabItem { Label("Peripherals", systemImage: "printer") }

            PathsPreferencesTab(model: model)
                .tabItem { Label("Paths", systemImage: "folder") }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}
```

### 11.3 About Box

```swift
struct AboutBoxView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("Atari800MacX")
                .font(.largeTitle.bold())

            Text("Version 6.1.2")
                .foregroundStyle(.secondary)

            Text("Copyright © 2002–2026 Mark Grebe")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Based on the Atari 800 emulator by David Firth")
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 360)
    }
}
```

### 11.4 Media Manager

The media manager window (disk drives, cartridge, cassette) is a good candidate for SwiftUI:

```swift
struct MediaManagerView: View {
    @State private var drives: [DriveState] = Array(repeating: .empty, count: 8)
    @State private var cartridge: CartridgeState = .empty

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Disk Drives").font(.headline).padding()
            ForEach(0..<8) { i in
                DriveRowView(drive: $drives[i], index: i)
                Divider()
            }
            CartridgeRowView(cartridge: $cartridge)
        }
        .frame(minWidth: 480)
    }
}
```

---

## 12. Phase 8 — Dependency Modernization

**Goal:** Replace the embedded SDL2.framework binary blob with a modern, version-controlled dependency.
**Risk:** Medium — SDL API changes between versions.
**Estimated effort:** 2–4 days

### 12.1 SDL2 → SDL3 Evaluation

SDL3 was released in 2024 and includes breaking API changes from SDL2. Evaluate:

| Feature | SDL2 | SDL3 |
|---------|------|------|
| Audio API | `SDL_OpenAudioDevice` | `SDL_OpenAudioDeviceStream` |
| Event system | `SDL_Event` union | Same, minor changes |
| Input/gamepad | `SDL_GameController` | `SDL_Gamepad` |
| Render | SDL_Renderer | Same + GPU API |
| macOS integration | Good | Better Metal support |

**Recommendation:** Migrate to SDL3 if the audio/input changes are manageable, otherwise stay on SDL2 but deliver it via Swift Package Manager.

### 12.2 Swift Package Manager Integration

Create a local package or reference the SDL binary:

**Option A: XCFramework via SPM**

If Apple's binary distribution of SDL3 is available, or build your own XCFramework:

```swift
// Package.swift (in project root or a local package)
// Reference a local XCFramework
.binaryTarget(
    name: "SDL3",
    path: "Frameworks/SDL3.xcframework"
)
```

**Option B: Use SDL2 from Homebrew (Development only)**

```xcconfig
// For local developer builds only
FRAMEWORK_SEARCH_PATHS = $(inherited) /opt/homebrew/Cellar/sdl2/2.30.0/lib
```

For distribution, always embed a signed copy in the app bundle.

### 12.3 hidapi

`hidapi.framework` is embedded inside SDL2.framework. With SDL3, hidapi is integrated directly into SDL. If staying on SDL2, maintain the existing embedding approach.

### 12.4 Package the Result

For distribution:
1. Build SDL (2 or 3) as a universal XCFramework (`arm64` + `x86_64`)
2. Place in `Frameworks/` directory
3. Sign with the app's Developer ID
4. Set `FRAMEWORK_SEARCH_PATHS` to point at `$(SRCROOT)/Frameworks`
5. Embed and sign in the app bundle via the Embed Frameworks build phase

---

## 13. Phase 9 — Code Signing & Notarization

**Goal:** The app is fully notarized and passes Gatekeeper on all modern macOS versions.
**Risk:** Low with correct setup.
**Estimated effort:** 1–2 days

### 13.1 Hardened Runtime Entitlements

Create `Atari800MacX.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <!-- Required for SDL joystick/gamepad input -->
    <key>com.apple.security.device.usb</key>
    <true/>

    <!-- Required for HID device access (joysticks) -->
    <key>com.apple.security.device.bluetooth</key>
    <true/>

    <!-- Required if loading ROMs from user-chosen locations -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- Required for network SIO (netsio.c) -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Disable library validation if loading SDL from bundle -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

### 13.2 Notarization Workflow

```bash
# 1. Build archive
xcodebuild archive -scheme Atari800MacX -archivePath build/Atari800MacX.xcarchive

# 2. Export for Developer ID
xcodebuild -exportArchive \
    -archivePath build/Atari800MacX.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist ExportOptions.plist

# 3. Notarize
xcrun notarytool submit build/export/Atari800MacX.dmg \
    --apple-id "your@apple.id" \
    --team-id "XXXXXXXXXX" \
    --wait

# 4. Staple
xcrun stapler staple build/export/Atari800MacX.dmg
```

### 13.3 Create a Makefile/Script for Distribution

Add `scripts/build_release.sh` that automates the full archive → notarize → staple → DMG workflow.

---

## 14. Testing Strategy

### 14.1 Regression Test Baseline

Before any modernization changes:
1. **Record a golden set of screenshots** at known emulation states (boot screen, a running game, etc.) at 5-second intervals
2. **Record audio output** checksums for a short emulation run
3. Store these in `tests/golden/` directory

After each phase, run the emulator and compare outputs.

### 14.2 Unit Tests (XCTest)

Create `Atari800MacXTests` target:

```swift
// EmulatorEngineTests.swift
class EmulatorEngineTests: XCTestCase {

    func testInitialization() throws {
        let engine = EmulatorEngine.shared
        XCTAssertNoThrow(try engine.start())
    }

    func testDiskMounting() throws {
        let engine = EmulatorEngine.shared
        let diskURL = Bundle(for: Self.self).url(forResource: "test_disk", withExtension: "atr")!
        XCTAssertNoThrow(try engine.mount(diskURL, drive: 1))
    }

    func testPreferencePersistence() {
        let model = PreferenceModel()
        model.videoMode = .pal
        model.save()

        let model2 = PreferenceModel()
        model2.load()
        XCTAssertEqual(model2.videoMode, .pal)
    }
}
```

### 14.3 UI Tests (XCUITest)

```swift
// Atari800MacXUITests.swift
class Atari800MacXUITests: XCTestCase {

    func testPreferencesWindowOpens() {
        let app = XCUIApplication()
        app.launch()
        app.menuBars.menuBarItems["Atari800MacX"].click()
        app.menus.menuItems["Preferences…"].click()
        XCTAssert(app.windows["Preferences"].exists)
    }

    func testMediaManagerOpens() {
        let app = XCUIApplication()
        app.launch()
        app.menuBars.menuBarItems["File"].click()
        app.menus.menuItems["Open Media Manager"].click()
        XCTAssert(app.windows["Media Manager"].exists)
    }
}
```

### 14.4 Visual Comparison Testing

For the Metal renderer specifically, implement a snapshot testing approach:
- Use `XCTAttachment` to capture `MTKView` screenshots during tests
- Compare against golden images with a pixel-diff threshold
- Flag tests where more than 0.1% of pixels differ by more than 5 RGB units

---

## 15. Risk Assessment

### 15.1 Risk Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Metal renderer pixel-perfect mismatch vs OpenGL | Medium | High | Extensive visual testing; keep OGL build option initially |
| SDL2→SDL3 audio breakage | Medium | High | Evaluate SDL3 on dev branch first; keep SDL2 fallback |
| Carbon API usage deeper than expected | Low | Medium | Audit with `grep -r "Carbon"` before removing |
| Preferences NIB migration breaks outlet connections | High | Medium | Validate every tab interactively after conversion |
| ARC migration introduces retain cycles | Medium | Medium | Run Instruments Leaks profiler after each conversion batch |
| Notarization failure due to embedded framework | Low | High | Use `codesign -vvv --deep` before submission |
| Thread safety bugs from emulator/UI interaction | Medium | High | Enable TSan on Debug; add logging for thread assertions |

### 15.2 Rollback Strategy

- Each phase is on a feature branch merging to `main` only when validated
- The C emulation core is never modified — all changes are additive to the GUI layer
- The Metal renderer should be built alongside OpenGL initially, switchable via a compile flag
- NIB → XIB conversions are tracked per-file so partial states are manageable

---

## 16. Phased Rollout Summary

### Timeline Overview

```
Phase 1  ██████                       Xcode Project Modernization     (1–2 days)
Phase 2  ██████████                   Emulation Core Isolation        (3–5 days)
Phase 3  ██████████                   NIB → XIB Migration             (2–3 days)
Phase 4  ████████████████             AppKit API Modernization        (5–8 days)
Phase 5  ████████████████████         Metal Rendering Pipeline        (5–10 days)
Phase 6  ██████                       Swift/ObjC Interop Setup        (1–2 days)
Phase 7  ████████████████             SwiftUI Panels                  (5–10 days)
Phase 8  ████████                     Dependency Modernization        (2–4 days)
Phase 9  ██████                       Code Signing & Notarization     (1–2 days)
─────────────────────────────────────────────────────────────────────────────────
Total                                                            ~25–46 dev-days
```

### Recommended Phase Order

The phases above are ordered by risk and dependency. Strictly follow this sequence:

1. **Phase 1** first — clean Xcode setup unlocks all subsequent work
2. **Phase 2** before Phases 6/7 — the clean C interface must exist before Swift wraps it
3. **Phase 3** before **Phase 4** — XIBs are easier to edit when removing deprecated controls
4. **Phase 5** can run in parallel with **Phase 3/4** on a feature branch
5. **Phase 6** before **Phase 7** — Swift bridge must exist before SwiftUI uses it
6. **Phase 8** at any point after **Phase 1** — independent of GUI work
7. **Phase 9** last — notarization is a distribution step

### Definition of Done

A phase is complete when:
- [ ] All code compiles with zero errors and zero warnings (treat warnings as errors: `GCC_TREAT_WARNINGS_AS_ERRORS = YES`)
- [ ] The emulator runs and produces correct Atari 800 display output
- [ ] All previously working UI controls respond correctly
- [ ] No memory leaks detected in a 5-minute Instruments session
- [ ] Tests pass (unit tests for affected code, UI test for affected windows)
- [ ] Code is committed to `claude/modernize-gui-xcode-plan-yG4Gu` with a descriptive message

---

## Appendix A: File-Level Change Inventory

### Files to Delete
- `Atari800MacX.xcconfig` (replaced by modern config)
- `*.nib` bundles (all 9, replaced by XIBs)
- `keyedobjects-101201.nib`, `keyedobjects-101300.nib` variants
- `English.lproj/` NIB artifacts (keep InfoPlist.strings)
- `SDLMain.nib` (replaced by XIB + modern entry point)

### Files to Create
- `Atari800MacX-Modern.xcconfig`
- `Atari800MacX.entitlements`
- `Atari800Core.h` (public C API)
- `Atari800Engine.h` / `Atari800Engine.m` (ObjC façade)
- `PreferenceKeys.h` (string constants)
- `PreferenceModel.swift`
- `EmulatorMetalView.h` / `EmulatorMetalView.m`
- `Shaders.metal`
- `Atari800App.swift` (SwiftUI app entry when ready)
- `PreferencesView.swift` and sub-views
- `AboutBoxView.swift`
- `MediaManagerView.swift`
- `Atari800MacX-Bridging-Header.h`
- `*.xib` for each converted NIB
- `Atari800MacXTests/` test target
- `scripts/build_release.sh`

### Files to Modify
- `project.pbxproj` — objectVersion, deployment target, new files
- `Info-Atari800MacX.plist` — remove `NSMainNibFile`, add UTI declarations
- `SDLMain.m` — remove Carbon imports, update entry point
- `DisplayManager.m` — replace OpenGL with Metal
- All `.m` files — ARC migration, deprecated API replacement
- `Preferences.m` — connect to PreferenceModel

---

## Appendix B: Key Reference Documentation

- [Metal Best Practices Guide (Apple Developer)](https://developer.apple.com/documentation/metal)
- [Migrating OpenGL Code to Metal](https://developer.apple.com/documentation/metal/migrating_opengl_code_to_metal)
- [Updating Your App from 32-Bit to 64-Bit](https://developer.apple.com/documentation/xcode/updating_your_app_from_32-bit_to_64-bit_architecture)
- [Hardened Runtime Entitlements](https://developer.apple.com/documentation/security/hardened_runtime)
- [Notarizing macOS Software Before Distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [NSHostingController Documentation](https://developer.apple.com/documentation/swiftui/nshostingcontroller)
- [MTKView Documentation](https://developer.apple.com/documentation/metalkit/mtkview)
- [SDL3 Migration Guide](https://wiki.libsdl.org/SDL3/MigrationGuide)
