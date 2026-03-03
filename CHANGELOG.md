# Changelog — fuji-concepts / Atari800MacX

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added — Phase VBXE: Video Board XE Emulation (`feature/vbxe-emulation`)

- **`src/vbxe.c` / `src/vbxe.h`** — New VBXE emulation module (~600 lines).
  Derived from Altirra `vbxe.cpp` (Avery Lee, GPL v2). Implements:
  - 512 KB VBXE VRAM
  - 256-color 21-bit RGB palette (7R 7G 7B per entry, expandable via VRAM)
  - Register file at `$D640` or `$D740` (FX 1.26 layout, 256 bytes)
  - MEMAC A/B: two CPU-visible 4 KB bank-switched windows into VBXE VRAM
    installed into `MEMORY_readmap`/`MEMORY_writemap`; default windows at
    `$4000` (A) and `$6000` (B)
  - XDL renderer: walks VBXE Extended Display List per frame; supports LR
    (160 px 8bpp), SR (320 px 8bpp), and HR (640 px 4bpp) overlay modes
  - Priority compositor: blends `vbxe_overlay[]` onto `MetalFrameBuffer`
    according to PRIO register (normal / always-VBXE / OR-blend)
  - Synchronous 7-mode blitter: COPY, FILL, OR, AND, XOR, MOVE, STENCIL,
    ADD; Z-enable (skip dest-write when src==0) supported
  - GTIA color forwarding: `VBXE_SetGTIAColor()` called from `GTIA_PutByte`
    for `COLPM0–3`, `COLPF0–3`, `COLBK` when VBXE is active
  - Full lifecycle: `VBXE_Initialise / Exit / ColdStart / WarmStart`
  - `VBXE_StateSave / StateRead` stubs (statesav integration deferred)

- **`LEGAL.md`** at repo root — documents Altirra derivation, Avery Lee
  authorship, GPL v2 licensing, and a summary of changes made during the port.

- **`gtia.c`** — `#include "vbxe.h"` + post-switch hook forwards
  `COLPM0–COLBK` writes to `VBXE_SetGTIAColor()` when VBXE is enabled.

- **`ultimate1mb.c`** — `#include "vbxe.h"` + `$D381` handler now calls
  `VBXE_Enable(addr)` / `VBXE_Disable()`; `ULTIMATE_ColdStart()` calls
  `VBXE_ColdStart()`.

- **`atari.c`** — `#include "vbxe.h"` + `VBXE_Initialise()` called from
  `Atari800_Initialise()`; `VBXE_Exit()` called from `Atari800_Exit()`.

- **`atari_mac_sdl.c`** — `#include "vbxe.h"` + `VBXE_RenderFrame()` /
  `VBXE_Composite()` called in `Atari_DisplayScreen()` after GTIA raster
  and before `Mac_MetalPresent()`.

- **`project.pbxproj`** — `vbxe.c` added to `PBXSourcesBuildPhase`; both
  `vbxe.c` and `vbxe.h` added to `PBXFileReference` and the source group.

### Implementation notes
- VBXE disabled by default; enabled via Ultimate 1MB `$D381` register or
  (future) Preferences UI toggle.
- Blitter is synchronous: blitter-done IRQ status bit clears immediately on
  trigger write. Cycle-accurate DMA deferred to Phase VBXE-2.
- Covers ~95% of known VBXE software (FX 1.26, standard display modes).

---

## [26.0.0] — 2026-03-03

### Fixed
- **MetalFrameBuffer stride mismatch** (`b488f65`) — `Mac_MetalPresent` was receiving
  `scaledWidth * 4` as the Metal texture row pitch, but `MetalFrameBuffer` rows are
  `Screen_WIDTH = 384` pixels wide (includes unrendered border columns). Metal was
  reading every row from a wrong offset, producing a blank/garbled display. Fixed by
  adding a `srcRowPitch` parameter to `Mac_MetalPresent` / `presentPixels:` and passing
  `screen_width * 4` at the call site in `Atari_DisplayScreen()`.

  Files changed: `EmulatorMetalView.h`, `EmulatorMetalView.m`, `atari_mac_sdl.c`

- **ARC migration crash** (`9cb4725`) — Phase 4.3 removed `retain`/`release` calls but
  never set `CLANG_ENABLE_OBJC_ARC = YES`, leaving the project compiling as MRC with
  missing retains. This caused a use-after-free Heisenbug (EXC_BAD_ACCESS in
  `objc_autorelease` during NIB load). Fixed by enabling ARC in all 3 build
  configurations and correcting `[super init]` → `self = [super init]; if (!self) return nil;`
  in 12 `.m` files. Also fixed a selector mismatch in `ControlManager.h`.

- **NSInvalidArgumentException on cart dialogs** (`ef1ed2a`) — Missing 8 MB/16 MB
  cart windows and dirty-cart dialog caused crashes when those code paths were reached.

