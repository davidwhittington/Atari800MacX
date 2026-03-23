#!/usr/bin/env bash
# seed-issues.sh — Creates all historical and planned issues for fuji-concepts
# Completed issues are created then immediately closed.
# Run from repo root: bash docs/project-management/seed-issues.sh
set -euo pipefail

REPO="davidwhittington/Atari800MacX"

# Milestone names (must match exactly what was created in GitHub)
MS_FOUNDATION="Active — fuji-foundation"
MS_VISION="Active — fuji-vision"
MS_SERVICES="Active — fuji-services"
MS_NEAR="Roadmap — Near Term"
MS_MID="Roadmap — Mid Term"
MS_LONG="Roadmap — Long Term"
MS_BACKLOG="Backlog"

new() {
  # new TITLE LABELS MILESTONE BODY
  # LABELS is comma-separated, e.g. "type: chore,app: fuji-foundation,area: build"
  local title="$1" labels="$2" ms="$3" body="$4"
  local label_args=()
  IFS=',' read -ra label_list <<< "$labels"
  for lbl in "${label_list[@]}"; do
    label_args+=(--label "$lbl")
  done
  local url
  url=$(gh issue create \
    --repo "$REPO" \
    --title "$title" \
    "${label_args[@]}" \
    --milestone "$ms" \
    --body "$body" 2>&1)
  local num
  num=$(echo "$url" | grep -o '[0-9]*$')
  echo "[#$num] $title" >&2
  echo "$num"
}

close() {
  local num="$1" commit="${2:-}"
  local comment="Completed"
  [[ -n "$commit" ]] && comment="Completed in commit $commit."
  gh issue close "$num" --repo "$REPO" --comment "$comment" 2>/dev/null
  echo "  closed #$num"
}

echo ""
echo "=== fuji-foundation — Completed ==="

