# Fuji-Services Session Protocol Specification (FSSP)

**Version:** 0.1-draft  
**Status:** Draft  
**Last Updated:** 2026-03-01  
**License:** Open (MIT or Apache-2.0 recommended)

---

## 0. Document Control

### 0.1 Change Log
| Date | Version | Summary | Author |
|------|---------|---------|--------|
| 2026-03-01 | 0.1-draft | Initial full protocol specification | Fuji Concepts |

### 0.2 Conformance Language
The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** are to be interpreted as described in RFC 2119.

---

## 1. Scope

### 1.1 Purpose
Fuji-Services Session Protocol (FSSP) defines a secure, multiplexed session protocol for transporting legacy and modern protocols unchanged over encrypted transports. It is designed to enable secure access, low-latency interaction, and multiplayer collaboration for retro-computing systems.

### 1.2 Out of Scope
- Redefinition of TNFS, Telnet, FTP, SMB, or similar protocols
- Firmware-level behavior for FujiNet
- Game logic synchronization semantics

### 1.3 Design Goals
- Payload transparency
- Low overhead for small messages
- Secure-by-default transport
- NAT-friendly operation
- Extensible channel model

---

## 2. Terminology

- **Session:** A secure, authenticated connection context
- **Channel:** A logical communication lane within a session
- **Frame:** A single protocol unit sent over the transport
- **Bridge:** Local endpoint near the retro system or emulator
- **Edge:** Remote endpoint near target services
- **Relay:** Optional neutral router for NAT traversal
- **Payload:** Opaque bytes carried by Fuji-Services

---

## 3. Threat Model

### 3.1 Assumptions
- Networks may be hostile
- Passive and active interception is possible

### 3.2 Protections
- Confidentiality via TLS 1.3
- Integrity via TLS
- Endpoint authentication

---

## 4. Transport Layer

### 4.1 Mandatory Transport
- HTTPS over port 443
- WebSocket over TLS

### 4.2 Optional Transports
- HTTP/2 streaming
- HTTP/3
- WireGuard (outside protocol, implementation-level)

---

## 5. Session Lifecycle

### 5.1 Establishment
1. Client initiates TLS connection
2. Authentication performed
3. Session ID assigned

### 5.2 Keepalive
- Ping frame every configurable interval

### 5.3 Termination
- Graceful close or forced close with code

---

## 6. Authentication & Authorization

### 6.1 MVP Authentication
- Bearer token

### 6.2 Authorization
- Session-level permissions
- Channel-level permissions

---

## 7. Framing Format

### 7.1 Frame Structure
All frames consist of a fixed header followed by payload bytes.

```
0                   1                   2                   3
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| Version | Flags | ChannelType |        Header Length           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Session ID (64-bit)                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Channel ID (32-bit)                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Payload Length (32-bit)                 |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                        Payload Bytes                           |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 7.2 Encoding
- Network byte order (big endian)
- Version starts at `0x01`

---

## 8. Channel Types

### 8.0 CONTROL (0x00)
- Session control-plane messages
- Capabilities negotiation
- Channel open/close and QoS hints
- Errors and close reasons

CONTROL frames SHOULD be used for protocol-level control operations rather than overloading application STREAM channels.

### 8.1 DATAGRAM (0x01)
- Unordered
- Best effort
- Use cases: TNFS, discovery

### 8.2 STREAM (0x02)
- Ordered, reliable
- Use cases: Telnet, COM streams

### 8.3 INPUT (0x03)
- Prioritized delivery
- Use cases: joystick and keyboard input

### 8.4 VIDEO (0x04)
- Optional
- Use cases: framebuffer streaming

---

## 9. Channel Allocation & Requirements

### 9.1 Minimum Channel Support
Implementations **MUST** support at least **16 concurrently open channels** per session.

### 9.2 Full-Duplex Behavior
All channels are **full-duplex by default** (bidirectional). A future extension MAY define a unidirectional flag, but v0.1 assumes duplex operation.

### 9.3 Well-Known Channel IDs (0–15)
The following channel IDs are **reserved** to improve interoperability. Implementations MAY open additional channels beyond this range.

| Channel ID | Purpose | Channel Type |
|---:|---|---|
| 0 | Control Plane | CONTROL |
| 1 | Telnet / BBS | STREAM |
| 2 | Modem / COM A | STREAM |
| 3 | Modem / COM B | STREAM |
| 4 | TNFS / UDP A | DATAGRAM |
| 5 | TNFS / UDP B | DATAGRAM |
| 6 | Joystick P1 | INPUT |
| 7 | Joystick P2 | INPUT |
| 8 | Joystick P3 | INPUT |
| 9 | Joystick P4 | INPUT |
| 10 | Keyboard | INPUT |
| 11 | Video Primary | VIDEO |
| 12 | Video Secondary / Spectator | VIDEO |
| 13–15 | Reserved / Plugin Lanes | Any |

### 9.4 Capability Negotiation (MVP)
On session establishment, the client SHOULD send a CONTROL message advertising:
- supported channel types
- maximum channels
- optional features (VIDEO, state-hash hooks)

The server SHOULD reply with the negotiated capabilities.

---

## 10. INPUT Payload Specification

### 10.1 Joystick Payload
```
Byte 0: Controller ID
Byte 1: Button Bitfield (U D L R F1 F2 F3 F4)
Byte 2: Reserved
Byte 3: Sequence Number
```

### 10.2 Keyboard Payload
```
Byte 0: Event Type (0=up,1=down)
Byte 1: Scancode
Byte 2: Modifier Bitfield
Byte 3: Sequence Number
```

---

## 11. Multiplayer Support Hooks

### 11.1 State Hash Frame (Optional)
- Used for deterministic verification

### 11.2 Resync Request Frame
- Requests state resynchronization

---

## 12. Error Handling

### 12.1 Close Codes
- 0x00 Normal
- 0x01 Auth Failed
- 0x02 Unsupported Channel
- 0x03 Policy Violation

---

## 13. Observability

Recommended metrics:
- RTT
- Jitter
- Packet loss
- Bytes per channel

---

## 14. Versioning & Compatibility
- Semantic versioning
- Backward-compatible extensions preferred

---

## 15. Security Considerations
- TLS 1.3 required
- Short-lived tokens recommended
- Rate limiting encouraged

---

## 16. Reference Implementations
- Bridge: Go
- Edge: Go
- Relay: Go
- Client Integration: Swift

---

## 17. Examples

### 17.1 Telnet Session
- STREAM channel opened
- Bytes forwarded bidirectionally

### 17.2 TNFS Session
- DATAGRAM frames forwarded

### 17.3 Netplay Session
- INPUT frames at fixed cadence

---

## 18. Registries

### 18.1 Channel Type Registry
- 0x00 CONTROL
- 0x01 DATAGRAM
- 0x02 STREAM
- 0x03 INPUT
- 0x04 VIDEO

---

## 19. Summary
Fuji-Services provides a secure, extensible session protocol that enables retro systems to interact across modern networks without rewriting history.
