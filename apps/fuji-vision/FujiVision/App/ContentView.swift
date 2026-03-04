/* ContentView.swift — Main window layout for Fuji-Vision
 *
 * Hosts the emulator display, on-screen controls overlay, and a toolbar
 * with disk/cartridge/media management and emulator controls.
 */

import SwiftUI

struct ContentView: View {
    @Environment(EmulatorSession.self) private var session

    @State private var showFileImporter = false
    @State private var importTarget: MediaImportTarget = .disk1

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
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Emulator control buttons
                Button(action: { session.togglePause() }) {
                    Label(session.isPaused ? "Resume" : "Pause",
                          systemImage: session.isPaused ? "play.fill" : "pause.fill")
                }

                Button(action: { session.warmReset() }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }

                Divider()

                // Media management
                Menu {
                    Button("Insert Disk (D1:)") {
                        importTarget = .disk1
                        showFileImporter = true
                    }
                    Button("Insert Cartridge") {
                        importTarget = .cartridge
                        showFileImporter = true
                    }
                    Button("Load Executable") {
                        importTarget = .executable
                        showFileImporter = true
                    }
                    Button("Mount Cassette") {
                        importTarget = .cassette
                        showFileImporter = true
                    }
                } label: {
                    Label("Media", systemImage: "opticaldisc")
                }

                Divider()

                // Machine type
                Menu {
                    Button("Atari 800") { session.setMachineModel(.model800) }
                    Button("Atari XL/XE") { session.setMachineModel(.modelXLXE) }
                    Button("Atari 5200") { session.setMachineModel(.model5200) }
                } label: {
                    Label("Machine", systemImage: "desktopcomputer")
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
        .onAppear {
            session.start()
        }
        .onDisappear {
            session.stop()
        }
    }
}

/// Target for file import operations
enum MediaImportTarget {
    case disk1, disk2, cartridge, executable, cassette

    var allowedTypes: [UTType] {
        // All Atari media types — refined when UTType declarations are added
        [.data]
    }
}

import UniformTypeIdentifiers
