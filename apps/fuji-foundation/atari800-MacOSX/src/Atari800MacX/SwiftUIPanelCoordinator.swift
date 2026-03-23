// SwiftUIPanelCoordinator.swift
// Phase 7: NSHostingController bridge between AppKit (ObjC) and SwiftUI panels.
//
// Usage from Objective-C:
//   [[SwiftUIPanelCoordinator shared] showPreferences];
//   [[SwiftUIPanelCoordinator shared] showAboutBox];
//
// The coordinator owns the PreferenceModel singleton and is responsible for
// loading/saving preferences when the window is shown/hidden.

import SwiftUI

@objc
final class SwiftUIPanelCoordinator: NSObject {

    @objc static let shared = SwiftUIPanelCoordinator()

    private let preferencesModel = PreferenceModel()
    private var preferencesWindow: NSWindow?
    private var aboutBoxWindow: NSWindow?

    private override init() { super.init() }

    // MARK: - Preferences

    /// Open (or bring to front) the SwiftUI Preferences window.
    /// Call on the main thread.
    @objc func showPreferences() {
        if preferencesWindow == nil {
            let hostVC = NSHostingController(
                rootView: PreferencesView(model: preferencesModel)
            )
            let window = NSWindow(contentViewController: hostVC)
            window.title = "Preferences"
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.setContentSize(NSSize(width: 680, height: 520))
            window.center()
            preferencesWindow = window
        }
        preferencesModel.load()
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - About Box

    /// Open (or bring to front) the SwiftUI About Box.
    /// Call on the main thread.
    @objc func showAboutBox() {
        if aboutBoxWindow == nil {
            let hostVC = NSHostingController(rootView: AboutBoxView())
            let window = NSWindow(contentViewController: hostVC)
            window.title = "About Atari800MacX"
            window.styleMask = [.titled, .closable]
            aboutBoxWindow = window
        }
        aboutBoxWindow?.makeKeyAndOrderFront(nil)
    }
}