num=$(new \
  "Phase 1: Xcode modernization" \
  "type: chore,app: fuji-foundation,area: build,priority: high" \
  "$MS_FOUNDATION" \
  "Modernize the Xcode project to build cleanly on Xcode 15+/Apple Silicon.

- Removed legacy build settings and stale configurations
- Set deployment target macOS 13.0 (Ventura)
- Configurations: Development / Deployment / Default (NOT Debug/Release)
- xcconfig attached to project-level Deployment config only

**Commit:** c01803b")
close "$num" "c01803b"

num=$(new \
  "Phase 2: Core isolation — monorepo restructure" \
  "type: chore,app: monorepo,area: build,priority: high" \
  "$MS_FOUNDATION" \
  "Reorganized repository as a fuji-concepts monorepo.

- Core app moved to \`apps/fuji-foundation/\`
- Scaffold apps added: \`apps/fuji-swift/\`, \`apps/fuji-vision/\`, \`apps/fuji-dynasty/\`
- Upstream changes merge into fuji-foundation only; other apps inherit selectively

**Commit:** cfa6dd0")
close "$num" "cfa6dd0"

num=$(new \
  "Phase 3: NIB → XIB migration" \
  "type: chore,app: fuji-foundation,area: ui,priority: medium" \
  "$MS_FOUNDATION" \
  "Migrated all legacy .nib files to editable .xib format.

Enables modern Interface Builder editing and version-control-friendly diffs for all UI files.

**Commit:** 88cac7a")
close "$num" "88cac7a"

num=$(new \
  "Phase 4.1: Remove Carbon.framework hard-link" \
  "type: chore,app: fuji-foundation,area: build,priority: medium" \
  "$MS_FOUNDATION" \
  "Removed Carbon.framework as a hard-linked dependency.

- Replaced with \`-weak_framework Carbon\` in OTHER_LDFLAGS
- TIS keyboard symbols (KeyMapper.m) guarded with NULL checks
- \`LMGetKbdType()\` guarded by \`#if TARGET_CPU_ARM64\` (unavailable on arm64)

Note: WEAK_FRAMEWORKS build setting does NOT produce a linker flag in Xcode 26 — must use OTHER_LDFLAGS.")
close "$num"

num=$(new \
  "Phase 4.2: Modernize NSOpenPanel/NSSavePanel" \
  "type: chore,app: fuji-foundation,area: ui,priority: medium" \
  "$MS_FOUNDATION" \
  "Updated all file open/save panel usage to modern macOS APIs.

- Replaced deprecated completion-handler patterns
- Added UniformTypeIdentifiers.framework for UTType/UTTypePDF
- Updated Preferences.m and PrintOutputController.m")
close "$num"

num=$(new \
  "Phase 4.3: ARC migration + NSZone cleanup" \
  "type: chore,app: fuji-foundation,area: build,priority: high" \
  "$MS_FOUNDATION" \
  "Enabled Automatic Reference Counting across the entire ObjC codebase.

- Set CLANG_ENABLE_OBJC_ARC = YES in all 3 build configurations
- Fixed \`[super init]\` → \`self = [super init]; if (!self) return nil;\` in 12 .m files
- Removed all manual retain/release/autorelease calls
- Fixed ControlManager.h selector mismatch

**Critical bug discovered and fixed:** Phase 4.3 had removed retain/release calls but never enabled ARC, leaving the project as MRC with missing retains → use-after-free Heisenbug (EXC_BAD_ACCESS in objc_autorelease during NIB load).

**Commit:** e8f3676, fix: 9cb4725")
close "$num" "9cb4725"

num=$(new \
  "Phase 4.4: NSMatrix → modern controls" \
  "type: chore,app: fuji-foundation,area: ui,priority: medium" \
  "$MS_FOUNDATION" \
  "Replaced all deprecated NSMatrix uses with modern AppKit controls.

- Radio button groups → NSSegmentedControl (\`selectedSegment\` / \`setSelectedSegment:\`)
- Cart type dialogs → NSPopUpButton (\`indexOfSelectedItem\`)
- Fixed pbiExpansionMatrix: old tags 1/2/3 → new segment indices 0/1/2

**Commit:** c27eb1a")
close "$num" "c27eb1a"

num=$(new \
  "Phase 5: Metal rendering pipeline" \
  "type: feature,app: fuji-foundation,area: metal,priority: high" \
  "$MS_FOUNDATION" \
  "Replaced SDL renderer/surface/texture with a native Metal pipeline.

- Added EmulatorMetalView.h/m (MTKView subclass + C bridge)
- Added Shaders.metal
- New globals: MetalPalette32[256], MetalFrameBuffer (640×300 max)
- CalcPalette() builds MetalPalette32 as 0xFF000000|colortable[i] (BGRA8Unorm)
- Atari_DisplayScreen() computes NDC quad, calls Mac_MetalPresent()
- DisplayWithoutScaling16bpp/AF80/Bit3 write to MetalFrameBuffer (uint32_t per pixel)
- MetalKit.framework + Metal.framework in OTHER_LDFLAGS

**Commit:** a9939f2")
close "$num" "a9939f2"

num=$(new \
  "Phase 6: Swift/ObjC interoperability" \
  "type: feature,app: fuji-foundation,area: build,priority: medium" \
  "$MS_FOUNDATION" \
  "Added Swift to the fuji-foundation target with a bridging header.

- Added Atari800App.swift (enables Swift; NOT @main — entry point stays in main.m)
- Added Atari800MacX-Bridging-Header.h
- SWIFT_OBJC_BRIDGING_HEADER set in all 3 target configs
- SWIFT_VERSION = 5.9

**Commit:** 6fbec8e")
close "$num" "6fbec8e"

num=$(new \
  "Phase 7: SwiftUI preference panels" \
  "type: feature,app: fuji-foundation,area: ui,priority: medium" \
  "$MS_FOUNDATION" \
  "Added parallel SwiftUI implementation of key UI panels.

- PreferencesView.swift: TabView with 6 tabs; Video/Audio/Machine fully implemented; Input/Peripherals/Paths are stubs
- AboutBoxView.swift: app icon, version from Bundle, copyright
- SwiftUIPanelCoordinator.swift: @objc bridge for ObjC wiring
- Uses ObservableObject/@ObservedObject (NOT @Bindable — requires macOS 14+)
- Old ObjC Preferences/About Box windows remain (parallel implementation)

**Commit:** eead5e4")
close "$num" "eead5e4"

num=$(new \
  "Phase 9: Code signing and notarization" \
  "type: chore,app: fuji-foundation,area: build,priority: medium" \
  "$MS_FOUNDATION" \
  "Set up full code signing and notarization pipeline.

- Entitlements: disable-library-validation, user-selected.read-write, network.client
- ExportOptions.plist: Developer ID, team X49M46V9N7, automatic signing
- scripts/build_release.sh: archive → export → hdiutil DMG → notarytool → staple
- SKIP_NOTARIZE=1 env var skips notarization for local testing

Note: Deployment config fails due to missing team cert X49M46V9N7 — pre-existing, not a regression.

**Commit:** 7970466")
close "$num" "7970466"

num=$(new \
  "Fix: SIO patch breaking non-standard ROMs" \
  "type: bug,app: fuji-foundation,area: emulation,priority: high" \
  "$MS_FOUNDATION" \
  "SIO patch was applied unconditionally, breaking boot on non-standard ROMs.

Added validation before applying the SIO speed patch so it only fires when the ROM signature matches the expected pattern.

**Branch:** fix/sio-patch-rom-validation
**Commit:** 8d4f3d4 (merge)")
close "$num" "8d4f3d4"

num=$(new \
  "Fix: Expose pixel aspect ratio toggle" \
  "type: bug,app: fuji-foundation,area: metal,priority: medium" \
  "$MS_FOUNDATION" \
  "Screen aspect ratio was not user-configurable; NTSC pixels appeared square.

Wired pixel aspect ratio preference through to the Metal renderer sampler.

**Branch:** fix/screen-aspect-ratio
**Commit:** c4a2e44 (merge)")
close "$num" "c4a2e44"

num=$(new \
  "Fix: SDL Game Controller support for M1 Macs" \
  "type: bug,app: fuji-foundation,area: input,priority: high" \
  "$MS_FOUNDATION" \
  "Game controllers were not recognized on Apple Silicon Macs.

Added SDL_GameController API support alongside the legacy SDL_Joystick path. M1/M2 Macs require the newer API for HID gamepad enumeration.

**Branch:** fix/m1-input-support
**Commit:** 73e4ff6 (merge)")
close "$num" "73e4ff6"

num=$(new \
  "Fix: Gamepad crashes from unicode controller names" \
  "type: bug,app: fuji-foundation,area: input,priority: medium" \
  "$MS_FOUNDATION" \
  "Gamepads with non-ASCII unicode characters in their names caused a crash during SDL device enumeration.

Added UTF-8 safe handling for controller name strings.

**Branch:** fix/gamepad-compatibility
**Commit:** 0e7495b (merge)")
close "$num" "0e7495b"

num=$(new \
  "Fix: Audio clicking and popping on modern macOS" \
  "type: bug,app: fuji-foundation,area: audio,priority: high" \
  "$MS_FOUNDATION" \
  "POKEY audio output had audible clicking and popping artifacts on macOS Sonoma/Sequoia.

Fixed audio buffer sizing and CoreAudio callback timing to prevent underruns on modern macOS audio subsystem.

**Branch:** fix/audio-clicking-popping
**Commit:** 602d849 (merge)")
close "$num" "602d849"

num=$(new \
  "Phase VBXE-1: Video Board XE emulation (synchronous blitter)" \
  "type: feature,app: fuji-foundation,area: vbxe,priority: high" \
  "$MS_FOUNDATION" \
  "Implemented VBXE hardware emulation derived from Altirra (Avery Lee, GPL v2).

**What's included:**
- 512 KB VBXE VRAM
- 256-color 21-bit RGB palette (7R 7G 7B)
- Register file at \$D640 or \$D740 (FX 1.26 layout, 256 bytes)
- MEMAC A/B: two 4 KB bank-switched CPU-visible windows into VRAM
- XDL renderer: LR (160px 8bpp), SR (320px 8bpp), HR (640px 4bpp) overlay modes
- Priority compositor: blends vbxe_overlay onto MetalFrameBuffer
- Synchronous 7-mode blitter: COPY, FILL, OR, AND, XOR, MOVE, STENCIL, ADD
- GTIA color forwarding for COLPM0–3, COLPF0–3, COLBK
- Full lifecycle: Initialise / Exit / ColdStart / WarmStart

**Limitations (deferred to VBXE-2):**
- Blitter is synchronous (done IRQ clears immediately on trigger write)
- Cycle-accurate DMA deferred
- StateSave/StateRead are stubs

Covers ~95% of known VBXE software (FX 1.26, standard display modes).
See LEGAL.md for Altirra derivation details.

**Branch:** feature/vbxe-emulation
**Commit:** d57254b (merge)")
close "$num" "d57254b"

echo ""
echo "=== fuji-vision — Completed ==="

num=$(new \
  "Phase V1: C core compiling for visionOS" \
  "type: feature,app: fuji-vision,area: build,priority: high" \
  "$MS_VISION" \
  "All 69 C core files build and link for visionOS arm64 (xrsimulator).

- XcodeGen project (project.yml) — visionOS 2.0+, SwiftUI lifecycle
- 60 portable C files + 5 bridge files + 4 Altirra ROM files
- Platform shims: preferences_vision.c, capslock_vision.c, vision_stubs.c
- mac_monitor.c included (replaces monitor.c — conflict on shared symbols)
- config.h defines: VISIONOS 1, ATARI800MACX, MACOSX (all three required)
- Resolved 10 build iterations: SDL deps, IOKit, system() unavailability, linker symbols

**Commit:** 7cab1ed")
close "$num" "7cab1ed"

num=$(new \
  "Phase V2: Metal rendering" \
  "type: feature,app: fuji-vision,area: metal,priority: high" \
  "$MS_VISION" \
  "Live Atari screen visible in a visionOS window.

- Source texture: .rgba8Unorm (matching C core RGBA output)
- Pipeline output: .bgra8Unorm (matching MTKView drawable)
- Metal handles RGBA→BGRA conversion during shader sampling
- Frame callback trampoline copies pixels on emu thread, dispatches to main for GPU upload
- MTKView at 60fps via display link

**Commit:** feb58ba")
close "$num" "feb58ba"

num=$(new \
  "Phase V3: Audio — AVAudioSourceNode pull model" \
  "type: feature,app: fuji-vision,area: audio,priority: high" \
  "$MS_VISION" \
  "POKEY sound output plays through visionOS audio system.

- AVAudioSourceNode render callback pulls from lock-free SPSC ring buffer via Vision_Sound_Read()
- Format: 44100 Hz, 16-bit signed integer, stereo interleaved
- Zero-fills remainder on underrun (prevents clicks)
- Pause/resume for app lifecycle

**Commit:** feb58ba")
close "$num" "feb58ba"

num=$(new \
  "Phase V4: Input — GCController + on-screen controls" \
  "type: feature,app: fuji-vision,area: input,priority: high" \
  "$MS_VISION" \
  "Full joystick and keyboard input via gamepad and virtual controls.

- Console keys (Start/Select/Option) use INPUT_key_consol bit-clearing
- Vision_Input_ConsoleKeyDown/Up() added to platform_bridge.h
- D-pad + left thumbstick → joystick directions (0.3 deadzone)
- A=Fire, B=Start, X=Select, Y=Option, L1=Space, R1=Return, Menu=WarmReset
- On-screen virtual joystick + console key buttons

**Commit:** feb58ba")
close "$num" "feb58ba"

num=$(new \
  "Phase V5: File management — UTType, importer, persistence" \
  "type: feature,app: fuji-vision,area: storage,priority: medium" \
  "$MS_VISION" \
  "Users can import and manage Atari media files.

- UTType declarations for 6 Atari types: .atr/.xfd/.car/.xex/.cas/.a8s
- AtariUTTypes.swift with Swift UTType constants
- File importer filters by media type with .data fallback
- mountedMedia dictionary with eject support
- UserDefaults persistence: last-mounted paths restored on launch
- visionOS ornament status bar showing mounted media
- Disk LED indicator (green=read, red=write)

**Commit:** be2bd91")
close "$num" "be2bd91"

num=$(new \
  "Phase V6: Settings, save states, and app lifecycle polish" \
  "type: feature,app: fuji-vision,area: ui,priority: medium" \
  "$MS_VISION" \
  "Production-quality user experience layer.

- SettingsView.swift: Display (TV mode, artifacting, bilinear, CRT scanlines), Audio (enable, volume, stereo POKEY), Speed (limit toggle, multiplier 50–400%), Machine (model selection)
- SaveStateView.swift: 10-slot save state manager with modification dates
- App lifecycle: scenePhase monitoring pauses/resumes emulation+audio
- All settings use @AppStorage for persistence

**Commit:** e41c4a6")
close "$num" "e41c4a6"

num=$(new \
  "Phase V7a: Visibility compositor — transparency, chroma key, pass-through" \
  "type: feature,app: fuji-vision,area: metal,priority: medium" \
  "$MS_VISION" \
  "Transparency modes and chroma keying for visionOS spatial pass-through rendering.

- VisibilityCompositor.swift: Solid (1.0), Dim (0.6), Ghost (0.2), Peek (0.15 held)
- Chroma key: configurable color, threshold, soft-edge feathering via smoothstep
- Background auto-detection: border pixel sampling every 30 frames, 4-bit histogram, 3-scan hysteresis
- Edge enhancement at key boundaries
- FragParams expansion in Shaders.metal and EmulatorRenderer.swift
- Alpha blending on pipeline; MTKView isOpaque=false for pass-through
- All transitions lerp over 0.3s (Section 11 comfort compliance)
- Peek gesture: hold-to-peek-through with smooth return

**Branch:** fuji-vision-compositor
**Commit:** 527f223")
close "$num" "527f223"

echo ""
echo "=== fuji-services — Completed ==="

num=$(new \
  "FSSP protocol specification v0.1" \
  "type: chore,app: fuji-services,area: docs,priority: high" \
  "$MS_SERVICES" \
  "Authored FUJI_SERVICES_SESSION_PROTOCOL_FSSP.md — the protocol spec.

Covers: transport (HTTPS/WebSocket), session lifecycle, frame format, channel types (CONTROL/DATAGRAM/STREAM/INPUT/VIDEO), well-known channel IDs, INPUT payload format, multiplayer hooks, error codes, security considerations.

Lives at repo root: \`FUJI_SERVICES_SESSION_PROTOCOL_FSSP.md\`")
close "$num"

num=$(new \
  "FSSP core: frame codec, session layer, WebSocket transport" \
  "type: feature,app: fuji-services,area: networking,priority: high" \
  "$MS_SERVICES" \
  "Go implementation of the FSSP protocol core.

**pkg/fssp:** 20-byte binary frame header, Encode/Decode/ReadFrom, all control message types (Hello/Welcome/ChanOpen/Ping/Pong/Close), channel type constants, well-known channel IDs.

**pkg/transport:** gorilla/websocket conn wrapper — Dial (client), Upgrade (server), thread-safe write, automatic ping/pong keepalive.

**pkg/session:** server + client handshake, channel registry, frame dispatcher, control handler (auto-pong, auto-close), RegisterHandler for per-channel-type routing.

14 tests passing. Benchmarked encode/decode.

**Commit:** aafa9e3")
close "$num" "aafa9e3"

num=$(new \
  "FSSP: TNFS UDP proxy adapter (sidecar for existing TNFS servers)" \
  "type: feature,app: fuji-services,area: networking,priority: high" \
  "$MS_SERVICES" \
  "pkg/tnfs — UDP↔FSSP DATAGRAM bridge. Existing TNFS servers require zero modifications.

- Proxy (edge side): receives DATAGRAM frames, forwards as UDP to local TNFS server, returns responses
- BridgeUDP (bridge side): listens on UDP 16384, injects packets as DATAGRAM frames
- Per-session UDP socket isolation (keyed by sessionID+channelID)
- Idle socket reaping (configurable timeout)

Run alongside any TNFS server: \`fssp-edge -tnfs 127.0.0.1:16384\`

**Commit:** aafa9e3")
close "$num" "aafa9e3"

num=$(new \
  "FSSP: Telnet STREAM proxy, INPUT encoder, NAT relay" \
  "type: feature,app: fuji-services,area: networking,priority: high" \
  "$MS_SERVICES" \
  "Three packages completing the fuji-services transport layer.

**pkg/telnet:** bidirectional TCP↔FSSP STREAM proxy. Per-session TCP connections, continuous read loops, zero-length frame = EOF signal. BridgeTCP for client side.

**pkg/input:** INPUT frame encoder/decoder. JoystickEvent (4-byte: controllerID, buttons bitfield U/D/L/R/F1-F4, seq) and KeyEvent (4-byte: type, scancode, modifiers, seq) with Atari scancode constants.

**cmd/fssp-relay:** WebSocket relay for NAT traversal. Pairs two peers by shared room token, forwards raw WebSocket messages bidirectionally. Protocol-version agnostic.

**Commit:** bcd7654")
close "$num" "bcd7654"

num=$(new \
  "FSSP: VIDEO frame codec and broadcaster" \
  "type: feature,app: fuji-services,area: metal,priority: high" \
  "$MS_SERVICES" \
  "pkg/video — VIDEO channel frame compression and fan-out.

- 8-byte payload header: encoding, flags (keyframe/delta), width, height, sequence
- Encoder: zlib/deflate or raw RGBA. sync.Pool for zlib writer reuse. Solid-color Atari frame: 360 KB → 0.5 KB (ratio 0.001).
- Decoder: decompress VIDEO payload → raw RGBA Frame struct
- Broadcaster: encode once, fan out to N FSSP sessions. Auto-removes failed subscribers.

5 tests + 2 benchmarks passing.

**Commit:** 93b4d5f")
close "$num" "93b4d5f"

num=$(new \
  "fuji-server Phase FS1: headless server skeleton" \
  "type: feature,app: fuji-server,area: build,priority: high" \
  "$MS_SERVICES" \
  "cmd/fuji-server — headless multi-user emulation server skeleton.

**pkg/server:**
- EmulatorInstance interface (the CGo implementation will satisfy this)
- StubInstance: animated 60Hz HSV test-pattern generator for pipeline dev without C core
- Manager: Create/Destroy instances, JoinPlayer (INPUT routing to joystick port 0–3), JoinSpectator (VIDEO-only), auto-cleanup on session end
- Lobby: cryptographically random single-use join tokens with configurable TTL

**cmd/fuji-server:**
- FSSP WebSocket endpoint (public, TLS): token auth via Lobby, session handshake, player/spectator routing
- Admin HTTP API (loopback only): POST/GET /api/instances, DELETE instance, POST /api/instances/{id}/join
- -max-instances flag caps concurrent sessions

**Commit:** 93b4d5f")
close "$num" "93b4d5f"

echo ""
echo "=== web / monorepo — Completed ==="

num=$(new \
  "beta.fujiconcepts.com website scaffold" \
  "type: feature,app: web,area: docs,priority: medium" \
  "$MS_FOUNDATION" \
  "Static marketing/info site for beta.fujiconcepts.com.

- 8 HTML pages: index, fuji-foundation, fuji-vision, fuji-swift, fuji-dynasty, fuji-services, downloads, about
- Hosted on VPS root@159.198.64.231, Apache 2.4.58, Ubuntu 24.04
- TLS via Let's Encrypt (certbot), expires 2026-06-03
- Deploy: rsync -avz web/beta/ root@159.198.64.231:/var/www/beta.fujiconcepts.com/

**Commits:** 568fa7a, 36a19cc")
close "$num" "36a19cc"

num=$(new \
  "GitHub Actions deploy workflow for beta.fujiconcepts.com" \
  "type: chore,app: web,area: build,priority: low" \
  "$MS_FOUNDATION" \
  "Automated rsync deploy pipeline for the beta website.

GitHub Actions workflow that deploys web/beta/ to the VPS on push to master.

**Commit:** 36a19cc")
close "$num" "36a19cc"

num=$(new \
  "Project management framework: labels, milestones, issue templates" \
  "type: chore,app: monorepo,area: docs,priority: medium" \
  "$MS_FOUNDATION" \
  "GitHub Issues tracking system adapted from commodorecaverns framework.

Key addition for this monorepo: \`app:\` label dimension scopes every issue to its target app. A feature for fuji-services cannot be assumed to apply to fuji-vision.

- 4 label dimensions: type / priority / app / area + status exceptions
- 9 app: labels covering all current and planned apps
- 7 milestones matching the Fuji roadmap
- 4 issue templates (feature, bug, discussion, chore) — all require App field
- setup.sh creates everything via gh CLI

**Commit:** 4b48e8d")
close "$num" "4b48e8d"

echo ""
echo "=== fuji-foundation — Roadmap ==="

new \
  "Phase VBXE-2: Cycle-accurate DMA timing" \
  "type: feature,app: fuji-foundation,area: vbxe,priority: medium" \
  "$MS_NEAR" \
  "Upgrade the VBXE blitter from synchronous to cycle-accurate DMA.

**Current state:** Blitter-done IRQ status bit clears immediately on trigger write. Covers ~95% of VBXE software.

**What's needed:**
- DMA cycle counting per scanline
- Blitter-done IRQ fires after correct number of cycles
- Covers remaining 5% of VBXE software that polls the status bit
- StateRead/StateSave integration (currently stubs)

**Blocked by:** Nothing. Ready to start.
**Effort:** Medium (a few days)"

new \
  "Phase VBXE: Preferences UI toggle for VBXE enable/disable" \
  "type: feature,app: fuji-foundation,area: vbxe,priority: low" \
  "$MS_NEAR" \
  "Add a user-facing toggle to enable/disable VBXE emulation.

Currently VBXE is enabled only via Ultimate 1MB \$D381 register.
A Preferences tab (or menu item) should allow toggling VBXE on/off and selecting the register base (\$D640 or \$D740).

**Effort:** Low"

new \
  "Phase 8: SDL3 migration" \
  "type: chore,app: fuji-foundation,area: build,priority: someday" \
  "$MS_BACKLOG" \
  "Migrate from SDL2 v2.0.14 to SDL3.

**Current state:** SDL2 universal binary (x86_64 + arm64) embedded. Working.

**Blockers (as of 2026-03-07):**
- Audio API complete rewrite: SDL_OpenAudio removed
- Joystick index→ID API rewrite throughout
- SDL_SysWMinfo structure change
- SDLWindow.m uses SDL 1.2 internal APIs (dead code, but indicates complexity)

Revisit when SDL audio + joystick can be refactored together.
**Status:** Blocked on SDL3 stability."

new \
  "SwiftUI Preferences: complete Input, Peripherals, and Paths tabs" \
  "type: feature,app: fuji-foundation,area: ui,priority: medium" \
  "$MS_NEAR" \
  "The Phase 7 SwiftUI Preferences panel has 3 stub tabs.

- Input tab: key mapping, joystick configuration
- Peripherals tab: printer, R: device, SIO device configuration
- Paths tab: ROM paths, disk image directories, save state location

**Effort:** Medium"

echo ""
echo "=== fuji-vision — Roadmap ==="

new \
  "Phase V7b: Immersive Space — 3D CRT model" \
  "type: feature,app: fuji-vision,area: spatial,priority: medium" \
  "$MS_MID" \
  "Place the Atari emulator inside a 3D CRT television floating in the user's physical space.

**Approach:**
- CompositorServices for custom Metal rendering in immersive mode
- RealityKit entity with CRT mesh + emulator texture as emissive material
- ImmersiveSpace scene type in SwiftUI

**Dependencies:** Phase V2 (Metal) done ✓
**Effort:** High
**Spec:** apps/fuji-vision/FUJI_VISION_SPEC_FEATURE_ADDENDUM_MARCH_2026.md"

new \
  "Phase V7c: Spatial Audio — head-tracked POKEY output" \
  "type: feature,app: fuji-vision,area: spatial,priority: low" \
  "$MS_LONG" \
  "Position POKEY audio to emanate from the virtual CRT's location in 3D space.

- PHASESpatialMixerDefinition for head-tracked audio
- Audio position updated as user moves relative to the virtual CRT
- Requires Phase V7b (ImmersiveSpace) to know the CRT's world position

**Dependencies:** Phase V7b
**Effort:** Medium"

new \
  "Phase V7d: Hand Tracking — gestures to joystick/keyboard" \
  "type: feature,app: fuji-vision,area: spatial,priority: low" \
  "$MS_LONG" \
  "Map ARKit hand gestures to joystick directions and keyboard input.

- ARKit hand tracking API
- Pinch gesture → fire button
- Swipe gestures → joystick directions
- Proximity to virtual keyboard → key press

**Dependencies:** Phase V7b (ImmersiveSpace for coordinate space)
**Effort:** High"

new \
  "Multi-window: independent emulator instances per window" \
  "type: feature,app: fuji-vision,area: ui,priority: someday" \
  "$MS_LONG" \
  "Allow opening multiple emulator instances in separate visionOS windows.

Each window would run an independent EmulatorSession with its own CPU state, media, and audio.

**Effort:** High
**Blocked by:** Memory and threading audit needed."

new \
  "SharePlay: multiplayer over FaceTime" \
  "type: feature,app: fuji-vision,area: networking,priority: someday" \
  "$MS_LONG" \
  "Shared joystick ports over FaceTime GroupActivities.

Player 1 retains local joystick port 0; other FaceTime participants control ports 1–3 via SharePlay. Game state synchronized via state hash.

**Effort:** High
**Dependencies:** Phase V7 complete, FSSP INPUT channel spec finalized"

echo ""
echo "=== fuji-services — Roadmap ==="

new \
  "VIDEO delta encoding: dirty-rect LZ4 for bandwidth reduction" \
  "type: feature,app: fuji-services,area: networking,priority: medium" \
  "$MS_NEAR" \
  "Reduce VIDEO channel bandwidth from ~1.2 Mbit/s to ~200 Kbit/s on typical Atari frames.

**Current (v1):** Full frame zlib per FSSP VIDEO frame. Solid color: 0.5 KB. Typical gameplay: 15–60 KB @ 60fps.

**Proposed (v2):**
- Split frame into 8×8 blocks
- Send only changed blocks per frame
- Block header: x, y (uint16) + compressed block data (LZ4)
- Keyframe every 60 frames or on scene change
- Decoder patches MTLTexture in-place

**See:** apps/fuji-services/docs/FEATURE_IOS_REMOTE_CLIENT.md
**Effort:** Medium"

new \
  "Edge VIDEO push: hook fuji-foundation frame buffer into FSSP" \
  "type: feature,app: fuji-services,area: metal,priority: high" \
  "$MS_NEAR" \
  "Wire the fuji-foundation Metal frame buffer into FSSP VIDEO frames so connected clients receive the live screen.

**What's needed:**
- Hook in atari_mac_sdl.c / EmulatorMetalView.m to capture each rendered frame
- Pass to an FSSP VideoSource that feeds the Broadcaster
- fssp-edge advertises VIDEO capability in Hello/Welcome negotiation
- Clients subscribe to VIDEO channel and receive compressed frames

**Effort:** Medium
**Dependencies:** pkg/video Broadcaster done ✓"

new \
  "Authentication hardening: token rotation and expiry" \
  "type: chore,app: fuji-services,area: networking,priority: medium" \
  "$MS_NEAR" \
  "Current auth is bearer token + open mode fallback. Production needs:

- Short-lived token issuance (15 min default)
- Refresh token flow
- Token revocation
- Rate limiting on /fssp endpoint (connections per IP per minute)
- Structured logging for auth events

**Effort:** Medium"

new \
  "fuji-server Phase FS2: real CGo C core integration" \
  "type: feature,app: fuji-server,area: build,priority: high" \
  "$MS_MID" \
  "Replace StubInstance with a real emulator backed by the fuji-foundation C core via CGo.

**Approach options (unresolved — see Discussion issue):**
- Option A: CGo — link libfujicore.a statically. Lower latency, requires headless build.
- Option B: Subprocess — run Atari800MacX with --headless, communicate via pipes/shared memory.

**What's needed either way:**
- Headless build of fuji-foundation C core (no SDL window, no display)
- Frame buffer accessible to Go layer
- Input writable from Go layer
- Linux cross-compilation (VPS deployment target)

**Effort:** High
**Spec:** apps/fuji-services/docs/FEATURE_HEADLESS_SERVER.md"

new \
  "[DISCUSS] fuji-server: CGo vs subprocess for C core integration" \
  "type: discussion,app: fuji-server,area: build,priority: high" \
  "$MS_MID" \
  "Phase FS2 requires running the fuji-foundation C emulator headlessly from Go. The choice of integration method affects build complexity, latency, isolation, and Linux portability.

**Option A: CGo**
Link \`libfujicore.a\` directly. Lower latency (~0ms IPC). Tighter integration. Requires a headless static library build of fuji-foundation (no Xcode on server, must cross-compile for Linux/amd64).

**Option B: Subprocess**
Run Atari800MacX with a \`--headless\` flag, communicate via stdin/stdout protocol or shared memory. Better process isolation (crash doesn't take down server). Easier to kill/restart per session. Adds ~1ms IPC overhead.

**Option C: Defer**
Keep StubInstance for FS2, deliver FS3/FS4/FS5 against the stub, revisit CGo when C core headless build is ready.

**Constraints:**
- Must run on Linux (VPS)
- Must support 16 concurrent instances
- Must not require Xcode on the server
- Frame capture latency < 16ms

**Decision needed before:** Roadmap — Mid Term work starts on fuji-server FS2"

new \
  "fuji-server Phase FS3: multi-player INPUT routing" \
  "type: feature,app: fuji-server,area: networking,priority: medium" \
  "$MS_MID" \
  "Route INPUT frames from each connected player session to the correct joystick port in the emulator.

**Spec:**
- Player 1 → PIA_PORT_input[0] / GTIA_TRIG[0]
- Player 2 → PIA_PORT_input[1] / GTIA_TRIG[1]
- Player 3/4 → ports 2/3
- Server enforces port assignment, rejects conflicts
- INPUT frame rate limiting per session (anti-flooding)
- Late frame policy: drop frames older than threshold (TBD: 100ms? 200ms?)

**Dependencies:** Phase FS2 (real emulator instance)
**Effort:** Medium"

new \
  "fuji-server Phase FS4: lobby API and join token UI" \
  "type: feature,app: fuji-server,area: ui,priority: medium" \
  "$MS_MID" \
  "Public session listing and streamlined token distribution.

- GET /lobby — public unauthenticated endpoint listing open instances (title, player count, game)
- Join token as a short URL / QR code for easy sharing
- Session titles: admin sets a human-readable name on instance creation
- Optional password protection per session

**Effort:** Low–Medium"

new \
  "fuji-server Phase FS5: save state management" \
  "type: feature,app: fuji-server,area: storage,priority: low" \
  "$MS_LONG" \
  "Server-side save state persistence for hosted sessions.

- Auto-snapshot on session end (all players disconnect)
- Manual snapshot via admin API: POST /api/instances/{id}/snapshot
- Load state: POST /api/instances/{id}/load with snapshot ID
- State hash broadcast to clients every N frames for sync verification
- Storage backend: local filesystem initially, S3 future

**Dependencies:** Phase FS2 + FS3
**Effort:** Medium"

echo ""
echo "=== fuji-remote (iOS) — Roadmap ==="

new \
  "fuji-remote Phase R1: FSSPClient Swift WebSocket connection" \
  "type: feature,app: fuji-remote,area: networking,priority: high" \
  "$MS_MID" \
  "iOS Swift FSSP client library — the foundation for Fuji Remote.

- FSSPClient.swift: URLSessionWebSocketTask-based (no third-party deps)
- Frame encode/decode matching Go pkg/fssp wire format
- Hello/Welcome handshake (client side)
- Automatic reconnect with exponential backoff
- Connection state published via Combine/AsyncStream

**See:** apps/fuji-services/docs/FEATURE_IOS_REMOTE_CLIENT.md
**Effort:** Medium"

new \
  "fuji-remote Phase R2: Metal VIDEO frame rendering" \
  "type: feature,app: fuji-remote,area: metal,priority: high" \
  "$MS_MID" \
  "Display the live Atari screen on iPhone via FSSP VIDEO frames.

- MTKView-based EmulatorView (UIViewRepresentable for SwiftUI)
- Receive VIDEO frames from FSSPClient, decompress, upload to MTLTexture
- Maintain aspect ratio (384×240 with pixel aspect correction)
- 60fps target with frame drop on backpressure

**Dependencies:** Phase R1
**Effort:** Medium"

new \
  "fuji-remote Phase R3: GCController + on-screen INPUT" \
  "type: feature,app: fuji-remote,area: input,priority: high" \
  "$MS_MID" \
  "Send joystick and keyboard INPUT frames from iPhone to the edge/server.

- On-screen D-pad + fire button → JoystickEvent FSSP frames
- Console keys (Start/Select/Option/Reset) → INPUT frames
- MFi gamepad support via GCController
- Haptic feedback on fire button
- Keyboard accessory view for Atari text input

**Dependencies:** Phase R1
**Effort:** Medium"

new \
  "fuji-remote Phase R4: Connection UI and token entry" \
  "type: feature,app: fuji-remote,area: ui,priority: medium" \
  "$MS_MID" \
  "User interface for connecting to a Fuji edge or server.

- Host URL entry field (wss://...)
- Token entry (paste or QR code scan via camera)
- Relay mode toggle with room token entry
- Connection history (recently connected hosts)
- Latency indicator (RTT from CONTROL ping/pong)
- Frame rate display

**Dependencies:** Phase R1
**Effort:** Low–Medium"

echo ""
echo "=== monorepo — Roadmap ==="

new \
  "Rename GitHub repo from Atari800MacX to fuji-concepts" \
  "type: chore,app: monorepo,area: build,priority: medium" \
  "$MS_NEAR" \
  "The monorepo should be named fuji-concepts to reflect its expanded scope.

**Steps:**
1. Rename on GitHub: Settings → Rename repository
2. Update all local git remotes: git remote set-url origin
3. Update MEMORY.md and any hardcoded references
4. Update README.md
5. Redirect will exist automatically from the old URL

**Impact:** All clone URLs will redirect; existing checkouts need remote update."

new \
  "fuji-swift: define roadmap and scaffold" \
  "type: discussion,app: fuji-swift,area: build,priority: low" \
  "$MS_BACKLOG" \
  "apps/fuji-swift/ exists as a scaffold but has no defined roadmap.

Define: what differentiates fuji-swift from fuji-foundation? Proposed: lighter-weight, Swift-first macOS app targeting a simpler UI and faster launch, sharing the C core with fuji-foundation.

**Questions to resolve:**
- Does fuji-swift share the ObjC UI layer or replace it entirely with SwiftUI?
- What features are in scope vs fuji-dynasty?
- Is this a separate Xcode target or separate project?"

new \
  "fuji-dynasty: define roadmap and scaffold" \
  "type: discussion,app: fuji-dynasty,area: build,priority: low" \
  "$MS_BACKLOG" \
  "apps/fuji-dynasty/ exists as a scaffold but has no defined roadmap.

Define: what differentiates fuji-dynasty from fuji-foundation? Proposed: modular plugin architecture, advanced features (enhanced debugger, scripting, peripheral simulation), targeting power users.

**Questions to resolve:**
- Plugin API design (how do peripheral modules plug in?)
- Relationship to fuji-foundation code base (fork or shared core?)
- Priority relative to fuji-remote and fuji-server?"

echo ""
echo "============================================"
echo "Issue seeding complete."
echo "View at: https://github.com/davidwhittington/Atari800MacX/issues"
echo "============================================"
