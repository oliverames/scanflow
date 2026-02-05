//
//  SettingsView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

#if os(macOS)
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ScannerSettings()
                .tabItem {
                    Label("Scanner", systemImage: "scanner")
                }

            ProcessingSettings()
                .tabItem {
                    Label("Processing", systemImage: "wand.and.stars")
                }

            AdvancedSettings()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(minWidth: 500, idealWidth: 550, minHeight: 400, idealHeight: 500)
    }
}

struct GeneralSettings: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Default Scan Settings") {
                Picker("Resolution:", selection: $appState.defaultResolution) {
                    Text("300 DPI").tag(300)
                    Text("600 DPI").tag(600)
                    Text("1200 DPI").tag(1200)
                }

                Picker("Format:", selection: $appState.defaultFormat) {
                    Text("JPEG").tag("jpeg")
                    Text("PNG").tag("png")
                    Text("TIFF").tag("tiff")
                }
            }

            Section("File Organization") {
                Picker("Organization:", selection: $appState.organizationPattern) {
                    Text("Single folder").tag("single")
                    Text("By date (YYYY-MM-DD)").tag("date")
                    Text("By month (YYYY-MM)").tag("month")
                }

                TextField("Naming Pattern:", text: $appState.fileNamingTemplate)
                    .help("Use: yyyy (year), MM (month), dd (day), ### (number)")
                Text("Example: \(exampleFilename)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Automatically open destination folder", isOn: $appState.autoOpenDestination)
                Toggle("Use mock scanner for testing", isOn: $appState.useMockScanner)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var exampleFilename: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = appState.fileNamingTemplate.replacingOccurrences(of: "###", with: "001")
        return dateFormatter.string(from: Date())
    }
}

struct ScannerSettings: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Scanner") {
                Text("Scanner: \(appState.scannerManager.mockScannerName)")
                Text("Status: \(appState.scannerManager.connectionState.description)")

                Button("Discover Scanners") {
                    Task {
                        await appState.scannerManager.discoverScanners()
                    }
                }
            }

            Section("Background Connection") {
                Toggle(
                    "Keep connected when closing ScanFlow",
                    isOn: Binding(
                        get: { appState.keepConnectedInBackground },
                        set: { newValue in
                            appState.keepConnectedInBackground = newValue
                            appState.handleKeepConnectedToggle(newValue)
                        }
                    )
                )
                Toggle("Auto-start scans when scanner is ready", isOn: $appState.autoStartScanWhenReady)
                    .disabled(!appState.keepConnectedInBackground)
                Toggle(
                    "Start at login",
                    isOn: Binding(
                        get: { appState.startAtLogin },
                        set: { newValue in
                            appState.handleStartAtLoginToggle(newValue)
                        }
                    )
                )
                .disabled(appState.keepConnectedInBackground)
                Toggle("Show background prompt on quit", isOn: $appState.shouldPromptForBackgroundConnection)

                Text("Auto-start uses scanner readiness signals and may vary by device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Auto-start Scanners") {
                if appState.scannerManager.availableScanners.isEmpty {
                    Text("Available scanners will appear here")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.scannerManager.availableScanners, id: \.self) { scanner in
                        Toggle(
                            scanner.name ?? "Unknown Scanner",
                            isOn: Binding(
                                get: { appState.isAutoStartEnabled(for: scanner) },
                                set: { newValue in
                                    appState.setAutoStartEnabled(newValue, for: scanner)
                                }
                            )
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ProcessingSettings: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section {
                AIRenamingSettingsView(settings: $appState.defaultNamingSettings)
            } header: {
                Label("AI-Assisted File Naming", systemImage: "sparkles")
            }

            Section {
                DocumentSeparationSettingsView(settings: $appState.defaultSeparationSettings)
            } header: {
                Label("Document Separation", systemImage: "doc.on.doc")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AdvancedSettings: View {
    var body: some View {
        Form {
            Section("Performance") {
                Text("Advanced settings coming soon")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
#endif
