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

            AdvancedSettings()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 500, height: 400)
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
        return (try? dateFormatter.string(from: Date())) ?? "2024-12-30_001.jpg"
    }
}

struct ScannerSettings: View {
    @Environment(AppState.self) private var appState

    var body: some View {
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

            Section("Connection") {
                Text("Available scanners will appear here")
                    .foregroundStyle(.secondary)
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
