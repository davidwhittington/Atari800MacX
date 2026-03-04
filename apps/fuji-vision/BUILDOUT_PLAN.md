# Fuji-Vision Buildout Plan

Phased implementation roadmap for the visionOS Atari 800 emulator.

## Phase V1: C Core Compiling — DONE

**Goal**: Get all ~65 C core files building and linking for visionOS arm64.

**Status**: BUILD SUCCEEDED — universal binary (x86_64 + arm64) for visionOS Simulator.

### What Was Done
- Generated Xcode project via XcodeGen (`project.yml`) — visionOS 2.0+, SwiftUI lifecycle
- Referenced 60 portable C core files + 5 bridge files from `../fuji-foundation/`
- Created visionOS-specific `config.h` with `VISIONOS 1`, `ATARI800MACX`, `MACOSX` defines
- Created platform shim `atari_vision.c` (PLATFORM_* functions, INPUT_* globals, sound ring buffer)
- Created `preferences_vision.c` (replaces SDL-dependent `preferences_c.c`)
- Created `capslock_vision.c` (replaces IOKit-dependent `capslock.c`)
- Created `vision_stubs.c` (stubs for macOS ObjC symbols: ControlManager, MediaManager, etc.)
- Added `mac_monitor.c` to build (provides MONITOR_* symbols used by cpu.c)
- Added 4 Altirra ROM .c files (built-in OS/BASIC ROMs)

### Files Excluded (and why)
| File | Reason | Replacement |
|------|--------|-------------|
| `preferences_c.c` | Requires SDL.h (keyboard scancodes) | `preferences_vision.c` |
| `capslock.c` | Requires IOKit (macOS Caps Lock LED) | `capslock_vision.c` |
| `rdevice.c` | Requires R_SERIAL/R_NETWORK (no serial on visionOS) | N/A |
| `atari_mac_sdl.c` | SDL platform layer (replaced by `atari_vision.c`) | `atari_vision.c` |
| `input.c` | INPUT_* stubs provided by `atari_vision.c` | `atari_vision.c` |
| `screen.c` | Replaced by `mac_screen.c` (shared with macOS) | `mac_screen.c` |
| `colours.c` | Replaced by `mac_colours.c` (shared with macOS) | `mac_colours.c` |
| `sound.c` | Sound_Update/Exit provided by `atari_vision.c` | `atari_vision.c` |
| `monitor.c` | Replaced by `mac_monitor.c` (MACOSX-enhanced) | `mac_monitor.c` |

### Build Issues Resolved (10 iterations)
1. Swift `renderer` property redeclaration — changed to `private(set)`
2. C function pointer capturing Swift context — static trampoline via global
3. `SDL.h` not found in `preferences_c.c` — replaced with `preferences_vision.c`
4. `altirra_basic.h` not found — added `src/roms` to header search paths
5. `IOKit/hidsystem/IOHIDLib.h` not found — replaced `capslock.c` with stub
6. Missing `CARTRIDGE_funcs_type` struct members — added `ATARI800MACX` define
7. Missing `TransferDest`, `PCLink_Enabled` — added `MACOSX` define
8. `system()` unavailable on visionOS — macro stub in `config.h`
9. `INPUT_Initialise` return type mismatch — changed to `void`
10. Linker undefined symbols — added `vision_stubs.c`, `mac_monitor.c`, ROM files

### Build Settings

```
HEADER_SEARCH_PATHS:
  $(SRCROOT)/FujiVision/Platform          ← config.h lives here (found FIRST)
  $(SRCROOT)/../fuji-foundation/atari800-MacOSX/src
  $(SRCROOT)/../fuji-foundation/atari800-MacOSX/src/Atari800MacX
  $(SRCROOT)/../fuji-foundation/atari800-MacOSX/src/roms

GCC_PREPROCESSOR_DEFINITIONS: HAVE_CONFIG_H=1
SWIFT_OBJC_BRIDGING_HEADER: FujiVision/FujiVision-Bridging-Header.h
SWIFT_VERSION: 5.9
GCC_C_LANGUAGE_STANDARD: gnu11
```

### C Core Files in Build (69 total)

