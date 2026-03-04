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

## Phase V2: Metal Rendering

**Goal**: Live Atari screen visible in a visionOS window.

### Tasks
- Wire `EmulatorRenderer.uploadFrame()` to receive ARGB8888 data from C callback
- Verify MTKView displays the frame texture via the shared vertex/fragment shaders
- Implement aspect-ratio-correct quad computation (4:3 Atari display in variable window)
- Add bilinear filter toggle and scanline effect controls
- Test with known ROMs that produce visible output (e.g., Atari BASIC `GR.0` screen)

### Key Insight
The C core produces ARGB8888 via `Atari800Core_GetFrameBuffer()` (384x240).
`EmulatorRenderer` uploads this directly to an `MTLTexture` — no pixel format conversion needed since both the core and Metal use 4 bytes/pixel. The only caveat: the core outputs ARGB while Metal expects BGRA, so the shader or upload path may need byte-order swizzling.

---

## Phase V3: Audio

**Goal**: POKEY sound output plays through visionOS spatial audio.

### Tasks
- Verify `AudioEngine` starts and `AVAudioSourceNode` callback fires
- Confirm `Vision_Sound_Read()` pulls correct samples from ring buffer
- Tune ring buffer size and latency (target ~20ms, currently VISION_SOUND_BUFFER_SIZE = 16384)
- Implement `PLATFORM_AdjustSpeed()` feedback loop for synchronized sound
- Test stereo POKEY output (dual POKEY games)
- Add volume control wired to `Atari800Core_SetAudioVolume()`

---

## Phase V4: Input

**Goal**: Full joystick and keyboard input via gamepad and virtual controls.

### Tasks
- Verify GCController discovery and mapping with Bluetooth gamepad
- Refine `InputManager` button-to-AKEY mappings using actual `akey.h` constants
- Implement `OnScreenControlsView` with proper gaze+pinch interaction
- Add virtual Atari keyboard overlay (full key matrix for typing)
- Support analog stick → joystick direction with proper dead zone
- Test with joystick-intensive games (River Raid, Star Raiders)
- Test 5200 controller (analog range mapping)

### Controller Mapping (Refined)

| Physical | Atari Action | AKEY / Register |
|----------|-------------|-----------------|
| D-pad | Joystick directions | PIA_PORT_input[] |
| Left stick | Joystick directions (alt) | PIA_PORT_input[] |
| A (south) | Fire button | GTIA_TRIG[0] |
| B (east) | Start | AKEY_START / INPUT_key_consol |
| X (west) | Select | AKEY_SELECT / INPUT_key_consol |
| Y (north) | Option | AKEY_OPTION / INPUT_key_consol |
| L1 | Space | AKEY_SPACE |
| R1 | Return | AKEY_RETURN |
| Menu | Warm reset | Atari800Core_WarmReset() |

---

## Phase V5: File Management

**Goal**: Users can import and manage Atari media files.

### Tasks
- Implement `fileImporter()` with proper UTType declarations for:
  - `.atr`, `.xfd` (disk images)
  - `.car`, `.rom`, `.bin` (cartridge images)
  - `.xex`, `.com`, `.exe` (executables)
  - `.cas` (cassette images)
  - `.a8s` (save states)
- Copy imported files to app sandbox `Documents/Media/` directory
- Add media browser view (list mounted disks, show file names)
- Support drag-and-drop from Files app
- Persist last-mounted media across app launches (UserDefaults)

---

## Phase V6: Polish

**Goal**: Production-quality user experience.

### Tasks
- Settings view:
  - TV mode (NTSC/PAL)
  - Artifacting mode
  - Machine type (800/XL/XE/5200)
  - Audio volume, stereo toggle
  - Speed control
  - Scanline effect, linear filter
- Save state management (save/load/list)
- Disk LED indicator overlay
- Machine type indicator in toolbar
- Speed display (FPS counter)
- App lifecycle handling (pause on background, resume on foreground)
- Keyboard shortcut support (if hardware keyboard connected)

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
