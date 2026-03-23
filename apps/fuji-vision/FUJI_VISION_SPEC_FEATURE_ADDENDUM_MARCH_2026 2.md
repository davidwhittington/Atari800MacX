
# Fuji Vision — Feature Addendum
## March 2026

This document supplements the primary **FUJI_VISION_BLUEPRINT.md** and captures additional architectural and UX capabilities proposed for the Fuji Vision spatial client.

Fuji Vision is designed as a **spatial Atari interface for Apple Vision Pro**, emphasizing presence, comfort, and shared experiences. The features below extend the original blueprint with remote control capabilities, FujiNet integration, and advanced visibility controls tailored for spatial computing.

---

# 1. Remote Emulator Control (Mac Host)

Fuji Vision should be capable of controlling an emulator instance running on a Mac.

This enables Vision Pro to act as a **remote Atari console interface**, while the Mac performs the actual emulation workload.

## Host Control Service

New Fuji Services module:

HostControlService

Responsibilities:

- Discover emulator hosts (LAN / invite link / directory)
- Query host capabilities
- Start / Stop / Pause / Reset emulator
- Mount or eject cartridges and disk images
- Request save state or checkpoint
- Provide session metadata

### Host Control Messages

Examples:

ListHosts
HostCapabilities
StartEmulator
StopEmulator
PauseEmulator
ResetEmulator
MountMedia
EjectMedia
RequestState

### Roles

Sessions introduce a new role:

Operator

Capabilities may include:

- Mount media
- Control emulator
- Provide joystick input
- Spectate without control

Permissions are controlled via session policy tokens.

---

# 2. FujiNet Remote Content Bridge

Fuji Vision should be able to browse **FujiNet.online** content libraries even when the emulator is running remotely.

Vision functions as a **media browser**, while the host machine performs the actual mount.

## FujiNetBridge Module

Responsibilities:

- Authenticate with FujiNet services
- Browse cartridge collections
- Search titles
- Return media identifiers
- Generate mount intents

Example workflow:

1. Vision connects to FujiNet
2. User browses cartridges
3. Vision sends MountIntent
4. Mac host mounts the cartridge

### MountIntent Example

MountIntent
{
  mediaType: "cartridge",
  uri: "fujinet://collection/space_invaders",
  slot: "CART"
}

---

# 3. Cartridge Selection Protocol

Media selection becomes a first-class Fuji Services protocol feature.

Messages:

ListMediaSources
BrowseCollection(path)
SearchMedia(query)
SelectCartridge(mediaId)
MountMedia(intent)

Host Response:

MountResult
{
  success: true,
  message: "Cartridge mounted"
}

This protocol allows Swift, Vision, Foundation, and Dynasty clients to share a consistent cartridge mounting model.

---

# 4. Remote Console Mode

Fuji Vision supports a **RemoteConsole gameplay mode**.

In this configuration:

- Mac host runs emulator
- Vision receives video stream
- Vision sends controller input
- Vision may issue host control commands

Transport Channels:

Control Plane
Input Fast Lane
Audio Stream
Video Stream
Diagnostics

Sync Modes:

- Video Stream (primary for Vision)
- State Sync (optional if compatibility verified)
- Hybrid

---

# 5. Virtual Input System

Vision Pro may operate without physical controllers.

A virtual input module allows spatial interaction with Atari titles.

VirtualInputKit

Capabilities:

- Virtual joystick
- Tap buttons (Fire / Start / Select)
- Paddle simulation
- Optional analog interpretation for 5200 titles

Virtual inputs generate standard emulator InputSnapshot messages so the emulator core remains unchanged.

---

# 6. Input Fast Lane Channel

Low latency input delivery is required when Vision is controlling a remote host.

InputFastLane prioritizes controller packets over video data.

Features:

- Timestamped input events
- Packet prioritization
- Jitter smoothing
- Conservative prediction (optional)

---

# 7. Visibility Modes (Spatial Awareness)

Fuji Vision introduces Visibility Modes to allow users to remain aware of their environment while playing.

Mode presets:

Solid — Standard opaque display  
Dim — Reduced opacity HUD style  
Ghost — Highly transparent display  
Peek — Temporary fade while control held

---

# 8. Black-Key Transparency

Many Atari games feature black backgrounds.

Fuji Vision can treat near-black pixels as transparent so gameplay floats in the room.

Controls:

- Key color (default black)
- Threshold slider
- Soft edge feathering
- Invert mode

---

# 9. Background Color Detection

Some titles use dark colors rather than pure black.

Vision can detect background color automatically.

Detection algorithm:

1. Sample border pixels
2. Determine dominant color
3. Apply hysteresis smoothing
4. Use detected color as transparency key

Controls:

- Auto Detect ON/OFF
- Sensitivity
- Lock detected color

---

# 10. Visibility Compositor

New rendering module for Vision.

VisibilityCompositor

Responsibilities:

- Apply fade / opacity
- Apply chroma key transparency
- Enhance edges when transparency active
- Maintain readability against real world background

Pipeline:

Emulator Frame
→ VisibilityCompositor
→ Spatial Material
→ VisionOS Scene

This compositor exists only in Fuji Vision and does not modify shared emulator code.

---

# 11. Comfort Design Principles

All Vision features follow spatial comfort rules:

- Avoid abrupt motion
- Avoid rapid opacity changes
- Maintain readable contrast
- Provide quick return to solid display

Default configuration:

Solid display with transparency features disabled until enabled.

---

# 12. Future Expansion

Possible future work:

- Spatial Atari cabinet shell
- Multi-screen gameplay surfaces
- Persistent room layouts
- Cloud sync of screen placement
- Session bookmark system

---

# Summary

This addendum expands Fuji Vision into three major capability areas:

1. Remote Atari Console Control
2. FujiNet Content Browsing
3. Spatial Visibility / HUD Gameplay Modes

Together these position Fuji Vision as:

- a spatial Atari console
- a remote emulator control surface
- a social spectator platform
