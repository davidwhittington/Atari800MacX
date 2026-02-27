// AboutBoxView.swift
// Phase 7: SwiftUI About Box for Atari800MacX.

import SwiftUI
import AppKit

struct AboutBoxView: View {

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "6.1.2"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? "Version \(v)" : "Version \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("Atari800MacX")
                .font(.largeTitle.bold())

            Text(versionString)
                .foregroundStyle(.secondary)

            Text("Copyright © 2002–2026 Mark Grebe")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Based on the Atari 800 emulator by David Firth.\nAdditional contributors listed in Credits.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 360)
    }
}
