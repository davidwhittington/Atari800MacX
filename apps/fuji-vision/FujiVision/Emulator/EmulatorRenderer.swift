/* EmulatorRenderer.swift — Metal pipeline for visionOS Atari display
 *
 * Manages the Metal device, pipeline, and texture upload. The emulation
 * core produces ARGB8888 pixels (384x240); this renderer uploads them
 * to an MTLTexture that EmulatorView's MTKView draws as a fullscreen quad.
 *
 * The shader pair (emulatorVertex / emulatorFragment) is shared with
 * fuji-foundation — same Shaders.metal file.
 */

import Foundation
import Metal
import MetalKit
import simd

final class EmulatorRenderer {

    // MARK: - Public State

    /// The current frame texture, ready for display
    private(set) var frameTexture: MTLTexture?

    // MARK: - Metal Objects

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let samplerNearest: MTLSamplerState
    let samplerLinear: MTLSamplerState

    /// Whether to use linear (bilinear) texture filtering
    var linearFilterEnabled: Bool = false

    /// Whether CRT scanline effect is enabled
    var scanlinesEnabled: Bool = false

    /// Scanline transparency (0.0 = fully dark, 1.0 = fully bright)
    var scanlineTransparency: Float = 0.9

    // MARK: - Frame Texture State

    private var textureWidth: Int = 0
    private var textureHeight: Int = 0

    // MARK: - FragParams (matches Shaders.metal)

    struct FragParams {
        var scanlines: Int32
        var scanlineTransparency: Float
    }

    // MARK: - Initialization

    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("EmulatorRenderer: No Metal device available")
            return nil
        }
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            print("EmulatorRenderer: Failed to create command queue")
            return nil
        }
        self.commandQueue = queue

        // Load shader library
        guard let library = try? device.makeDefaultLibrary(bundle: .main) else {
            print("EmulatorRenderer: Failed to load shader library")
            return nil
        }

        guard let vertexFunc = library.makeFunction(name: "emulatorVertex"),
              let fragmentFunc = library.makeFunction(name: "emulatorFragment") else {
            print("EmulatorRenderer: Shader functions not found")
            return nil
        }

        // Create render pipeline
        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexFunc
        pipelineDesc.fragmentFunction = fragmentFunc
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDesc)
        } catch {
            print("EmulatorRenderer: Pipeline creation failed: \(error)")
            return nil
        }

        // Create samplers
        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .nearest
        samplerDesc.magFilter = .nearest
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge

        guard let nearest = device.makeSamplerState(descriptor: samplerDesc) else {
            print("EmulatorRenderer: Failed to create nearest sampler")
            return nil
        }
        self.samplerNearest = nearest

        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        guard let linear = device.makeSamplerState(descriptor: samplerDesc) else {
            print("EmulatorRenderer: Failed to create linear sampler")
            return nil
        }
        self.samplerLinear = linear
    }

    // MARK: - Frame Upload

    /// Upload ARGB8888 pixel data to the frame texture.
    /// Called from the main thread after receiving data from the emulation thread.
    func uploadFrame(pixels: UnsafePointer<UInt8>, width: Int, height: Int) {
        // Recreate texture only if dimensions changed
        if frameTexture == nil || textureWidth != width || textureHeight != height {
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            desc.usage = .shaderRead
            desc.storageMode = .shared

            guard let texture = device.makeTexture(descriptor: desc) else {
                print("EmulatorRenderer: Texture allocation failed (\(width)x\(height))")
                return
            }
            frameTexture = texture
            textureWidth = width
            textureHeight = height
        }

        // Upload pixels
        let bytesPerRow = width * 4
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: width, height: height, depth: 1)
        )
        frameTexture?.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: bytesPerRow
        )
    }

    // MARK: - Rendering

    /// Draw the current frame texture into the given MTKView.
    /// Called by EmulatorView's MTKViewDelegate.
    func draw(in view: MTKView) {
        guard let texture = frameTexture,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDesc = view.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc)
        else { return }

        encoder.setRenderPipelineState(pipelineState)

        // Vertex buffer 0: fullscreen quad in NDC
        var quad = SIMD4<Float>(-1.0, -1.0, 1.0, 1.0)  // L, B, R, T
        encoder.setVertexBytes(&quad, length: MemoryLayout<SIMD4<Float>>.size, index: 0)

        // Fragment texture 0: Atari frame
        encoder.setFragmentTexture(texture, index: 0)

        // Fragment sampler 0: nearest or linear
        let sampler = linearFilterEnabled ? samplerLinear : samplerNearest
        encoder.setFragmentSamplerState(sampler, index: 0)

        // Fragment buffer 0: scanline params
        var params = FragParams(
            scanlines: scanlinesEnabled ? 1 : 0,
            scanlineTransparency: scanlineTransparency
        )
        encoder.setFragmentBytes(&params, length: MemoryLayout<FragParams>.size, index: 0)

        // Draw fullscreen quad as triangle strip
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        encoder.endEncoding()
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
    }
}