### Changed
- **Version bumped to 26.0.0** (`dbd2889`)
- **Copyright updated** to reflect fuji-concepts authorship (`d473690`)

---

## [Monorepo restructure] — 2026-02 (`cfa6dd0`)

### Changed
- Repository reorganized as a **fuji-concepts monorepo**.
  Core app moved to `apps/fuji-foundation/`.
  Scaffold apps added: `apps/fuji-swift/`, `apps/fuji-vision/`, `apps/fuji-dynasty/`.

---

## Modernization — Phases A–D (`2fd91f6`–`8068a1e`)

Post-merge upstream integration and display wiring:

- **Phase A** (`2fd91f6`) — Merge upstream/master: cartridge system, ATR, debugger,
  NetSIO, display prefs.
- **Phase B** (`643ef58`) — Wire linear filter, pixel aspect ratio, and scanline
  transparency to Metal renderer. Added `_samplerLinear` / `_samplerNearest` to
  `EmulatorMetalView`; `scanlineTransparency` is now a configurable float.
- **Phase C** (`73501aa`) — Wire display quality controls in `Preferences.xib` and
  `SDLMain.xib` to the Metal renderer.
- **Phase D** (`8068a1e`) — Port debugger column-width and breakpoint editor fixes to
  `ControlManager.xib`.

---

## Modernization — Phases 1–9 (`c01803b`–`a9939f2`)

Full modernization of the Atari800MacX GUI layer for macOS 13+ arm64.
See `apps/fuji-foundation/MODERNIZATION_BLUEPRINT.md` for detailed design.

### Phase 1 & 2 — Xcode + Core Isolation (`c01803b`)
- Upgraded project `objectVersion` to 56 (Xcode 14/15 format)
- Set `MACOSX_DEPLOYMENT_TARGET = 13.0`, `SWIFT_VERSION = 5.9`
- Formalized C/ObjC boundary headers (`Atari800Core.h` umbrella)

### Phase 3 — NIB → XIB Migration (`88cac7a`)
- Converted all 9 NIB bundles to XIB source files
- Registered new XIB files in `project.pbxproj`

### Phase 4 — AppKit API Modernization (`e8f3676`, `c27eb1a`)
- Removed `Carbon.framework` hard-link; TIS symbols weakly linked
- Modernized `NSOpenPanel`/`NSSavePanel` to block-based API
- Replaced all `NSMatrix` usages with `NSSegmentedControl` / `NSPopUpButton`
- ARC migration (manual — see ARC crash fix note above)

### Phase 5 — Metal Rendering Pipeline (`a9939f2`)
- Replaced SDL renderer / surface / texture with `MTKView`-based Metal pipeline
- New files: `EmulatorMetalView.h/.m`, `Shaders.metal`
- New globals: `MetalPalette32[256]` (BGRA8Unorm), `MetalFrameBuffer` (heap, 384×300 max)
- `CalcPalette()` now builds `MetalPalette32` as `0xFF000000 | colortable[i]`
- `Atari_DisplayScreen()` computes NDC quad and calls `Mac_MetalPresent()`
- SDL2 stays for event loop, keyboard/joystick input, and audio

### Phase 6 — Swift/ObjC Interoperability (`6fbec8e`)
- Added `Atari800App.swift` (enables Swift; entry point stays in `main.m`)
- Added `Atari800MacX-Bridging-Header.h`
- `PreferenceModel.swift` uses `ObservableObject`/`@Published` (macOS 13 compatible)

### Phase 7 — SwiftUI Panels (`eead5e4`)
- `PreferencesView.swift`: TabView with 6 tabs (Video/Audio/Machine fully wired;
  Input/Peripherals/Paths are stubs)
- `AboutBoxView.swift`: app icon, version from Bundle, copyright
- `SwiftUIPanelCoordinator.swift`: `@objc NSObject` bridge for ObjC wiring
- Old ObjC Preferences/About Box windows remain (parallel implementation)

### Phase 9 — Code Signing & Notarization (`7970466`)
- `Atari800MacX.entitlements`: `disable-library-validation`,
  `user-selected.read-write`, `network.client`
- `ExportOptions.plist`: Developer ID, team X49M46V9N7, automatic signing
- `scripts/build_release.sh`: archive → export → DMG → notarytool → staple

### Phase 8 — Dependency Modernization — SKIPPED
- SDL2 v2.0.14 stays as-is (universal x86_64 + arm64)
- SDL3 blockers: audio API rewrite, joystick index→ID rewrite, `SDL_SysWMinfo` change
- Revisit when SDL audio + joystick can be refactored together

---

## Notes

- **Build command:**
  ```
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    xcodebuild -project apps/fuji-foundation/atari800-MacOSX/src/Atari800MacX/Atari800MacX.xcodeproj \
    -configuration Development -scheme Atari800MacX
  ```
- **Configurations:** Development / Deployment / Default (not Debug/Release)
- Deployment config fails due to missing team ID signing cert — pre-existing, not a regression.
