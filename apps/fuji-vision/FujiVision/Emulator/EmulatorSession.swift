/* EmulatorSession.swift — Owns the emulation lifecycle and frame texture
 *
 * This is the central @Observable model that:
 *   - Starts/stops the C emulation thread via Vision_Emulation_Start/Stop
 *   - Receives frame callbacks from the C layer
 *   - Publishes the current MTLTexture for EmulatorView to display
 *   - Bridges media operations to Atari800Core_* C functions
 *   - Tracks mounted media and persists across launches
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

    /// Disk LED status (0 = off, 1-9 = read, 10-18 = write)
    private(set) var diskLEDStatus: Int = 0

    /// Currently mounted media — maps target to display name
    private(set) var mountedMedia: [MediaImportTarget: String] = [:]

    // MARK: - Internal Components

    private(set) var renderer: EmulatorRenderer?
    private var audioEngine: AudioEngine?
    private var inputManager: InputManager?
    private var isRunning: Bool = false

    // MARK: - Persistence Keys

    private enum PrefKeys {
        static let disk1Path = "FV_Disk1Path"
        static let disk2Path = "FV_Disk2Path"
        static let cartridgePath = "FV_CartridgePath"
        static let cassettePath = "FV_CassettePath"
    }

    // MARK: - Lifecycle

    init() {}

    func start() {
        guard !isRunning else { return }

        renderer = EmulatorRenderer()
        audioEngine = AudioEngine()
        audioEngine?.start()
        inputManager = InputManager()
        inputManager?.startMonitoring()

        EmulatorSession.shared = self
        Vision_Platform_SetFrameCallback(EmulatorSession.frameCallbackTrampoline)

        // Apply stored visibility settings before emulation starts
        applyStoredVisibilitySettings()

        Vision_Emulation_Start()
        isRunning = true

        // Restore previously mounted media
        restoreMedia()
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
        if isPaused {
            audioEngine?.pause()
        } else {
            audioEngine?.resume()
        }
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

    func setAudioVolume(_ volume: Float) {
        audioEngine?.setVolume(volume)
    }

    // MARK: - Save States

    func saveState(slot: Int) {
        let url = SaveStateView.stateURL(slot: slot)
        Atari800Core_SaveState(url.path)
    }

    func loadState(slot: Int) {
        let url = SaveStateView.stateURL(slot: slot)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        Atari800Core_LoadState(url.path)
    }

    func deleteState(slot: Int) {
        let url = SaveStateView.stateURL(slot: slot)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - App Lifecycle

    func handleBackground() {
        guard isRunning, !isPaused else { return }
        Vision_Emulation_SetPaused(1)
        audioEngine?.pause()
    }

    func handleForeground() {
        guard isRunning, !isPaused else { return }
        Vision_Emulation_SetPaused(0)
        audioEngine?.resume()
    }

    // MARK: - Media Management

    func importMedia(url: URL, target: MediaImportTarget) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let sandboxURL = copyToSandbox(url: url)
        let path = sandboxURL.path
        let name = sandboxURL.lastPathComponent

        var success = false
        switch target {
        case .disk1:
            success = Atari800Core_MountDisk(1, path) != 0
        case .disk2:
            success = Atari800Core_MountDisk(2, path) != 0
        case .cartridge:
            success = Atari800Core_InsertCartridge(path) != 0
        case .executable:
            success = Atari800Core_LoadExecutable(path) != 0
        case .cassette:
            success = Atari800Core_MountCassette(path) != 0
        }

        if success {
            mountedMedia[target] = name
            persistMediaPath(path, for: target)
        }
    }

    func ejectMedia(_ target: MediaImportTarget) {
        switch target {
        case .disk1:
            Atari800Core_UnmountDisk(1)
        case .disk2:
            Atari800Core_UnmountDisk(2)
        case .cartridge:
            Atari800Core_RemoveCartridge()
        case .executable:
            break // executables can't be "ejected"
        case .cassette:
            Atari800Core_UnmountCassette()
        }
        mountedMedia.removeValue(forKey: target)
        persistMediaPath(nil, for: target)
    }

    // MARK: - Sandbox File Copy

    private func copyToSandbox(url: URL) -> URL {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let mediaDir = docsDir.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let destURL = mediaDir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: destURL)
        try? FileManager.default.copyItem(at: url, to: destURL)
        return destURL
    }

    // MARK: - Visibility Settings Restore

    private func applyStoredVisibilitySettings() {
        guard let compositor = renderer?.compositor else { return }
        let defaults = UserDefaults.standard

        if let mode = VisibilityMode(rawValue: defaults.integer(forKey: "FV_VisibilityMode")) {
            compositor.mode = mode
        }
        compositor.keyEnabled = defaults.bool(forKey: "FV_KeyEnabled")
        compositor.keyThreshold = Float(defaults.double(forKey: "FV_KeyThreshold"))
        compositor.keySoftEdge = Float(defaults.double(forKey: "FV_KeySoftEdge"))
        compositor.keyInvert = defaults.bool(forKey: "FV_KeyInvert")
        compositor.autoDetectEnabled = defaults.bool(forKey: "FV_AutoDetect")
        compositor.autoDetectSensitivity = Float(defaults.double(forKey: "FV_AutoDetectSensitivity"))
        compositor.detectedColorLocked = defaults.bool(forKey: "FV_DetectedColorLocked")
        compositor.edgeEnhanceEnabled = defaults.bool(forKey: "FV_EdgeEnhance")

        // Apply defaults for unset keys (UserDefaults returns 0.0 for unregistered doubles)
        if compositor.keyThreshold == 0 && !defaults.bool(forKey: "FV_KeyEnabled") {
            compositor.keyThreshold = 0.1
        }
        if compositor.keySoftEdge == 0 && !defaults.bool(forKey: "FV_KeyEnabled") {
            compositor.keySoftEdge = 0.05
        }
        if compositor.autoDetectSensitivity == 0 && !defaults.bool(forKey: "FV_AutoDetect") {
            compositor.autoDetectSensitivity = 0.5
        }
    }

    // MARK: - Persistence

    private func persistMediaPath(_ path: String?, for target: MediaImportTarget) {
        let key: String? = switch target {
        case .disk1:     PrefKeys.disk1Path
        case .disk2:     PrefKeys.disk2Path
        case .cartridge: PrefKeys.cartridgePath
        case .cassette:  PrefKeys.cassettePath
        case .executable: nil
        }
        guard let key else { return }
        UserDefaults.standard.set(path, forKey: key)
    }

    private func restoreMedia() {
        let defaults = UserDefaults.standard
        let restoreTargets: [(MediaImportTarget, String, (String) -> Int32)] = [
            (.disk1, PrefKeys.disk1Path, { Atari800Core_MountDisk(1, $0) }),
            (.disk2, PrefKeys.disk2Path, { Atari800Core_MountDisk(2, $0) }),
            (.cartridge, PrefKeys.cartridgePath, { Atari800Core_InsertCartridge($0) }),
            (.cassette, PrefKeys.cassettePath, { Atari800Core_MountCassette($0) }),
        ]

        for (target, key, mountFn) in restoreTargets {
            guard let path = defaults.string(forKey: key),
                  FileManager.default.fileExists(atPath: path) else { continue }
            if mountFn(path) != 0 {
                let name = URL(fileURLWithPath: path).lastPathComponent
                mountedMedia[target] = name
            }
        }
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
