/* EmulatorView.swift — MTKView wrapper for visionOS
 *
 * On visionOS, UIViewRepresentable wraps a UIKit view (MTKView) for use
 * in SwiftUI. The MTKView is configured in paused mode — drawing is
 * triggered by the EmulatorSession when a new frame arrives.
 *
 * NOTE: visionOS uses UIKit (not AppKit), so this is UIViewRepresentable,
 * not NSViewRepresentable as in the macOS fuji-foundation.
 */

import SwiftUI
import MetalKit

struct EmulatorView: UIViewRepresentable {
    @Environment(EmulatorSession.self) private var session

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()

        guard let renderer = session.renderer else {
            return mtkView
        }

        mtkView.device = renderer.device
        mtkView.delegate = context.coordinator
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.framebufferOnly = true

        // Emulator drives rendering, not the display link
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60

        // Store renderer reference in coordinator
        context.coordinator.renderer = renderer

        return mtkView
    }

    func updateUIView(_ mtkView: MTKView, context: Context) {
        // Renderer reference may change if session restarts
        context.coordinator.renderer = session.renderer
    }

    // MARK: - MTKViewDelegate Coordinator

    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: EmulatorRenderer?

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // No action needed — the quad fills the drawable
        }

        func draw(in view: MTKView) {
            renderer?.draw(in: view)
        }
    }
}

// Private access to EmulatorSession.renderer for the view
extension EmulatorSession {
    /// Internal accessor for the renderer (used by EmulatorView)
    var renderer: EmulatorRenderer? {
        // Access the private renderer through a computed property
        // This is a workaround; in production, expose via a proper internal API
        return _renderer
    }

    /// Internal storage accessor — set during init
    fileprivate var _renderer: EmulatorRenderer? {
        // This will be properly wired when the renderer is initialized
        // For now, returns nil until start() is called
        return nil  // TODO: Phase V2 — wire to actual renderer instance
    }
}
