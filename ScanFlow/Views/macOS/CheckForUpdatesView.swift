//
//  CheckForUpdatesView.swift
//  ScanFlow
//
//  SwiftUI view for Check for Updates menu item
//

import SwiftUI
#if os(macOS)
import Sparkle

/// SwiftUI view for the "Check for Updates" menu item
public struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    public init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    public var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

/// Settings view section for update preferences
struct UpdateSettingsView: View {
    @ObservedObject var softwareUpdater: SoftwareUpdater

    var body: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: $softwareUpdater.automaticallyChecksForUpdates)

                Toggle("Automatically download updates", isOn: $softwareUpdater.automaticallyDownloadsUpdates)
                    .disabled(!softwareUpdater.automaticallyChecksForUpdates)

                if let lastCheck = softwareUpdater.lastUpdateCheckDate {
                    HStack {
                        Text("Last checked:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lastCheck, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Check Now") {
                    softwareUpdater.checkForUpdates()
                }
            } header: {
                Label("Software Updates", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }
}

#endif
