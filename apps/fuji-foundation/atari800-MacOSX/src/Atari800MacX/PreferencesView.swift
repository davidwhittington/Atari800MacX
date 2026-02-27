// PreferencesView.swift
// Phase 7: SwiftUI tabbed Preferences window for Atari800MacX.
//
// This view is hosted by SwiftUIPanelCoordinator via NSHostingController.
// It replaces the XIB-based Preferences window over time (Phase 7 establishes
// the structure; individual tabs are fleshed out as the ObjC prefs are retired).

import SwiftUI

// MARK: - Top-level container

struct PreferencesView: View {
    @ObservedObject var model: PreferenceModel

    var body: some View {
        TabView {
            VideoPreferencesTab(model: model)
                .tabItem { Label("Video", systemImage: "display") }

            AudioPreferencesTab(model: model)
                .tabItem { Label("Audio", systemImage: "speaker.wave.2") }

            InputPreferencesTab()
                .tabItem { Label("Input", systemImage: "gamecontroller") }

            MachinePreferencesTab(model: model)
                .tabItem { Label("Machine", systemImage: "cpu") }

            PeripheralsPreferencesTab()
                .tabItem { Label("Peripherals", systemImage: "printer") }

            PathsPreferencesTab()
                .tabItem { Label("Paths", systemImage: "folder") }
        }
        .frame(minWidth: 620, minHeight: 480)
        .onDisappear { model.save() }
    }
}

// MARK: - Video tab

struct VideoPreferencesTab: View {
    @ObservedObject var model: PreferenceModel

    var body: some View {
        Form {
            Section("TV System") {
                Picker("TV Mode", selection: $model.videoMode) {
                    Text("NTSC").tag(VideoMode.ntsc)
                    Text("PAL").tag(VideoMode.pal)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Display Scaling") {
                Picker("Scale Mode", selection: $model.scalingMode) {
                    Text("Normal").tag(ScalingMode.normal)
                    Text("Scanlines").tag(ScalingMode.scanline)
                }
                .pickerStyle(.inline)
                .labelsHidden()

                Toggle("Fix Aspect Ratio in Fullscreen", isOn: $model.fixAspectFullscreen)
                Toggle("Integer Scaling Only", isOn: $model.onlyIntegralScaling)
            }

            Section("On-Screen Indicators") {
                Toggle("Show FPS Counter", isOn: $model.showFPS)
            }

            Section("NTSC Artifacting") {
                Picker("Artifacting Mode", selection: $model.artifactingMode) {
                    Text("None").tag(0)
                    Text("Blue/Brown").tag(1)
                    Text("Blue/Green").tag(2)
                    Text("CTIA").tag(3)
                    Text("GTIA").tag(4)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .padding(.vertical)
    }
}

// MARK: - Audio tab

struct AudioPreferencesTab: View {
    @ObservedObject var model: PreferenceModel

    var body: some View {
        Form {
            Section("Sound Output") {
                Toggle("Enable Sound", isOn: $model.audioEnabled)

                HStack {
                    Text("Volume")
                    Slider(value: $model.audioVolume, in: 0...1)
                    Text("\(Int(model.audioVolume * 100))%")
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
                .disabled(!model.audioEnabled)

                Toggle("POKEY Stereo", isOn: $model.stereoEnabled)
                    .disabled(!model.audioEnabled)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical)
    }
}

// MARK: - Input tab (stub)

struct InputPreferencesTab: View {
    var body: some View {
        VStack {
            Text("Input preferences are managed in the ObjC Preferences window.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Text("This tab will be implemented in a future update.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Machine tab

struct MachinePreferencesTab: View {
    @ObservedObject var model: PreferenceModel

    private let machineOptions: [(label: String, tag: Int)] = [
        ("Atari 800", 0),
        ("Atari XL/XE", 1),
        ("Atari 5200", 2),
    ]

    var body: some View {
        Form {
            Section("Machine Type") {
                Picker("Machine", selection: $model.machineModel) {
                    ForEach(machineOptions, id: \.tag) { opt in
                        Text(opt.label).tag(opt.tag)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Emulation Options") {
                Toggle("Speed Limit (≈60 fps)", isOn: $model.speedLimit)
                Toggle("Disable BASIC", isOn: $model.disableBasic)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical)
    }
}

// MARK: - Peripherals tab (stub)

struct PeripheralsPreferencesTab: View {
    var body: some View {
        VStack {
            Text("Peripheral preferences (printers, hard disk, expansion boards) are managed in the ObjC Preferences window.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Text("This tab will be implemented in a future update.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Paths tab (stub)

struct PathsPreferencesTab: View {
    var body: some View {
        VStack {
            Text("ROM paths and directory settings are managed in the ObjC Preferences window.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Text("This tab will be implemented in a future update.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
