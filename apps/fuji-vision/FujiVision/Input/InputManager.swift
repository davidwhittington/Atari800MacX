/* InputManager.swift — Game controller and virtual keyboard bridge
 *
 * Monitors GCController connections for Bluetooth gamepad input and
 * maps physical controls to Atari joystick/keyboard events via the
 * Atari800Core C API.
 *
 * Console keys (Start/Select/Option) use INPUT_key_consol bit-clearing,
 * not AKEY constants, because that's how the Atari hardware works.
 *
 * Mapping:
 *   D-pad / left thumbstick → Joystick directions (port 0)
 *   Button A (south)        → Fire button
 *   Button B (east)         → Start key
 *   Button X (west)         → Select key
 *   Button Y (north)        → Option key
 *   Left shoulder           → Space
 *   Right shoulder          → Return/Enter
 *   Menu button             → Warm reset
 */

import GameController

final class InputManager {

    // MARK: - Console key bit masks (match INPUT_CONSOL_* in input.h)

    /// INPUT_CONSOL_START = 0x01
    private static let consolStart:  Int32 = 0x01
    /// INPUT_CONSOL_SELECT = 0x02
    private static let consolSelect: Int32 = 0x02
    /// INPUT_CONSOL_OPTION = 0x04
    private static let consolOption: Int32 = 0x04

    // MARK: - State

    private var connectedController: GCController?
    private var notificationObservers: [NSObjectProtocol] = []

    /// Current fire button state (tracked separately since joystick update is combined)
    private var currentFire: Int32 = 0

    /// Current joystick direction
    private var currentDirection: Atari800Core_JoyDirection = Atari800Core_JoyCenter

    // MARK: - Monitoring

    func startMonitoring() {
        let connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.configureController(controller)
        }

        let disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            if self?.connectedController === controller {
                self?.connectedController = nil
                self?.currentDirection = Atari800Core_JoyCenter
                self?.currentFire = 0
                Atari800Core_JoystickUpdate(0, Atari800Core_JoyCenter, 0)
            }
        }

        notificationObservers = [connectObserver, disconnectObserver]

        GCController.startWirelessControllerDiscovery {}

        // Check for already-connected controllers
        if let controller = GCController.controllers().first {
            configureController(controller)
        }
    }

    func stopMonitoring() {
        GCController.stopWirelessControllerDiscovery()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        connectedController = nil
    }

    // MARK: - Controller Configuration

    private func configureController(_ controller: GCController) {
        connectedController = controller

        guard let gamepad = controller.extendedGamepad else {
            configureBasicGamepad(controller)
            return
        }

        // D-pad → joystick directions
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.updateJoystickFromAxis(x: xValue, y: yValue)
        }

        // Left thumbstick → joystick directions (alternative)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.updateJoystickFromAxis(x: xValue, y: yValue)
        }

        // Button A → Fire
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self else { return }
            self.currentFire = pressed ? 1 : 0
            Atari800Core_JoystickUpdate(0, self.currentDirection, self.currentFire)
        }

        // Button B → Start (console key, bit-clear mechanism)
        gamepad.buttonB.pressedChangedHandler = { _, _, pressed in
            if pressed {
                Vision_Input_ConsoleKeyDown(InputManager.consolStart)
            } else {
                Vision_Input_ConsoleKeyUp(InputManager.consolStart)
            }
        }

        // Button X → Select
        gamepad.buttonX.pressedChangedHandler = { _, _, pressed in
            if pressed {
                Vision_Input_ConsoleKeyDown(InputManager.consolSelect)
            } else {
                Vision_Input_ConsoleKeyUp(InputManager.consolSelect)
            }
        }

        // Button Y → Option
        gamepad.buttonY.pressedChangedHandler = { _, _, pressed in
            if pressed {
                Vision_Input_ConsoleKeyDown(InputManager.consolOption)
            } else {
                Vision_Input_ConsoleKeyUp(InputManager.consolOption)
            }
        }

        // Left shoulder → Space
        gamepad.leftShoulder.pressedChangedHandler = { _, _, pressed in
            if pressed {
                Atari800Core_KeyDown(AKEY_SPACE)
            } else {
                Atari800Core_KeyUp()
            }
        }

        // Right shoulder → Return
        gamepad.rightShoulder.pressedChangedHandler = { _, _, pressed in
            if pressed {
                Atari800Core_KeyDown(AKEY_RETURN)
            } else {
                Atari800Core_KeyUp()
            }
        }

        // Menu button → Warm reset
        gamepad.buttonMenu.pressedChangedHandler = { _, _, pressed in
            if pressed {
                Atari800Core_WarmReset()
            }
        }
    }

    private func configureBasicGamepad(_ controller: GCController) {
        guard let gamepad = controller.microGamepad else { return }

        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.updateJoystickFromAxis(x: xValue, y: yValue)
        }

        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard let self else { return }
            self.currentFire = pressed ? 1 : 0
            Atari800Core_JoystickUpdate(0, self.currentDirection, self.currentFire)
        }
    }

    // MARK: - Axis → Joystick Direction Mapping

    private func updateJoystickFromAxis(x: Float, y: Float) {
        let threshold: Float = 0.3

        let left  = x < -threshold
        let right = x >  threshold
        let up    = y >  threshold
        let down  = y < -threshold

        let direction: Atari800Core_JoyDirection = switch (up, down, left, right) {
        case (true,  false, false, false): Atari800Core_JoyUp
        case (false, true,  false, false): Atari800Core_JoyDown
        case (false, false, true,  false): Atari800Core_JoyLeft
        case (false, false, false, true):  Atari800Core_JoyRight
        case (true,  false, true,  false): Atari800Core_JoyUpLeft
        case (true,  false, false, true):  Atari800Core_JoyUpRight
        case (false, true,  true,  false): Atari800Core_JoyDownLeft
        case (false, true,  false, true):  Atari800Core_JoyDownRight
        default:                           Atari800Core_JoyCenter
        }

        currentDirection = direction
        Atari800Core_JoystickUpdate(0, direction, currentFire)
    }
}