**From `src/` (60 portable core files):**
af80.c, afile.c, antic.c, atari.c, binload.c, bit3.c, cartridge.c, cartridge_info.c, cassette.c, cfg.c, compfile.c, cpu.c, crc32.c, cycle_map.c, devices.c, eeprom.c, emuio.c, esc.c, flash.c, gtia.c, ide.c, img_disk.c, img_raw.c, img_tape.c, img_vhd.c, list.c, log.c, maxflash.c, megacart.c, memory.c, mzpokeysnd.c, netsio.c, pbi.c, pbi_bb.c, pbi_mio.c, pbi_scsi.c, pclink.c, pia.c, pokey.c, pokey_resample.c, pokeysnd.c, prompts.c, remez.c, rtcds1305.c, rtime.c, sic.c, side2.c, sio.c, sndsave.c, statesav.c, sysrom.c, thecart.c, ui_basic.c, ultimate1mb.c, util.c, vec.c, votrax.c, xep80.c, xep80_fonts.c

**From `src/Atari800MacX/` (5 bridge files):**
Atari800Core.c, mac_colours.c, mac_diskled.c, mac_monitor.c, mac_screen.c

**From `src/roms/` (4 ROM files):**
altirra_5200_os.c, altirra_basic.c, altirraos_800.c, altirraos_xl.c

### Verification
- `xcodebuild -scheme FujiVision -destination 'generic/platform=xrsimulator'` — BUILD SUCCEEDED
- Binary: Mach-O universal (x86_64 + arm64) at `FujiVision.app/FujiVision`

---

## Phase V2: Metal Rendering — DONE

**Goal**: Live Atari screen visible in a visionOS window.

**Status**: Implemented. Frame pipeline wired: C core RGBA → MTLTexture (.rgba8Unorm) → Metal shader → MTKView drawable (.bgra8Unorm).

