/* VisibilityCompositor.swift — Transparency and chroma key processor
 *
 * Data processor that manages visibility modes (Solid/Dim/Ghost/Peek),
 * chroma key transparency, background auto-detection, and edge enhancement.
 * Produces an expanded FragParams struct for the Metal fragment shader.
 *
 * This class does NOT own Metal objects or pipeline state — it is a pure
 * data processor owned by EmulatorRenderer.
 */

import Foundation
import simd

// MARK: - Visibility Mode

enum VisibilityMode: Int, CaseIterable {
    case solid = 0   // alpha 1.0
    case dim   = 1   // alpha 0.6
    case ghost = 2   // alpha 0.2
    case peek  = 3   // alpha 0.15 while held (runtime gesture, not a setting)

    var targetAlpha: Float {
        switch self {
        case .solid: return 1.0
        case .dim:   return 0.6
        case .ghost: return 0.2
        case .peek:  return 0.15
        }
    }

    var displayName: String {
        switch self {
        case .solid: return "Solid"
        case .dim:   return "Dim"
        case .ghost: return "Ghost"
        case .peek:  return "Peek"
        }
    }
}

// MARK: - VisibilityCompositor

final class VisibilityCompositor {

    // MARK: - Mode

    var mode: VisibilityMode = .solid {
        didSet { targetAlpha = mode.targetAlpha }
    }

    /// Stored mode before peek, so we can return to it
    private var previousMode: VisibilityMode = .solid

    // MARK: - Key Transparency

    var keyEnabled: Bool = false
    var keyColor: SIMD3<Float> = .zero
    var keyThreshold: Float = 0.1
    var keySoftEdge: Float = 0.05
    var keyInvert: Bool = false

    // MARK: - Background Detection

    var autoDetectEnabled: Bool = false
    var autoDetectSensitivity: Float = 0.5
    var detectedColorLocked: Bool = false

    // MARK: - Edge Enhancement

    var edgeEnhanceEnabled: Bool = false

    // MARK: - Peek State

    var peekActive: Bool = false

    // MARK: - Animation (Private)

    private var currentAlpha: Float = 1.0
    private var targetAlpha: Float = 1.0
    private static let lerpDuration: Float = 0.3  // seconds

    // MARK: - Background Detection (Private)

    private var frameCounter: Int = 0
    private static let detectInterval: Int = 30  // frames between scans
    private var candidateColor: SIMD3<Float> = .zero
    private var candidateCount: Int = 0
    private static let hysteresisThreshold: Int = 3  // consecutive matches before adopting

    // MARK: - Update

    /// Advance the alpha lerp toward the target. Call once per frame.
    func update(deltaTime: Float) {
        guard currentAlpha != targetAlpha else { return }

        let speed = 1.0 / Self.lerpDuration
        let step = speed * deltaTime

        if currentAlpha < targetAlpha {
            currentAlpha = min(currentAlpha + step, targetAlpha)
        } else {
            currentAlpha = max(currentAlpha - step, targetAlpha)
        }
    }

    // MARK: - Background Detection

    /// Analyze border pixels to find the dominant background color.
    /// Called after texture upload when pixel data is still accessible.
    func analyzeFrame(pixels: UnsafePointer<UInt8>, width: Int, height: Int) {
        guard autoDetectEnabled, !detectedColorLocked else { return }

        frameCounter += 1
        guard frameCounter >= Self.detectInterval else { return }
        frameCounter = 0

        // Sample border pixels: top row, bottom row, left column, right column
        // Build a 4-bit-per-channel quantized histogram
        var histogram: [UInt16: Int] = [:]

        let stride = width * 4  // RGBA bytes per row

        // Helper: quantize and record a pixel
        func recordPixel(offset: Int) {
            let r = pixels[offset]
            let g = pixels[offset + 1]
            let b = pixels[offset + 2]
            // Quantize to 4-bit (16 levels per channel)
            let qr = UInt16(r >> 4)
            let qg = UInt16(g >> 4)
            let qb = UInt16(b >> 4)
            let key = (qr << 8) | (qg << 4) | qb
            histogram[key, default: 0] += 1
        }

        // Top row
        for x in Swift.stride(from: 0, to: width, by: 4) {
            recordPixel(offset: x * 4)
        }
        // Bottom row
        let bottomRowStart = (height - 1) * stride
        for x in Swift.stride(from: 0, to: width, by: 4) {
            recordPixel(offset: bottomRowStart + x * 4)
        }
        // Left column
        for y in Swift.stride(from: 0, to: height, by: 4) {
            recordPixel(offset: y * stride)
        }
        // Right column
        let rightColOffset = (width - 1) * 4
        for y in Swift.stride(from: 0, to: height, by: 4) {
            recordPixel(offset: y * stride + rightColOffset)
        }

        // Find dominant color
        guard let (dominantKey, _) = histogram.max(by: { $0.value < $1.value }) else { return }

        // Convert quantized key back to normalized color (center of bucket)
        let dr = (Float((dominantKey >> 8) & 0xF) + 0.5) / 16.0
        let dg = (Float((dominantKey >> 4) & 0xF) + 0.5) / 16.0
        let db = (Float(dominantKey & 0xF) + 0.5) / 16.0
        let detected = SIMD3<Float>(dr, dg, db)

        // Hysteresis: require consecutive matches before adopting
        let sensitivityThreshold = 0.1 * (1.0 - autoDetectSensitivity) + 0.02
        if simd_distance(detected, candidateColor) < sensitivityThreshold {
            candidateCount += 1
        } else {
            candidateColor = detected
            candidateCount = 1
        }

        if candidateCount >= Self.hysteresisThreshold {
            keyColor = candidateColor
            if !keyEnabled {
                keyEnabled = true
            }
        }
    }

    // MARK: - Peek

    func setPeekActive(_ active: Bool) {
        if active {
            previousMode = mode
            mode = .peek
            peekActive = true
        } else {
            mode = previousMode
            peekActive = false
        }
    }

    // MARK: - FragParams Builder

    /// Build the expanded FragParams struct for the current frame.
    func currentFragParams(scanlines: Bool, scanlineTransparency: Float) -> EmulatorRenderer.FragParams {
        EmulatorRenderer.FragParams(
            scanlines: scanlines ? 1 : 0,
            scanlineTransparency: scanlineTransparency,
            globalAlpha: currentAlpha,
            keyEnabled: keyEnabled ? 1 : 0,
            keyR: keyColor.x,
            keyG: keyColor.y,
            keyB: keyColor.z,
            keyThreshold: keyThreshold,
            keySoftEdge: keySoftEdge,
            keyInvert: keyInvert ? 1 : 0,
            edgeEnhance: edgeEnhanceEnabled ? 1.0 : 0.0
        )
    }
}
