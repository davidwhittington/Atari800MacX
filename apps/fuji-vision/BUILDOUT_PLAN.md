# Fuji-Vision Buildout Plan

Phased implementation roadmap for the visionOS Atari 800 emulator.

## Phase V1: C Core Compiling

**Goal**: Get all ~70 C core files building for visionOS arm64.

### Tasks
- Create Xcode project (visionOS App template, SwiftUI lifecycle, visionOS 2.0 target)
- Add C core file references from `../fuji-foundation/atari800-MacOSX/src/`
- Configure `HEADER_SEARCH_PATHS` so visionOS `config.h` is found first
- Set `GCC_PREPROCESSOR_DEFINITIONS = HAVE_CONFIG_H=1`
- Fix any SDK incompatibilities (e.g., missing POSIX functions, platform guards)
- Verify `Atari800Core_Initialize()` succeeds in visionOS Simulator
- Ensure no macOS/AppKit/SDL symbols leak into the visionOS build

### C Core Files to Reference

**From `src/` (portable core):**
af80.c, afile.c, antic.c, atari.c, binload.c, bit3.c, capslock.c, cartridge.c, cartridge_info.c, cassette.c, cfg.c, colours.c, compfile.c, cpu.c, crc32.c, cycle_map.c, devices.c, eeprom.c, esc.c, flash.c, gtia.c, ide.c, img_disk.c, img_raw.c, img_tape.c, img_vhd.c, input.c, log.c, maxflash.c, megacart.c, memory.c, monitor.c, mzpokeysnd.c, pbi.c, pbi_bb.c, pbi_mio.c, pbi_proto80.c, pbi_scsi.c, pbi_xld.c, pia.c, pokey.c, pokey_resample.c, pokeysnd.c, rdevice.c, remez.c, rt-config.c, rtcds1305.c, rtime.c, screen.c, sic.c, side2.c, sio.c, sndsave.c, sound.c, statesav.c, sysrom.c, thecart.c, ui.c, ui_basic.c, ultimate1mb.c, util.c, votrax.c, xep80.c, xep80_fonts.c

**From `src/Atari800MacX/` (shared bridge):**
Atari800Core.c, preferences_c.c, mac_colours.c, mac_diskled.c, mac_screen.c

**Excluded (macOS/SDL-specific):**
atari_mac_sdl.c, main.c, all .m ObjC files, SDLMain.*, EmulatorMetalView.*

### Build Settings

```
HEADER_SEARCH_PATHS:
  $(SRCROOT)/FujiVision/Platform          ← config.h lives here (found FIRST)
  $(SRCROOT)/../fuji-foundation/atari800-MacOSX/src
  $(SRCROOT)/../fuji-foundation/atari800-MacOSX/src/Atari800MacX

GCC_PREPROCESSOR_DEFINITIONS: HAVE_CONFIG_H=1
SWIFT_OBJC_BRIDGING_HEADER: FujiVision/FujiVision-Bridging-Header.h
SWIFT_VERSION: 5.9

Frameworks: Metal, MetalKit, GameController, AVFoundation
```

### Verification
- `xcodebuild -scheme FujiVision -destination 'platform=visionOS Simulator'` builds cleanly
- App launches in Simulator without crash
- Console shows "Atari800Core_Initialize() succeeded" (or similar)

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
