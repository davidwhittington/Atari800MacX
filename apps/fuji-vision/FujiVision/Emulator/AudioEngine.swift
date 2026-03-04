/* AudioEngine.swift — AVAudioEngine-based audio output for Fuji-Vision
 *
 * Uses AVAudioSourceNode in pull mode: the audio render callback pulls
 * samples from the C-side ring buffer (Vision_Sound_Read) on each
 * audio cycle. This matches the SDL SoundCallback pattern used by
 * fuji-foundation.
 *
 * Audio format: 44100 Hz, 16-bit signed integer, stereo (interleaved)
 * matching POKEYSND output with STEREO_SOUND enabled.
 */

import AVFoundation

final class AudioEngine {

    // MARK: - Configuration

    private let sampleRate: Double = 44100
    private let channelCount: AVAudioChannelCount = 2  // stereo
    private let bytesPerSample: Int = 2  // 16-bit

    // MARK: - Audio Graph

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    // MARK: - Lifecycle

    func start() {
        let engine = AVAudioEngine()
        self.engine = engine

        // Audio format: 44100 Hz, 16-bit signed integer, stereo
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: true
        ) else {
            print("AudioEngine: Failed to create audio format")
            return
        }

        // Create source node with render callback
        let bytesPerFrame = Int(channelCount) * bytesPerSample

        let sourceNode = AVAudioSourceNode(format: format) {
            [bytesPerFrame] (_, _, frameCount, audioBufferList) -> OSStatus in

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first,
                  let data = buffer.mData else {
                return noErr
            }

            let requestedBytes = Int(frameCount) * bytesPerFrame

            // Pull from the C ring buffer
            let bytesRead = Vision_Sound_Read(
                data.assumingMemoryBound(to: UInt8.self),
                Int32(requestedBytes)
            )

            // If we got less than requested, zero-fill the remainder (silence)
            if bytesRead < requestedBytes {
                let remaining = data.advanced(by: Int(bytesRead))
                memset(remaining, 0, requestedBytes - Int(bytesRead))
            }

            // Update callback tick for PLATFORM_AdjustSpeed
            let tick = UInt32(CFAbsoluteTimeGetCurrent() * 1000.0)
            Vision_Sound_SetCallbackTick(tick)

            return noErr
        }
        self.sourceNode = sourceNode

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("AudioEngine: Failed to start: \(error)")
        }
    }

    func stop() {
        engine?.stop()
        if let sourceNode = sourceNode {
            engine?.detach(sourceNode)
        }
        sourceNode = nil
        engine = nil
    }

    /// Pause audio output (e.g., when app moves to background)
    func pause() {
        engine?.pause()
    }

    /// Resume audio output
    func resume() {
        guard let engine = engine else { return }
        do {
            try engine.start()
        } catch {
            print("AudioEngine: Failed to resume: \(error)")
        }
    }

    /// Set the main mixer volume (0.0 - 1.0)
    func setVolume(_ volume: Float) {
        engine?.mainMixerNode.outputVolume = volume
    }
}
