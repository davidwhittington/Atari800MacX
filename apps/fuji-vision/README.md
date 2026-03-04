# Fuji-Vision — Atari 800 Emulator for Apple Vision Pro

Fuji-Vision brings the Atari 800/XL/XE/5200 to Apple Vision Pro (visionOS). It shares the same portable C emulation core as [fuji-foundation](../fuji-foundation/) (the macOS app) but replaces the macOS/SDL platform layer with a pure Swift + Metal + AVAudioEngine stack designed for spatial computing.

## Architecture

```
┌───────────────────────────────────────────┐
│  SwiftUI App Layer                        │
│  FujiVisionApp → ContentView → Views      │
├───────────────────────────────────────────┤
│  Emulator Layer (Swift)                   │
│  EmulatorSession  EmulatorRenderer        │
│  AudioEngine      InputManager            │
├───────────────────────────────────────────┤
│  Platform Bridge (C↔Swift)                │
│  platform_bridge.h  atari_vision.c        │
├───────────────────────────────────────────┤
│  C Emulation Core (shared with macOS)     │
│  Atari800Core.h/c → ~70 portable C files  │
│  from ../fuji-foundation/                 │
└───────────────────────────────────────────┘
```

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Window model | Windowed (WindowGroup) | MTKView works in visionOS windows; immersive space deferred to Phase V7 |
| Audio API | AVAudioSourceNode | Pull-model callback identical to SDL's SoundCallback pattern |
| Input | GCController + virtual overlay | Bluetooth gamepads for joystick; gaze+pinch for on-screen controls |
| Deployment target | visionOS 2.0 | Better Metal/MTKView support; all AVP users are on 2.0+ |
| C core integration | Relative file references | Same source files as fuji-foundation; no duplication |
| ObjC layer | None | Pure Swift ↔ C via bridging header; Atari800Core.h is the contract |

## Directory Structure

```
FujiVision/
├── App/
│   ├── FujiVisionApp.swift          # @main SwiftUI entry point
│   └── ContentView.swift            # Main window: emulator + toolbar
├── Emulator/
│   ├── EmulatorSession.swift        # @Observable: emulation lifecycle + frame texture
│   ├── EmulatorRenderer.swift       # Metal pipeline: texture upload + quad draw
│   └── AudioEngine.swift            # AVAudioSourceNode pulling from C ring buffer
├── Input/
│   └── InputManager.swift           # GCController gamepad + virtual keyboard bridge
├── Platform/
│   ├── config.h                     # visionOS feature flags (subset of macOS config.h)
│   ├── atari_vision.c               # PLATFORM_* stubs + globals + sound ring buffer
│   └── platform_bridge.h            # C↔Swift callback declarations
├── Views/
│   ├── EmulatorView.swift           # UIViewRepresentable wrapping MTKView
│   └── OnScreenControlsView.swift   # Virtual joystick + console key overlay
├── Shaders/
│   └── Shaders.metal                # Shared Metal shaders (identical to macOS)
├── Resources/
│   ├── Assets.xcassets/             # App icon (visionOS solidimagestack)
│   └── Info.plist                   # visionOS app metadata
├── FujiVision.entitlements          # Sandbox + file access + network
└── FujiVision-Bridging-Header.h     # Imports Atari800Core.h + platform_bridge.h
```

## C Core Files (from fuji-foundation)

The emulation core is ~70 portable C files referenced from `../fuji-foundation/atari800-MacOSX/src/`. These are **not** copied — the Xcode project references them via relative paths.

**Core files**: antic.c, atari.c, cartridge.c, cpu.c, gtia.c, memory.c, pia.c, pokey.c, sio.c, and ~60 more.

**Bridge files**: Atari800Core.c, preferences_c.c, mac_colours.c, mac_diskled.c, mac_screen.c

**Excluded** (macOS/SDL-specific): atari_mac_sdl.c, main.c, all .m ObjC files, SDLMain.*, EmulatorMetalView.*

## Building

### Prerequisites

- Xcode with visionOS SDK (visionOS 2.0+)
- Apple Vision Pro Simulator or device

### Steps

1. Create the Xcode project: **File > New > visionOS App** (SwiftUI lifecycle)
2. Add source files from this scaffold + C core references from fuji-foundation
3. Configure build settings:
   - `HEADER_SEARCH_PATHS`: `$(SRCROOT)/FujiVision/Platform` (first), `$(SRCROOT)/../fuji-foundation/atari800-MacOSX/src`, `$(SRCROOT)/../fuji-foundation/atari800-MacOSX/src/Atari800MacX`
   - `GCC_PREPROCESSOR_DEFINITIONS`: `HAVE_CONFIG_H=1`
   - `SWIFT_OBJC_BRIDGING_HEADER`: `FujiVision/FujiVision-Bridging-Header.h`
   - Frameworks: Metal, MetalKit, GameController, AVFoundation
4. Build and run on visionOS Simulator

## Buildout Phases

See [BUILDOUT_PLAN.md](BUILDOUT_PLAN.md) for the complete phased implementation roadmap.

| Phase | Description | Status |
|-------|-------------|--------|
| Scaffold | Directory structure, source files, documentation | Done |
| V1 | C Core compiling on visionOS | Pending |
| V2 | Metal rendering pipeline | Pending |
| V3 | Audio (AVAudioSourceNode) | Pending |
| V4 | Input (GCController + virtual controls) | Pending |
| V5 | File management (fileImporter) | Pending |
| V6 | Polish (settings, save states, LED) | Pending |
| V7 | Spatial features (immersive space, 3D CRT) | Future |

## Upstream Tracking

Upstream core changes flow through fuji-foundation first.
See `../fuji-foundation` for upstream integration notes.

## License

Same license as the parent fuji-concepts monorepo.
