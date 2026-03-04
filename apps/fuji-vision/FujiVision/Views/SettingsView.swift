/* SettingsView.swift — Emulator settings panel for Fuji-Vision
 *
 * Presented as a sheet from the toolbar. Controls TV mode, machine type,
 * audio, speed, and display options. Changes apply immediately to the
 * running emulator via Atari800Core_Set* APIs.
 */

import SwiftUI

struct SettingsView: View {
    @Environment(EmulatorSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    // Display
    @AppStorage("FV_TVMode") private var tvMode: Int = 0  // 0=NTSC, 1=PAL
    @AppStorage("FV_ArtifactingMode") private var artifactingMode: Int = 0
    @AppStorage("FV_LinearFilter") private var linearFilter: Bool = false
    @AppStorage("FV_Scanlines") private var scanlines: Bool = false
    @AppStorage("FV_ScanlineTransparency") private var scanlineTransparency: Double = 0.9

    // Audio
    @AppStorage("FV_AudioEnabled") private var audioEnabled: Bool = true
    @AppStorage("FV_AudioVolume") private var audioVolume: Double = 1.0
    @AppStorage("FV_StereoEnabled") private var stereoEnabled: Bool = false

    // Speed
    @AppStorage("FV_SpeedLimit") private var speedLimit: Bool = true
    @AppStorage("FV_EmulationSpeed") private var emulationSpeed: Double = 1.0

    // Visibility
    @AppStorage("FV_VisibilityMode") private var visibilityMode: Int = 0
    @AppStorage("FV_KeyEnabled") private var keyEnabled: Bool = false
    @AppStorage("FV_KeyThreshold") private var keyThreshold: Double = 0.1
    @AppStorage("FV_KeySoftEdge") private var keySoftEdge: Double = 0.05
    @AppStorage("FV_KeyInvert") private var keyInvert: Bool = false
    @AppStorage("FV_AutoDetect") private var autoDetect: Bool = false
    @AppStorage("FV_AutoDetectSensitivity") private var autoDetectSensitivity: Double = 0.5
    @AppStorage("FV_DetectedColorLocked") private var detectedColorLocked: Bool = false
    @AppStorage("FV_EdgeEnhance") private var edgeEnhance: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                displaySection
                visibilitySection
                audioSection
                speedSection
                machineSection
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }

    // MARK: - Display

    private var displaySection: some View {
        Section("Display") {
            Picker("TV Mode", selection: $tvMode) {
                Text("NTSC").tag(0)
                Text("PAL").tag(1)
            }
            .onChange(of: tvMode) { _, newValue in
                Atari800Core_SetTVMode(Int32(newValue))
            }

            Picker("Artifacting", selection: $artifactingMode) {
                Text("None").tag(0)
                Text("NTSC Old").tag(1)
                Text("NTSC New").tag(2)
                Text("NTSC New Hi-Fi").tag(3)
            }
            .onChange(of: artifactingMode) { _, newValue in
                Atari800Core_SetArtifactingMode(Int32(newValue))
            }

            Toggle("Bilinear Filter", isOn: $linearFilter)
                .onChange(of: linearFilter) { _, newValue in
                    session.renderer?.linearFilterEnabled = newValue
                }

            Toggle("CRT Scanlines", isOn: $scanlines)
                .onChange(of: scanlines) { _, newValue in
                    session.renderer?.scanlinesEnabled = newValue
                }

            if scanlines {
                HStack {
                    Text("Scanline Intensity")
                    Slider(value: $scanlineTransparency, in: 0.5...1.0)
                }
                .onChange(of: scanlineTransparency) { _, newValue in
                    session.renderer?.scanlineTransparency = Float(newValue)
                }
            }
        }
    }

    // MARK: - Visibility

