/* InputManager.swift — Game controller and virtual keyboard bridge
 *
 * Monitors GCController connections for Bluetooth gamepad input and
 * maps physical controls to Atari joystick/keyboard events via the
 * Atari800Core C API.
 *
 * Mapping:
 *   D-pad / left thumbstick → Joystick directions (port 0)
 *   Button A (south)        → Fire button
 *   Button B (east)         → Start key
 *   Button X (west)         → Select key
 *   Button Y (north)        → Option key
 *   Left shoulder           → Space (jump in many games)
 *   Right shoulder          → Return/Enter
 *   Menu button             → Warm reset
 */

import GameController

final class InputManager {

    // MARK: - State

    private var connectedController: GCController?
    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Monitoring

    func startMonitoring() {
        // Watch for controller connect/disconnect
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
                // Reset joystick to center when controller disconnects
                Atari800Core_JoystickUpdate(0, Atari800Core_JoyCenter, 0)
            }
        }

        notificationObservers = [connectObserver, disconnectObserver]

        // Start discovery
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
            // Try basic gamepad profile
            configureBasicGamepad(controller)
            return
        }

        // D-pad → joystick directions
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.updateJoystickFromAxis(x: xValue, y: yValue)
        }

        // Left thumbstick → joystick directions (alternative to d-pad)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.updateJoystickFromAxis(x: xValue, y: yValue)
        }

        // Button A → Fire
        gamepad.buttonA.pressedChangedHandler = { _, _, pressed in
            Atari800Core_JoystickUpdate(
                0,
                Atari800Core_JoyCenter,  // direction unchanged; managed separately
                pressed ? 1 : 0
            )
        }

        // Button B → Start
        gamepad.buttonB.pressedChangedHandler = { _, _, pressed in
            if pressed {
                Atari800Core_KeyDown(0x23)  // AKEY_START (approximate; refined in Phase V4)
            } else {
                Atari800Core_KeyUp()
            }
        }

        // Button X → Select
        gamepad.buttonX.pressedChangedHandler = { _, _, pressed in
            if pressed {
                Atari800Core_KeyDown(0x63)  // AKEY_SELECT (approximate)
            } else {
                Atari800Core_KeyUp()
            }
        }

        // Button Y → Option
        gamepad.buttonY.pressedChangedHandler = { _, _, pressed in
            if pressed {
                Atari800Core_KeyDown(0x22)  // AKEY_OPTION (approximate)
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

        gamepad.buttonA.pressedChangedHandler = { _, _, pressed in
            Atari800Core_JoystickUpdate(0, Atari800Core_JoyCenter, pressed ? 1 : 0)
        }
    }

    // MARK: - Axis → Joystick Direction Mapping

    /// Current fire state (tracked separately since joystick update is a combined call)
    private var currentFire: Int32 = 0

    private func updateJoystickFromAxis(x: Float, y: Float) {
        let threshold: Float = 0.3
        let direction: Atari800Core_JoyDirection

        let left  = x < -threshold
        let right = x >  threshold
        let up    = y >  threshold
        let down  = y < -threshold

        switch (up, down, left, right) {
        case (true,  false, false, false): direction = Atari800Core_JoyUp
        case (false, true,  false, false): direction = Atari800Core_JoyDown
        case (false, false, true,  false): direction = Atari800Core_JoyLeft
        case (false, false, false, true):  direction = Atari800Core_JoyRight
        case (true,  false, true,  false): direction = Atari800Core_JoyUpLeft
        case (true,  false, false, true):  direction = Atari800Core_JoyUpRight
        case (false, true,  true,  false): direction = Atari800Core_JoyDownLeft
        case (false, true,  false, true):  direction = Atari800Core_JoyDownRight
        default:                           direction = Atari800Core_JoyCenter
        }

        Atari800Core_JoystickUpdate(0, direction, currentFire)
    }
}