### What Was Done
- Source texture format set to `.rgba8Unorm` (matching C core's RGBA byte order)
- Pipeline output format stays `.bgra8Unorm` (matching MTKView drawable)
- Metal handles RGBA→BGRA conversion automatically during shader sampling
- Frame callback trampoline copies pixel data on emu thread, dispatches to main for GPU upload
- MTKView runs at 60fps via display link, draws fullscreen quad with current texture

---

## Phase V3: Audio — DONE

**Goal**: POKEY sound output plays through visionOS audio.

**Status**: Implemented. AudioEngine with AVAudioSourceNode pull-model wired to C ring buffer.

### What Was Done
- AVAudioSourceNode render callback pulls via `Vision_Sound_Read()` from lock-free SPSC ring buffer
- Format: 44100 Hz, 16-bit signed integer, stereo interleaved
- Zero-fills remainder when ring buffer has insufficient data (prevents clicks)
- Callback tick updates for `PLATFORM_AdjustSpeed()` synchronized sound feedback
- Volume control via `engine.mainMixerNode.outputVolume`
- Pause/resume for app lifecycle

---

## Phase V4: Input — DONE

**Goal**: Full joystick and keyboard input via gamepad and virtual controls.

**Status**: Implemented. GCController gamepad + on-screen virtual controls.

### What Was Done
- Fixed console key handling: Start/Select/Option now use `INPUT_key_consol` bit-clearing (not AKEY_* constants)
- Added `Vision_Input_ConsoleKeyDown/Up` to platform_bridge.h for proper console key access from Swift
- Fire button state tracked separately for combined joystick+fire updates
- Shoulder buttons mapped to Space (L1) and Return (R1) via correct AKEY constants
- D-pad AND left thumbstick both map to joystick directions with 0.3 deadzone
- On-screen controls use same console key bit-clearing mechanism

### Controller Mapping

| Physical | Atari Action | Mechanism |
|----------|-------------|-----------|
| D-pad | Joystick directions | `Atari800Core_JoystickUpdate()` |
| Left stick | Joystick directions (alt) | `Atari800Core_JoystickUpdate()` |
| A (south) | Fire button | `Atari800Core_JoystickUpdate()` fire=1 |
| B (east) | Start | `Vision_Input_ConsoleKeyDown(0x01)` |
| X (west) | Select | `Vision_Input_ConsoleKeyDown(0x02)` |
| Y (north) | Option | `Vision_Input_ConsoleKeyDown(0x04)` |
| L1 | Space | `Atari800Core_KeyDown(AKEY_SPACE)` |
| R1 | Return | `Atari800Core_KeyDown(AKEY_RETURN)` |
| Menu | Warm reset | `Atari800Core_WarmReset()` |

---

## Phase V5: File Management — DONE

**Goal**: Users can import and manage Atari media files.

**Status**: Implemented. UTType declarations, file importer, media tracking, persistence.

### What Was Done
- **UTType declarations** in Info.plist for 6 Atari media types:
  - `com.fujiconcepts.atari-disk-atr` (.atr, .atz)
  - `com.fujiconcepts.atari-disk-xfd` (.xfd, .dcm)
  - `com.fujiconcepts.atari-cartridge` (.car, .rom, .bin)
  - `com.fujiconcepts.atari-executable` (.xex, .com, .exe, .obx)
  - `com.fujiconcepts.atari-cassette` (.cas)
  - `com.fujiconcepts.atari-savestate` (.a8s)
- **AtariUTTypes.swift**: Swift `UTType` constants matching Info.plist declarations
- **File importer** filters by media type per target (disks show .atr/.xfd, carts show .car, etc.)
  - Falls back to `.data` so any file can still be selected
- **Media tracking**: `mountedMedia` dictionary tracks what's mounted in each slot
- **Eject support**: Toolbar shows eject buttons for mounted media
- **Persistence**: UserDefaults stores last-mounted paths; restored on launch
- **Media status bar**: visionOS ornament at bottom shows mounted media names
- **Disk LED indicator**: Green (read) / Red (write) dot in top-right corner
- Files copied to app sandbox `Documents/Media/` for persistent access

---

## Phase V6: Polish — DONE

**Goal**: Production-quality user experience.

**Status**: Implemented. Settings view, save states, app lifecycle.

### What Was Done
- **SettingsView.swift**: Form-based settings panel presented as sheet
  - Display: TV mode (NTSC/PAL), artifacting mode (4 options), bilinear filter, CRT scanlines with intensity slider
  - Audio: sound enable, volume slider, stereo POKEY toggle
  - Speed: speed limit toggle, speed multiplier slider (50%-400%)
  - Machine: model selection with current indicator
  - All settings use @AppStorage for persistence across launches
  - Changes apply immediately via Atari800Core_Set* APIs
- **SaveStateView.swift**: 10-slot save state manager
  - Save/load/delete per slot with modification date display
  - States stored in Documents/SaveStates/state_N.a8s
  - Uses Atari800Core_SaveState/LoadState
- **App lifecycle**: scenePhase monitoring
  - Pauses emulation + audio on background/inactive
  - Resumes on foreground (respects user pause state)
- **Toolbar additions**: Settings gear button, Save States button
- **Audio volume**: wired through EmulatorSession to AudioEngine

---

## Phase V7: Spatial Features (Future)

**Goal**: Leverage visionOS spatial computing capabilities.

### Tasks
- **Immersive Space**: 3D CRT television model floating in the user's space
  - CompositorServices for custom Metal rendering in immersive mode
  - RealityKit entity with CRT mesh + emulator texture as material
- **Spatial Audio**: Position POKEY audio to emanate from the virtual CRT
  - `PHASESpatialMixerDefinition` for head-tracked audio
- **Hand Tracking**: Map hand gestures to joystick/keyboard input
  - ARKit hand tracking API for gesture recognition
  - Pinch → fire, swipe → joystick directions
- **Multi-Window**: Open multiple emulator instances in separate windows
  - Each window runs an independent `EmulatorSession`
- **SharePlay**: Multiplayer over FaceTime (shared joystick ports)

---

## Dependencies Between Phases

```
V1 (C Core) ──→ V2 (Metal) ──→ V6 (Polish)
     │               │
     └──→ V3 (Audio) │
     │               │
     └──→ V4 (Input) │
                      │
              V5 (Files) ──→ V6 (Polish) ──→ V7 (Spatial)
```

V1 must complete first. V2, V3, V4 can proceed in parallel after V1.
V5 and V6 build on the earlier phases. V7 is a future enhancement.

---

## Technical Notes

### C Core Integration
- The C core files are **referenced** from `../fuji-foundation/`, not copied
- `config.h` in `FujiVision/Platform/` is found first via header search path ordering
- `atari_vision.c` provides all PLATFORM_* functions and extern globals
- The Mac port's `INPUT_Frame()` is a no-op; joystick state is written directly to `PIA_PORT_input[]` and `GTIA_TRIG[]` — the visionOS port does the same

### Sound Architecture
- POKEY generates samples → `Sound_Update()` → ring buffer → `AVAudioSourceNode` callback
- Lock-free SPSC ring buffer (single producer = emu thread, single consumer = audio thread)
- `PLATFORM_AdjustSpeed()` monitors buffer fill level to keep emulation in sync with audio

### Frame Pipeline
- C core renders to `Screen_atari` (indexed color, 384x240 bytes)
- `Atari800Core_RunFrame()` converts to ARGB8888 via `colortable[]`
- `PLATFORM_DisplayScreen()` callback delivers pixels to Swift
- `EmulatorRenderer` uploads to `MTLTexture` and draws fullscreen quad
