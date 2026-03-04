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

    // Console key bit masks (match INPUT_CONSOL_* in input.h)
    private static let consolStart:  Int32 = 0x01
    private static let consolSelect: Int32 = 0x02
    private static let consolOption: Int32 = 0x04

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
            dpadButton(direction: .up, systemImage: "chevron.up")

            HStack(spacing: 4) {
                dpadButton(direction: .left, systemImage: "chevron.left")
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                dpadButton(direction: .right, systemImage: "chevron.right")
            }

            dpadButton(direction: .down, systemImage: "chevron.down")
        }
    }

    private func dpadButton(direction: JoystickDirection, systemImage: String) -> some View {
        Button {
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
            consoleButton(label: "START", key: Self.consolStart)
            consoleButton(label: "SELECT", key: Self.consolSelect)
            consoleButton(label: "OPTION", key: Self.consolOption)
            consoleButton(label: "RESET", action: {
                session.warmReset()
            })
        }
    }

    /// Console key button — uses INPUT_key_consol bit-clearing
    private func consoleButton(label: String, key: Int32) -> some View {
        Button {
            // Press: clear bit, hold briefly, then release: set bit
            Vision_Input_ConsoleKeyDown(key)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Vision_Input_ConsoleKeyUp(key)
            }
        } label: {
            Text(label)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }

    /// Reset button (no console key, just warm reset)
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
