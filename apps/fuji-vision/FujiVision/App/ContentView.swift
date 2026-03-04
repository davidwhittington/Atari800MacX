/* ContentView.swift — Main window layout for Fuji-Vision
 *
 * Hosts the emulator display, on-screen controls overlay, and a toolbar
 * with disk/cartridge/media management and emulator controls.
 */

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(EmulatorSession.self) private var session

    @State private var showFileImporter = false
    @State private var importTarget: MediaImportTarget = .disk1
    @State private var showSettings = false
    @State private var showSaveStates = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Emulator display fills the window
            EmulatorView()

            // Virtual controls overlay (bottom of screen)
            VStack {
                Spacer()
                OnScreenControlsView()
                    .padding(.bottom, 20)
            }

            // Disk LED indicator (top-right)
            if session.diskLEDStatus > 0 {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(session.diskLEDStatus >= 10 ? .red : .green)
                            .frame(width: 10, height: 10)
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Emulator controls
                Button(action: { session.togglePause() }) {
                    Label(session.isPaused ? "Resume" : "Pause",
                          systemImage: session.isPaused ? "play.fill" : "pause.fill")
                }

                Button(action: { session.warmReset() }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }

                Divider()

                // Disk drives
                Menu {
                    Section("Drive D1:") {
                        Button("Insert Disk...") {
                            importTarget = .disk1
                            showFileImporter = true
                        }
                        if session.mountedMedia[.disk1] != nil {
                            Button("Eject D1:") { session.ejectMedia(.disk1) }
                        }
                    }
                    Section("Drive D2:") {
                        Button("Insert Disk...") {
                            importTarget = .disk2
                            showFileImporter = true
                        }
                        if session.mountedMedia[.disk2] != nil {
                            Button("Eject D2:") { session.ejectMedia(.disk2) }
                        }
                    }
                } label: {
                    Label("Disks", systemImage: "opticaldiscdrive")
                }

                // Cartridge
                Menu {
                    Button("Insert Cartridge...") {
                        importTarget = .cartridge
                        showFileImporter = true
                    }
                    if session.mountedMedia[.cartridge] != nil {
                        Button("Remove Cartridge") { session.ejectMedia(.cartridge) }
                    }
                } label: {
                    Label("Cartridge", systemImage: "cpu")
                }

                // More media
                Menu {
                    Button("Load Executable...") {
                        importTarget = .executable
                        showFileImporter = true
                    }
                    Button("Mount Cassette...") {
                        importTarget = .cassette
                        showFileImporter = true
                    }
                    if session.mountedMedia[.cassette] != nil {
                        Button("Eject Cassette") { session.ejectMedia(.cassette) }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }

                Divider()

                // Machine type
                Menu {
                    Button("Atari 800") { session.setMachineModel(.model800) }
                    Button("Atari XL/XE") { session.setMachineModel(.modelXLXE) }
                    Button("Atari 5200") { session.setMachineModel(.model5200) }
                } label: {
                    Label(session.machineModelName, systemImage: "desktopcomputer")
                }

                Divider()

                // Save states
                Button(action: { showSaveStates = true }) {
                    Label("Save States", systemImage: "square.and.arrow.down")
                }

                // Settings
                Button(action: { showSettings = true }) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: importTarget.allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                session.importMedia(url: url, target: importTarget)
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            mediaStatusBar
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(session)
        }
        .sheet(isPresented: $showSaveStates) {
            SaveStateView()
                .environment(session)
        }
        .onAppear {
            session.start()
        }
        .onDisappear {
            session.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                session.handleBackground()
            case .active:
                session.handleForeground()
            @unknown default:
                break
            }
        }
    }

    // MARK: - Media Status Bar (visionOS ornament)

    @ViewBuilder
    private var mediaStatusBar: some View {
        let media = session.mountedMedia
        if !media.isEmpty {
            HStack(spacing: 16) {
                ForEach(Array(media.sorted(by: { $0.key.sortOrder < $1.key.sortOrder })),
                        id: \.key) { target, name in
                    Label(name, systemImage: target.icon)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassBackgroundEffect()
        }
    }
}

/// Target for file import operations
enum MediaImportTarget: Hashable {
    case disk1, disk2, cartridge, executable, cassette

    var allowedTypes: [UTType] {
        switch self {
        case .disk1, .disk2:
            return [.atariDiskATR, .atariDiskXFD, .data]
        case .cartridge:
            return [.atariCartridge, .data]
        case .executable:
            return [.atariExecutable, .data]
        case .cassette:
            return [.atariCassette, .data]
        }
    }

    var icon: String {
        switch self {
        case .disk1:     return "opticaldiscdrive"
        case .disk2:     return "opticaldiscdrive"
        case .cartridge: return "cpu"
        case .executable: return "doc"
        case .cassette:  return "recordingtape"
        }
    }

    var sortOrder: Int {
        switch self {
        case .disk1: return 0
        case .disk2: return 1
        case .cartridge: return 2
        case .executable: return 3
        case .cassette: return 4
        }
    }
}
