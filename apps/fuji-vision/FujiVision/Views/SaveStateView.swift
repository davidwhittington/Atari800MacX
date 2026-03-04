/* SaveStateView.swift — Save/load state management for Fuji-Vision
 *
 * Presents a list of save state slots (1-10) with save/load/delete actions.
 * States are stored in the app sandbox Documents/SaveStates/ directory.
 */

import SwiftUI

struct SaveStateView: View {
    @Environment(EmulatorSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var slots: [SaveSlot] = []
    @State private var showDeleteConfirmation: Int? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(slots) { slot in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Slot \(slot.number)")
                                .font(.headline)
                            if let date = slot.date {
                                Text(date, style: .date) + Text(" ") + Text(date, style: .time)
                            } else {
                                Text("Empty")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button("Save") {
                            session.saveState(slot: slot.number)
                            refreshSlots()
                        }
                        .buttonStyle(.bordered)

                        if slot.exists {
                            Button("Load") {
                                session.loadState(slot: slot.number)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)

                            Button(role: .destructive) {
                                session.deleteState(slot: slot.number)
                                refreshSlots()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .navigationTitle("Save States")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { refreshSlots() }
        }
        .frame(minWidth: 400, minHeight: 400)
    }

    private func refreshSlots() {
        slots = (1...10).map { num in
            let url = SaveStateView.stateURL(slot: num)
            let exists = FileManager.default.fileExists(atPath: url.path)
            var date: Date? = nil
            if exists {
                date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
            }
            return SaveSlot(number: num, exists: exists, date: date)
        }
    }

    static func stateURL(slot: Int) -> URL {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let stateDir = docsDir.appendingPathComponent("SaveStates", isDirectory: true)
        try? FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        return stateDir.appendingPathComponent("state_\(slot).a8s")
    }
}

struct SaveSlot: Identifiable {
    let number: Int
    let exists: Bool
    let date: Date?
    var id: Int { number }
}
