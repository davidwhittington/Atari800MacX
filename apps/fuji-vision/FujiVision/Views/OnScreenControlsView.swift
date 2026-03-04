/* OnScreenControlsView.swift — Virtual joystick and console key overlay
 *
 * Provides touch/gaze-based controls for when no physical gamepad is
 * connected. On visionOS, these are activated via gaze + pinch gestures.
 *
 * Layout:
 *   Left side:  Virtual D-pad (joystick directions)
 *   Right side: Fire button
 *   Center top: Console keys (Start, Select, Option, Reset)
 */

import SwiftUI

struct OnScreenControlsView: View {
    @Environment(EmulatorSession.self) private var session

    @State private var joystickDirection: JoystickDirection = .center
    @State private var isFiring: Bool = false
    @State private var showConsoleKeys: Bool = false

    var body: some View {
        HStack(spacing: 40) {
            // D-pad (left side)
            dpadView

            Spacer()

            // Console keys (center)
            if showConsoleKeys {
                consoleKeysView
            }

            Spacer()

            // Fire button (right side)
            fireButton
        }
        .padding(.horizontal, 40)
        .overlay(alignment: .topTrailing) {
            // Toggle console keys visibility
            Button(action: { showConsoleKeys.toggle() }) {
                Image(systemName: "keyboard")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    // MARK: - D-Pad

    private var dpadView: some View {
        VStack(spacing: 4) {
            // Up
            dpadButton(direction: .up, systemImage: "chevron.up")

            HStack(spacing: 4) {
                // Left
                dpadButton(direction: .left, systemImage: "chevron.left")
                // Center (neutral)
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                // Right
                dpadButton(direction: .right, systemImage: "chevron.right")
            }

            // Down
            dpadButton(direction: .down, systemImage: "chevron.down")
        }
    }

    private func dpadButton(direction: JoystickDirection, systemImage: String) -> some View {
        Button {
            // Tap toggles direction
            if joystickDirection == direction {
                joystickDirection = .center
            } else {
                joystickDirection = direction
            }
            updateJoystick()
        } label: {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .tint(joystickDirection == direction ? .blue : .secondary)
    }

    // MARK: - Fire Button

    private var fireButton: some View {
        Button {
            isFiring.toggle()
            updateJoystick()
        } label: {
            Circle()
                .fill(isFiring ? .red : .red.opacity(0.4))
                .frame(width: 70, height: 70)
                .overlay {
                    Text("FIRE")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Console Keys

    private var consoleKeysView: some View {
        HStack(spacing: 12) {
            consoleButton(label: "START", action: {
                Atari800Core_KeyDown(0x23)  // AKEY_START
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    Atari800Core_KeyUp()
                }
            })
            consoleButton(label: "SELECT", action: {
                Atari800Core_KeyDown(0x63)  // AKEY_SELECT
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    Atari800Core_KeyUp()
                }
            })
            consoleButton(label: "OPTION", action: {
                Atari800Core_KeyDown(0x22)  // AKEY_OPTION
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    Atari800Core_KeyUp()
                }
            })
            consoleButton(label: "RESET", action: {
                session.warmReset()
            })
        }
    }

    private func consoleButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Joystick Update

    private func updateJoystick() {
        let coreDirection: Atari800Core_JoyDirection = switch joystickDirection {
        case .center:    Atari800Core_JoyCenter
        case .up:        Atari800Core_JoyUp
        case .down:      Atari800Core_JoyDown
        case .left:      Atari800Core_JoyLeft
        case .right:     Atari800Core_JoyRight
        case .upLeft:    Atari800Core_JoyUpLeft
        case .upRight:   Atari800Core_JoyUpRight
        case .downLeft:  Atari800Core_JoyDownLeft
        case .downRight: Atari800Core_JoyDownRight
        }

        Atari800Core_JoystickUpdate(0, coreDirection, isFiring ? 1 : 0)
    }
}

// MARK: - Direction Enum

private enum JoystickDirection {
    case center, up, down, left, right
    case upLeft, upRight, downLeft, downRight
}
