//
//  SettingsView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

#if os(macOS)
import SwiftUI

public struct SettingsView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
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
    @State private var twainScannerNames: [String] = []
    @State private var selectedTWAINScanner = ""
    @State private var twainCapabilities: TWAINBridge.TWAINCapabilities?
    @State private var twainSettings = TWAINBridge.TWAINSettings()
    @State private var isDiscoveringTWAIN = false
    @State private var isConnectingTWAIN = false
    @State private var isApplyingTWAIN = false

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

                Toggle(
                    "Enable Remote Scan Server",
                    isOn: Binding(
                        get: { appState.remoteScanServerEnabled },
                        set: { newValue in
                            appState.handleRemoteScanServerToggle(newValue)
                        }
                    )
                )

                Text("Allows iOS devices on your network to request scans.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Require pairing token for remote scans", isOn: $appState.remoteScanRequirePairingToken)

                TextField("Pairing token", text: $appState.remoteScanPairingToken)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disabled(!appState.remoteScanRequirePairingToken)

                HStack {
                    Button("Generate Token") {
                        appState.generateRemotePairingToken()
                    }
                    .disabled(!appState.remoteScanRequirePairingToken)

                    Button("Copy Token") {
                        appState.copyRemotePairingTokenToClipboard()
                    }
                    .disabled(!appState.remoteScanRequirePairingToken || appState.remoteScanPairingToken.isEmpty)
                }

                Text("When enabled, iOS requests must include the exact token shown here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("TWAIN (Beta)") {
                Label(
                    appState.twainBridge.isTWAINAvailable ? "TWAIN bridge available" : "TWAIN bridge unavailable",
                    systemImage: appState.twainBridge.isTWAINAvailable ? "checkmark.circle.fill" : "xmark.octagon.fill"
                )
                .foregroundStyle(appState.twainBridge.isTWAINAvailable ? .green : .secondary)

                HStack {
                    Button("Discover TWAIN Sources") {
                        discoverTWAINSources()
                    }
                    .disabled(isDiscoveringTWAIN)

                    if isDiscoveringTWAIN {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if twainScannerNames.isEmpty {
                    Text("No TWAIN sources discovered yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Scanner", selection: $selectedTWAINScanner) {
                        ForEach(twainScannerNames, id: \.self) { scanner in
                            Text(scanner).tag(scanner)
                        }
                    }

                    HStack {
                        Button("Connect") {
                            connectTWAINScanner()
                        }
                        .disabled(selectedTWAINScanner.isEmpty || isConnectingTWAIN)

                        Button("Disconnect") {
                            disconnectTWAINScanner()
                        }
                        .disabled(!appState.twainBridge.isConnected)

                        if isConnectingTWAIN {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }

                if let capabilities = twainCapabilities, appState.twainBridge.isConnected {
                    Divider()

                    Text("Connected: \(capabilities.manufacturer) \(capabilities.model)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Stepper(
                        "Resolution: \(twainSettings.resolution) DPI",
                        value: $twainSettings.resolution,
                        in: capabilities.minResolution...capabilities.maxResolution,
                        step: 25
                    )

                    Picker("Source", selection: $twainSettings.source) {
                        ForEach(supportedTWAINSources(for: capabilities), id: \.self) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }

                    Picker("Color Mode", selection: $twainSettings.colorMode) {
                        ForEach(supportedTWAINColorModes(for: capabilities), id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    Picker("Paper Size", selection: $twainSettings.paperSize) {
                        ForEach(supportedTWAINPaperSizes(for: capabilities), id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }

                    Toggle("Duplex", isOn: $twainSettings.duplex)
                        .disabled(!capabilities.supportsDuplex || twainSettings.source == .flatbed)

                    Toggle("Auto-feed", isOn: $twainSettings.autoFeed)
                        .disabled(!capabilities.supportsADF || twainSettings.source == .flatbed)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Brightness: \(Int(twainSettings.brightness))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $twainSettings.brightness, in: -100...100, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Contrast: \(Int(twainSettings.contrast))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $twainSettings.contrast, in: -100...100, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Exposure: \(Int(twainSettings.exposure))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $twainSettings.exposure, in: -100...100, step: 1)
                    }

                    if twainSettings.colorMode == .blackWhite {
                        Stepper("Threshold: \(twainSettings.threshold)", value: $twainSettings.threshold, in: 0...255)
                    }

                    Button("Apply TWAIN Settings") {
                        applyTWAINSettings()
                    }
                    .disabled(isApplyingTWAIN)
                } else {
                    Text("Connect to a TWAIN source to configure bridge settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            Section("Menu Bar") {
                Toggle(
                    "Always show menu bar icon",
                    isOn: Binding(
                        get: { appState.menuBarAlwaysEnabled },
                        set: { newValue in
                            appState.menuBarAlwaysEnabled = newValue
                            NotificationCenter.default.post(name: .scanflowMenuBarSettingChanged, object: nil)
                        }
                    )
                )
                Text("When enabled, the ScanFlow menu bar icon remains visible even when the app is open or background mode is disabled.")
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
        .task {
            twainSettings = appState.twainBridge.currentSettings
            if appState.twainBridge.isConnected {
                twainCapabilities = try? await appState.twainBridge.getCapabilities()
            }
        }
        .onChange(of: twainSettings.source) { _, newSource in
            if newSource == .flatbed {
                twainSettings.duplex = false
                twainSettings.autoFeed = false
            } else if newSource == .adf {
                twainSettings.autoFeed = true
            }
        }
    }

    private func discoverTWAINSources() {
        Task {
            isDiscoveringTWAIN = true
            defer { isDiscoveringTWAIN = false }
            do {
                let names = try await appState.twainBridge.discoverTWAINScanners()
                twainScannerNames = names
                if selectedTWAINScanner.isEmpty || !names.contains(selectedTWAINScanner) {
                    selectedTWAINScanner = names.first ?? ""
                }
            } catch {
                appState.showAlert(message: "TWAIN discovery failed: \(error.localizedDescription)")
            }
        }
    }

    private func connectTWAINScanner() {
        Task {
            guard !selectedTWAINScanner.isEmpty else { return }
            isConnectingTWAIN = true
            defer { isConnectingTWAIN = false }
            do {
                twainCapabilities = try await appState.twainBridge.connect(to: selectedTWAINScanner)
                twainSettings = appState.twainBridge.currentSettings
            } catch {
                appState.showAlert(message: "TWAIN connect failed: \(error.localizedDescription)")
            }
        }
    }

    private func disconnectTWAINScanner() {
        Task {
            await appState.twainBridge.disconnect()
            twainCapabilities = nil
            twainSettings = TWAINBridge.TWAINSettings()
        }
    }

    private func applyTWAINSettings() {
        Task {
            isApplyingTWAIN = true
            defer { isApplyingTWAIN = false }
            do {
                try await appState.twainBridge.updateSettings(twainSettings)
                twainSettings = appState.twainBridge.currentSettings
            } catch {
                appState.showAlert(message: "Failed to apply TWAIN settings: \(error.localizedDescription)")
            }
        }
    }

    private func supportedTWAINSources(for capabilities: TWAINBridge.TWAINCapabilities) -> [TWAINBridge.TWAINSettings.Source] {
        var sources: [TWAINBridge.TWAINSettings.Source] = []
        if capabilities.supportsFlatbed {
            sources.append(.flatbed)
        }
        if capabilities.supportsADF {
            sources.append(.adf)
            sources.append(.auto)
        }
        return sources.isEmpty ? [.flatbed] : sources
    }

    private func supportedTWAINColorModes(for capabilities: TWAINBridge.TWAINCapabilities) -> [TWAINBridge.TWAINSettings.ColorMode] {
        let supported = TWAINBridge.TWAINSettings.ColorMode.allCases.filter {
            capabilities.supportedColorModes.contains($0.rawValue)
        }
        return supported.isEmpty ? [.color] : supported
    }

    private func supportedTWAINPaperSizes(for capabilities: TWAINBridge.TWAINCapabilities) -> [TWAINBridge.TWAINSettings.PaperSize] {
        var supported = TWAINBridge.TWAINSettings.PaperSize.allCases.filter {
            $0 == .custom || capabilities.supportedPaperSizes.contains($0.rawValue)
        }
        if supported.isEmpty {
            supported = [.letter]
        }
        return supported
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
    @Environment(AppState.self) private var appState
    @State private var showingResetConfirmation = false

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Performance") {
                Stepper(value: $appState.scannerDiscoveryTimeoutSeconds, in: 1...15) {
                    Text("Scanner discovery timeout: \(appState.scannerDiscoveryTimeoutSeconds) sec")
                }

                Stepper(value: $appState.scanTimeoutSeconds, in: 30...900, step: 30) {
                    Text("Scan timeout: \(appState.scanTimeoutSeconds) sec")
                }

                Stepper(value: $appState.maxBufferedPages, in: 25...500, step: 25) {
                    Text("Max buffered ADF pages: \(appState.maxBufferedPages)")
                }

                Toggle("Preserve temporary scan files", isOn: $appState.preserveTemporaryScanFiles)

                Text("Preserved files are written under the ScanFlow folder in your temporary directory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Maintenance") {
                Button("Reveal Temporary Scan Folder") {
                    appState.revealTemporaryScanFolder()
                }

                Button("Export Diagnostics Bundle") {
                    appState.exportDiagnosticsBundle()
                }

                Button("Reset Settings to Defaults", role: .destructive) {
                    showingResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Reset all app settings?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                appState.resetSettingsToDefaults()
            }
        } message: {
            Text("This keeps existing presets and only resets app-level settings.")
        }
    }
}

#endif