    private var visibilitySection: some View {
        Section("Visibility") {
            Picker("Mode", selection: $visibilityMode) {
                Text("Solid").tag(0)
                Text("Dim").tag(1)
                Text("Ghost").tag(2)
            }
            .onChange(of: visibilityMode) { _, newValue in
                if let mode = VisibilityMode(rawValue: newValue) {
                    session.renderer?.compositor.mode = mode
                }
            }

            Toggle("Chroma Key", isOn: $keyEnabled)
                .onChange(of: keyEnabled) { _, newValue in
                    session.renderer?.compositor.keyEnabled = newValue
                }

            if keyEnabled {
                HStack {
                    Text("Threshold")
                    Slider(value: $keyThreshold, in: 0.0...0.5)
                }
                .onChange(of: keyThreshold) { _, newValue in
                    session.renderer?.compositor.keyThreshold = Float(newValue)
                }

                HStack {
                    Text("Soft Edge")
                    Slider(value: $keySoftEdge, in: 0.0...0.3)
                }
                .onChange(of: keySoftEdge) { _, newValue in
                    session.renderer?.compositor.keySoftEdge = Float(newValue)
                }

                Toggle("Invert Key", isOn: $keyInvert)
                    .onChange(of: keyInvert) { _, newValue in
                        session.renderer?.compositor.keyInvert = newValue
                    }
            }

            Toggle("Auto-Detect Background", isOn: $autoDetect)
                .onChange(of: autoDetect) { _, newValue in
                    session.renderer?.compositor.autoDetectEnabled = newValue
                }

            if autoDetect {
                HStack {
                    Text("Sensitivity")
                    Slider(value: $autoDetectSensitivity, in: 0.0...1.0)
                }
                .onChange(of: autoDetectSensitivity) { _, newValue in
                    session.renderer?.compositor.autoDetectSensitivity = Float(newValue)
                }

                Toggle("Lock Detected Color", isOn: $detectedColorLocked)
                    .onChange(of: detectedColorLocked) { _, newValue in
                        session.renderer?.compositor.detectedColorLocked = newValue
                    }
            }

            Toggle("Edge Enhance", isOn: $edgeEnhance)
                .onChange(of: edgeEnhance) { _, newValue in
                    session.renderer?.compositor.edgeEnhanceEnabled = newValue
                }
        }
    }

    // MARK: - Audio

    private var audioSection: some View {
        Section("Audio") {
            Toggle("Sound Enabled", isOn: $audioEnabled)
                .onChange(of: audioEnabled) { _, newValue in
                    Atari800Core_SetAudioEnabled(newValue ? 1 : 0)
                }

            HStack {
                Text("Volume")
                Slider(value: $audioVolume, in: 0.0...1.0)
            }
            .onChange(of: audioVolume) { _, newValue in
                Atari800Core_SetAudioVolume(newValue)
                session.setAudioVolume(Float(newValue))
            }

            Toggle("Stereo POKEY", isOn: $stereoEnabled)
                .onChange(of: stereoEnabled) { _, newValue in
                    Atari800Core_SetStereoEnabled(newValue ? 1 : 0)
                }
        }
    }

    // MARK: - Speed

    private var speedSection: some View {
        Section("Speed") {
            Toggle("Speed Limit", isOn: $speedLimit)
                .onChange(of: speedLimit) { _, newValue in
                    Atari800Core_SetSpeedLimitEnabled(newValue ? 1 : 0)
                }

            if speedLimit {
                HStack {
                    Text("Speed: \(Int(emulationSpeed * 100))%")
                    Slider(value: $emulationSpeed, in: 0.5...4.0, step: 0.25)
                }
                .onChange(of: emulationSpeed) { _, newValue in
                    Atari800Core_SetSpeed(newValue)
                }
            }
        }
    }

    // MARK: - Machine

    private var machineSection: some View {
        Section("Machine") {
            Button("Atari 800") { session.setMachineModel(.model800) }
            Button("Atari XL/XE") { session.setMachineModel(.modelXLXE) }
            Button("Atari 5200") { session.setMachineModel(.model5200) }

            Text("Current: \(session.machineModelName)")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}
