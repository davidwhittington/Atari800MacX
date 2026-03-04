/* FujiVisionApp.swift — SwiftUI entry point for Fuji-Vision (visionOS)
 *
 * This is the @main entry point. It creates a WindowGroup containing
 * the emulator view and manages the EmulatorSession lifecycle.
 */

import SwiftUI

@main
struct FujiVisionApp: App {
    @State private var session = EmulatorSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
        .defaultSize(width: 800, height: 600)
    }
}
