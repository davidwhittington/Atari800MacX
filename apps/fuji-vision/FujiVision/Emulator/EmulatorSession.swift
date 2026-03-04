/* EmulatorSession.swift — Owns the emulation lifecycle and frame texture
 *
 * This is the central @Observable model that:
 *   - Starts/stops the C emulation thread via Vision_Emulation_Start/Stop
 *   - Receives frame callbacks from the C layer
 *   - Publishes the current MTLTexture for EmulatorView to display
 *   - Bridges media operations to Atari800Core_* C functions
 *
 * THREADING:
 *   - The C emulation thread calls the frame callback (~60 Hz)
 *   - Frame data is handed to EmulatorRenderer for GPU upload
 *   - All UI-facing properties are updated on @MainActor
 */

import Foundation
import Metal
import Observation

@Observable
@MainActor
final class EmulatorSession {

    // MARK: - Global Singleton (for C callback trampoline)

    /// Weak global reference used by the C frame callback trampoline.
    /// C function pointers cannot capture Swift context, so we route through this.
    nonisolated(unsafe) static weak var shared: EmulatorSession?

    /// C-compatible frame callback that routes to the shared session.
    nonisolated static let frameCallbackTrampoline: VisionFrameReadyCallback = {
        pixels, width, height in
        guard let pixels = pixels else { return }
        let byteCount = Int(width) * Int(height) * 4
        let copy = UnsafeMutablePointer<UInt8>.allocate(capacity: byteCount)
        copy.initialize(from: pixels, count: byteCount)
        let w = Int(width)
        let h = Int(height)
        DispatchQueue.main.async {
            guard let session = EmulatorSession.shared else {
                copy.deallocate()
                return
            }
            session.renderer?.uploadFrame(pixels: UnsafePointer(copy), width: w, height: h)
            session.currentTexture = session.renderer?.frameTexture
            session.diskLEDStatus = Int(Atari800Core_GetDiskLEDStatus())
            copy.deallocate()
        }
    }

    // MARK: - Published State

    /// Current frame texture, updated ~60fps by the renderer
    private(set) var currentTexture: MTLTexture?

    /// Whether emulation is paused
    private(set) var isPaused: Bool = false

    /// Current machine model name for display
    private(set) var machineModelName: String = "Atari XL/XE"

    /// Disk LED status (0 = off)
    private(set) var diskLEDStatus: Int = 0

    // MARK: - Internal Components

    private(set) var renderer: EmulatorRenderer?
    private var audioEngine: AudioEngine?
    private var inputManager: InputManager?
    private var isRunning: Bool = false

    // MARK: - Lifecycle

    init() {
        // Renderer and audio are initialized on start()
    }

    func start() {
        guard !isRunning else { return }

        // Initialize Metal renderer
        renderer = EmulatorRenderer()

        // Initialize audio engine
        audioEngine = AudioEngine()
        audioEngine?.start()

        // Initialize input
        inputManager = InputManager()
        inputManager?.startMonitoring()

        // Register the frame callback before starting the emulation thread.
        // C function pointers can't capture Swift context, so we use a global.
        EmulatorSession.shared = self
        Vision_Platform_SetFrameCallback(EmulatorSession.frameCallbackTrampoline)

        // Start emulation thread
        Vision_Emulation_Start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }

        Vision_Emulation_Stop()
        audioEngine?.stop()
        inputManager?.stopMonitoring()
        Vision_Platform_SetFrameCallback(nil)
        isRunning = false
    }

    // MARK: - Emulator Controls

    func togglePause() {
        isPaused.toggle()
        Vision_Emulation_SetPaused(isPaused ? 1 : 0)
    }

    func warmReset() {
        Atari800Core_WarmReset()
    }

    func coldReset() {
        Atari800Core_ColdReset()
    }

    func setMachineModel(_ model: MachineModel) {
        Atari800Core_SetMachineModel(model.coreValue)
        machineModelName = model.displayName
    }

    // MARK: - Media Management

    func importMedia(url: URL, target: MediaImportTarget) {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        // Copy to app sandbox for persistent access
        let sandboxURL = copyToSandbox(url: url)
        let path = sandboxURL.path

        switch target {
        case .disk1:
            Atari800Core_MountDisk(1, path)
        case .disk2:
            Atari800Core_MountDisk(2, path)
        case .cartridge:
            Atari800Core_InsertCartridge(path)
        case .executable:
            Atari800Core_LoadExecutable(path)
        case .cassette:
            Atari800Core_MountCassette(path)
        }
    }

    private func copyToSandbox(url: URL) -> URL {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let mediaDir = docsDir.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let destURL = mediaDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: destURL)  // overwrite if exists
        try? FileManager.default.copyItem(at: url, to: destURL)
        return destURL
    }
}

// MARK: - Machine Model Mapping

enum MachineModel {
    case model800, modelXLXE, model5200

    var coreValue: Atari800Core_MachineModel {
        switch self {
        case .model800:  return Atari800Core_Model800
        case .modelXLXE: return Atari800Core_ModelXLXE
        case .model5200: return Atari800Core_Model5200
        }
    }

    var displayName: String {
        switch self {
        case .model800:  return "Atari 800"
        case .modelXLXE: return "Atari XL/XE"
        case .model5200: return "Atari 5200"
        }
    }
}

// C global access is now through Vision_Emulation_SetPaused() / Vision_Emulation_IsPaused()
// defined in platform_bridge.h and implemented in atari_vision.c
