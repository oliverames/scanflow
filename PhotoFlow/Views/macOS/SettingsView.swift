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

            BarcodeSettingsView()
                .tabItem {
                    Label("Barcode", systemImage: "barcode.viewfinder")
                }

            ImprinterSettingsView()
                .tabItem {
                    Label("Imprinter", systemImage: "textformat")
                }

            AdvancedSettings()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 550, height: 480)
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

struct BarcodeSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Barcode Recognition") {
                Toggle("Enable barcode recognition", isOn: $appState.barcodeEnabled)

                if appState.barcodeEnabled {
                    Slider(value: $appState.barcodeMinimumConfidence, in: 0.1...1.0, step: 0.1) {
                        Text("Minimum confidence: \(Int(appState.barcodeMinimumConfidence * 100))%")
                    }
                }
            }

            if appState.barcodeEnabled {
                Section("Document Organization") {
                    Toggle("Use barcode for file naming", isOn: $appState.barcodeUseForNaming)
                        .help("Name files based on barcode content")

                    Toggle("Use barcode for folder routing", isOn: $appState.barcodeUseForFolderRouting)
                        .help("Organize files into folders based on barcode prefix")

                    Toggle("Add barcode to file metadata", isOn: $appState.barcodeAddToMetadata)
                        .help("Store barcode information in file metadata for Spotlight")
                }

                Section("Batch Processing") {
                    Toggle("Split batches on barcode", isOn: $appState.barcodeUseForSplitting)
                        .help("Start a new document when a matching barcode is found")

                    if appState.barcodeUseForSplitting {
                        TextField("Split pattern (regex):", text: $appState.barcodeSplitPattern)
                            .help("Regular expression pattern to match for splitting")
                        Text("Example: ^SEP.*$ matches barcodes starting with 'SEP'")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ImprinterSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Dynamic Imprinter") {
                Toggle("Enable imprinting", isOn: $appState.imprinterEnabled)

                if appState.imprinterEnabled {
                    TextField("Custom text:", text: $appState.imprinterText)
                        .help("Text to overlay on scanned documents")
                }
            }

            if appState.imprinterEnabled {
                Section("Content") {
                    Toggle("Include date", isOn: $appState.imprinterIncludeDate)
                    Toggle("Include time", isOn: $appState.imprinterIncludeTime)
                    Toggle("Include page numbers", isOn: $appState.imprinterIncludePageNumbers)
                }

                Section("Appearance") {
                    Picker("Position:", selection: $appState.imprinterPosition) {
                        Text("Top Left").tag("topLeft")
                        Text("Top Right").tag("topRight")
                        Text("Bottom Left").tag("bottomLeft")
                        Text("Bottom Right").tag("bottomRight")
                        Text("Center").tag("center")
                    }

                    Picker("Rotation:", selection: $appState.imprinterRotation) {
                        Text("0°").tag(0)
                        Text("90°").tag(90)
                        Text("180°").tag(180)
                        Text("270°").tag(270)
                    }

                    Slider(value: $appState.imprinterOpacity, in: 0.1...1.0, step: 0.1) {
                        Text("Opacity: \(Int(appState.imprinterOpacity * 100))%")
                    }

                    Slider(value: $appState.imprinterFontSize, in: 12...72, step: 2) {
                        Text("Font size: \(Int(appState.imprinterFontSize))pt")
                    }

                    TextField("Font name:", text: $appState.imprinterFontName)
                    TextField("Text color (hex):", text: $appState.imprinterTextColor)
                        .help("Example: #000000 for black, #FF0000 for red")
                }

                Section("Preview") {
                    Text(imprinterPreview)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var imprinterPreview: String {
        var components: [String] = []
        if !appState.imprinterText.isEmpty {
            components.append(appState.imprinterText)
        }
        if appState.imprinterIncludeDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            components.append(formatter.string(from: Date()))
        }
        if appState.imprinterIncludeTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            components.append(formatter.string(from: Date()))
        }
        if appState.imprinterIncludePageNumbers {
            components.append("Page 1")
        }
        return components.isEmpty ? "(No content configured)" : components.joined(separator: " • ")
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
