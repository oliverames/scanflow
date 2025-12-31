//
//  ScanFlowApp.swift
//  ScanFlow
//
//  Professional document scanning application for macOS 26+
//

import SwiftUI

@main
struct ScanFlowApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            MainWindow()
                .environment(appState)
                .frame(minWidth: 1100, idealWidth: 1300, minHeight: 700, idealHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1300, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Start Scan") {
                    Task {
                        await appState.startScanning()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Add to Queue") {
                    appState.addToQueue(preset: appState.currentPreset, count: 1)
                }
                .keyboardShortcut("q", modifiers: .command)
            }

            CommandMenu("Scanner") {
                Button("Discover Scanners") {
                    Task {
                        await appState.scannerManager.discoverScanners()
                    }
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                // Show available scanners
                #if os(macOS)
                if !appState.scannerManager.availableScanners.isEmpty {
                    ForEach(appState.scannerManager.availableScanners, id: \.self) { scanner in
                        Button(scanner.name ?? "Unknown Scanner") {
                            Task {
                                try? await appState.scannerManager.connect(to: scanner)
                            }
                        }
                    }
                    Divider()
                }
                #endif

                Button("Disconnect Scanner") {
                    Task {
                        await appState.scannerManager.disconnect()
                    }
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .disabled(!appState.scannerManager.connectionState.isConnected)

                Divider()

                Button("Start Scan") {
                    Task {
                        await appState.startScanning()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Preview Scan") {
                    Task {
                        #if os(macOS)
                        _ = try? await appState.scannerManager.requestOverviewScan()
                        #endif
                    }
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(!appState.scannerManager.connectionState.isConnected)
            }

            CommandMenu("View") {
                Button("Scan") {
                    appState.selectedSection = .scan
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Scan Queue") {
                    appState.selectedSection = .queue
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Scanned Files") {
                    appState.selectedSection = .library
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Presets") {
                    appState.selectedSection = .presets
                }
                .keyboardShortcut("4", modifiers: .command)
            }

            CommandMenu("Presets") {
                ForEach(appState.presets) { preset in
                    Button(preset.name) {
                        appState.currentPreset = preset
                    }
                }
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
        #else
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        #endif
    }
}
