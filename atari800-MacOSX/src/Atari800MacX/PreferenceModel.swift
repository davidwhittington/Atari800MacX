// PreferenceModel.swift
// Phase 6: Observable preference model for Atari800MacX.
//
// Uses ObservableObject + @Published (available on macOS 13.0+).
// When the deployment target advances to macOS 14+, this can be
// migrated to the @Observable macro from the Observation framework.

import Combine
import Foundation

// MARK: - VideoMode

/// TV system for the Atari emulator.
enum VideoMode: Int {
    case ntsc = 0
    case pal  = 1
}

// MARK: - ScalingMode

/// Display scaling / filter mode.
enum ScalingMode: Int {
    case normal   = 0
    case scanline = 1
}

// MARK: - PreferenceModel

/// Observable model that mirrors NSUserDefaults preference values.
/// Designed as the data source for SwiftUI preference panels (Phase 7).
final class PreferenceModel: ObservableObject {

    // MARK: Video

    @Published var videoMode: VideoMode          = .ntsc
    @Published var scalingMode: ScalingMode      = .normal
    @Published var scanlinesEnabled: Bool        = false
    @Published var brightness: Double            = 1.0
    @Published var fixAspectFullscreen: Bool     = true
    @Published var onlyIntegralScaling: Bool     = false
    @Published var showFPS: Bool                 = false
    @Published var artifactingMode: Int          = 0

    // MARK: Audio

    @Published var audioEnabled: Bool   = true
    @Published var audioVolume: Double  = 1.0
    @Published var stereoEnabled: Bool  = false

    // MARK: Emulation

    /// Raw integer matching Atari800MachineModel enum values (0=800, 1=XLXE, 2=5200).
    @Published var machineModel: Int   = 1    // XLXE default
    @Published var speedLimit: Bool    = true
    @Published var disableBasic: Bool  = true

    // MARK: - Persistence

    /// Read all preference values from UserDefaults.
    func load() {
        let d = UserDefaults.standard
        videoMode           = VideoMode(rawValue: d.integer(forKey: PrefKeyTvMode)) ?? .ntsc
        scalingMode         = ScalingMode(rawValue: d.integer(forKey: PrefKeyScaleMode)) ?? .normal
        scanlinesEnabled    = (scalingMode == .scanline)
        fixAspectFullscreen = d.bool(forKey: PrefKeyFixAspectFullscreen)
        onlyIntegralScaling = d.bool(forKey: PrefKeyOnlyIntegralScaling)
        showFPS             = d.bool(forKey: PrefKeyShowFPS)
        artifactingMode     = d.integer(forKey: PrefKeyArtifactingMode)
        audioEnabled        = d.bool(forKey: PrefKeyEnableSound)
        audioVolume         = d.double(forKey: PrefKeySoundVolume)
        stereoEnabled       = d.bool(forKey: PrefKeyEnableStereo)
        machineModel        = d.integer(forKey: PrefKeyAtariTypeVer5)
        speedLimit          = d.bool(forKey: PrefKeySpeedLimit)
        disableBasic        = d.bool(forKey: PrefKeyDisableBasic)
    }

    /// Persist all preference values to UserDefaults.
    func save() {
        let d = UserDefaults.standard
        d.set(videoMode.rawValue,    forKey: PrefKeyTvMode)
        d.set(scalingMode.rawValue,  forKey: PrefKeyScaleMode)
        d.set(fixAspectFullscreen,   forKey: PrefKeyFixAspectFullscreen)
        d.set(onlyIntegralScaling,   forKey: PrefKeyOnlyIntegralScaling)
        d.set(showFPS,               forKey: PrefKeyShowFPS)
        d.set(artifactingMode,       forKey: PrefKeyArtifactingMode)
        d.set(audioEnabled,          forKey: PrefKeyEnableSound)
        d.set(audioVolume,           forKey: PrefKeySoundVolume)
        d.set(stereoEnabled,         forKey: PrefKeyEnableStereo)
        d.set(machineModel,          forKey: PrefKeyAtariTypeVer5)
        d.set(speedLimit,            forKey: PrefKeySpeedLimit)
        d.set(disableBasic,          forKey: PrefKeyDisableBasic)
    }
}
