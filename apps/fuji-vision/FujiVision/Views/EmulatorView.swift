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

        // Transparent background for visionOS pass-through visibility modes
        mtkView.isOpaque = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.framebufferOnly = false
        mtkView.layer.isOpaque = false

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

// renderer is now exposed as private(set) on EmulatorSession directly
