//
//  ControlPanelView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI
import os.log
import UniformTypeIdentifiers
#if os(macOS)
import ImageCaptureCore
#endif

private let logger = Logger(subsystem: "com.scanflow.app", category: "ControlPanelView")

struct ControlPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Filing").tag(0)
                Text("Basic").tag(1)
                Text("Advanced").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            // Tab content
            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    switch selectedTab {
                    case 0:
                        filingTab
                    case 1:
                        basicSettingsTab
                    case 2:
                        advancedSettingsTab
                    default:
                        filingTab
                    }
                }
                .padding(16)
            }

            Divider()

            // Scan Button - Fixed at bottom
            VStack(spacing: 8) {
                Button {
                    logger.info("Scan button pressed")
                    Task {
                        appState.addToQueue(preset: appState.currentPreset, count: 1)
                        await appState.startScanning()
                    }
                } label: {
                    HStack {
                        Image(systemName: appState.isScanning ? "stop.circle.fill" : "play.circle.fill")
                        Text(appState.isScanning ? "Scanning..." : "Scan")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appState.isScanning || (!appState.scannerManager.connectionState.isConnected && !appState.useMockScanner))
            }
            .padding(16)
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
    }

    // MARK: - Filing Tab

    private var filingTab: some View {
        @Bindable var appState = appState

        return VStack(alignment: .leading, spacing: 16) {
            // Profile/Preset name
            SettingsSection(title: "Profile Name") {
                TextField("", text: $appState.currentPreset.name)
                    .textFieldStyle(.plain)
                    .settingsFieldStyle()
            }

            // Destination folder
            SettingsSection(title: "Folder Name") {
                HStack(spacing: 8) {
                    TextField("", text: $appState.currentPreset.destination)
                        .textFieldStyle(.plain)
                        .font(.system(.callout, design: .monospaced))
                        .settingsFieldStyle()

                    Button("Choose") {
                        chooseFolder()
                    }
                    .controlSize(.small)
                }
            }

            // File name
            SettingsSection(title: "File Name") {
                HStack(spacing: 4) {
                    TextField("Prefix", text: $appState.currentPreset.fileNamePrefix)
                        .textFieldStyle(.plain)
                        .frame(width: 60)
                        .settingsFieldStyle()

                    if appState.currentPreset.useSequenceNumber {
                        Text("Seq# (\(String(format: "%03d", appState.currentPreset.sequenceStartNumber)))")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    }

                    Spacer()

                    Stepper("", value: $appState.currentPreset.sequenceStartNumber, in: 1...9999)
                        .labelsHidden()
                }

                // Example filename
                Text("Example: \(appState.currentPreset.fileNamePrefix)\(String(format: "%03d", appState.currentPreset.sequenceStartNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Unique date tag per file", isOn: $appState.currentPreset.uniqueDateTag)
                    Toggle("Edit each filename", isOn: $appState.currentPreset.editEachFilename)
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .padding(.top, 4)
            }

            // On existing files
            SettingsSection(title: "On Existing Files") {
                Picker("", selection: $appState.currentPreset.existingFileBehavior) {
                    ForEach(ExistingFileBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.rawValue).tag(behavior)
                    }
                }
                .labelsHidden()
            }

            // Format
            SettingsSection(title: "Format") {
                Picker("", selection: $appState.currentPreset.format) {
                    ForEach(ScanFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .labelsHidden()

                if appState.currentPreset.format == .pdf || appState.currentPreset.format == .compressedPDF {
                    Toggle("Searchable PDF (OCR)", isOn: $appState.currentPreset.searchablePDF)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                        .padding(.top, 4)
                }

                // Split on page option
                HStack {
                    Toggle("Split on page", isOn: $appState.currentPreset.splitOnPage)
                        .toggleStyle(.checkbox)
                    if appState.currentPreset.splitOnPage {
                        Stepper(value: $appState.currentPreset.splitPageNumber, in: 1...100) {
                            Text("\(appState.currentPreset.splitPageNumber)")
                                .monospacedDigit()
                        }
                    }
                }
                .controlSize(.small)
                .padding(.top, 4)
            }

            // Quality slider for JPEG and Compressed PDF
            if appState.currentPreset.format == .jpeg || appState.currentPreset.format == .compressedPDF {
                SettingsSection(title: "Quality") {
                    VStack(spacing: 4) {
                        Slider(value: $appState.currentPreset.quality, in: 0.5...1.0, step: 0.05)
                        HStack {
                            Text("least").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(appState.currentPreset.quality * 100))%").font(.caption2).monospacedDigit()
                            Spacer()
                            Text("best").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Workflow options
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Show configuration before scan", isOn: $appState.currentPreset.showConfigBeforeScan)
                Toggle("Scan this profile on document placement", isOn: $appState.currentPreset.scanOnDocumentPlacement)

                HStack {
                    Toggle("Ask for scanning more pages", isOn: $appState.currentPreset.askForMorePages)
                    Spacer()
                    Toggle("Timer:", isOn: $appState.currentPreset.useTimer)
                    if appState.currentPreset.useTimer {
                        TextField("", value: $appState.currentPreset.timerSeconds, format: .number)
                            .textFieldStyle(.plain)
                            .frame(width: 40)
                            .settingsFieldStyle()
                    }
                }

                Toggle("Show progress indicator", isOn: $appState.currentPreset.showProgressIndicator)

                HStack {
                    Toggle("Open with:", isOn: $appState.currentPreset.openWithApp)
                    if appState.currentPreset.openWithApp {
                        Text(URL(fileURLWithPath: appState.currentPreset.openWithAppPath).lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Choose") {
                            chooseApp()
                        }
                        .controlSize(.small)
                    }
                }

                // Print options would go here but require printer integration
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)
        }
    }

    #if os(macOS)
    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose application to open scans with"

        if panel.runModal() == .OK, let url = panel.url {
            appState.currentPreset.openWithAppPath = url.path
        }
    }
    #endif

    // MARK: - Basic Settings Tab

    private var basicSettingsTab: some View {
        @Bindable var appState = appState

        return VStack(alignment: .leading, spacing: 20) {
            // Source - only show sources available on connected scanner
            SettingsSection(title: "Source") {
                Picker("", selection: $appState.currentPreset.source) {
                    ForEach(appState.scannerManager.availableSources, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .labelsHidden()
                .onChange(of: appState.scannerManager.availableSources) { oldSources, newSources in
                    // When sources change (scanner connected), default to flatbed if available
                    // Only do this when we get new sources (connection) not when losing them
                    if oldSources.isEmpty && !newSources.isEmpty {
                        // First connection - always prefer flatbed
                        appState.currentPreset.source = appState.scannerManager.preferredDefaultSource
                        logger.debug("Scanner connected, defaulting to: \(appState.currentPreset.source.rawValue)")
                    } else if !newSources.contains(appState.currentPreset.source) {
                        // Current source no longer available - switch to preferred
                        appState.currentPreset.source = appState.scannerManager.preferredDefaultSource
                        logger.debug("Source unavailable, switching to: \(appState.currentPreset.source.rawValue)")
                    }
                }
            }

            // Colors
            SettingsSection(title: "Colors") {
                Picker("", selection: $appState.currentPreset.colorMode) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Resolution
            SettingsSection(title: "Resolution") {
                HStack {
                    Picker("", selection: $appState.currentPreset.resolution) {
                        Text("75 dpi").tag(75)
                        Text("150 dpi").tag(150)
                        Text("300 dpi").tag(300)
                        Text("600 dpi").tag(600)
                        Text("1200 dpi").tag(1200)
                    }
                    .labelsHidden()

                    Spacer()

                    // Custom resolution stepper
                    Stepper(value: $appState.currentPreset.resolution, in: 50...2400, step: 50) {
                        Text("\(appState.currentPreset.resolution)")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            }

            // Bit Depth
            SettingsSection(title: "Bit Depth") {
                Picker("", selection: $appState.currentPreset.bitDepth) {
                    ForEach(BitDepth.allCases, id: \.self) { depth in
                        Text(depth.displayName).tag(depth)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Size
            SettingsSection(title: "Size") {
                Picker("", selection: $appState.currentPreset.paperSize) {
                    ForEach(ScanPaperSize.allCases, id: \.self) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .labelsHidden()

                // Custom scan area
                Toggle("Custom scan area", isOn: $appState.currentPreset.useCustomScanArea)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .padding(.top, 4)

                if appState.currentPreset.useCustomScanArea {
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("X:")
                                .font(.caption)
                                .frame(width: 18, alignment: .trailing)
                            TextField("", value: $appState.currentPreset.scanAreaX, format: .number.precision(.fractionLength(2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 50, maxWidth: 60)
                            Text("Y:")
                                .font(.caption)
                                .frame(width: 18, alignment: .trailing)
                            TextField("", value: $appState.currentPreset.scanAreaY, format: .number.precision(.fractionLength(2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 50, maxWidth: 60)
                            Picker("", selection: $appState.currentPreset.measurementUnit) {
                                ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .labelsHidden()
                            .frame(minWidth: 70, maxWidth: 90)
                        }
                        HStack(spacing: 4) {
                            Text("W:")
                                .font(.caption)
                                .frame(width: 18, alignment: .trailing)
                            TextField("", value: $appState.currentPreset.scanAreaWidth, format: .number.precision(.fractionLength(2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 50, maxWidth: 60)
                            Text("H:")
                                .font(.caption)
                                .frame(width: 18, alignment: .trailing)
                            TextField("", value: $appState.currentPreset.scanAreaHeight, format: .number.precision(.fractionLength(2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 50, maxWidth: 60)
                            Spacer()
                        }
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
            }

            // Document Type (for film scanners)
            SettingsSection(title: "Document Type") {
                Picker("", selection: $appState.currentPreset.scanDocumentType) {
                    ForEach(ScanDocumentType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
            }

            // Media detection
            SettingsSection(title: "Media Detection") {
                Picker("", selection: $appState.currentPreset.mediaDetection) {
                    ForEach(MediaDetection.allCases, id: \.self) { detection in
                        Text(detection.rawValue).tag(detection)
                    }
                }
                .labelsHidden()
            }

            // Rotation
            SettingsSection(title: "Rotate") {
                Picker("", selection: $appState.currentPreset.rotationAngle) {
                    ForEach(RotationAngle.allCases, id: \.self) { angle in
                        Text(angle.displayName).tag(angle)
                    }
                }
                .labelsHidden()

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Auto rotate", isOn: $appState.currentPreset.autoRotate)
                    if appState.currentPreset.source == .adfDuplex {
                        Toggle("Rotate every second page by 180°", isOn: $appState.currentPreset.rotateEvenPages)
                    }
                    Toggle("De-skew based on page content", isOn: $appState.currentPreset.deskew)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.top, 4)
            }

            // ADF Page Orientation (only for document feeders)
            if appState.currentPreset.source != .flatbed {
                SettingsSection(title: "Page Orientation") {
                    HStack {
                        Text("Odd pages:")
                            .font(.caption)
                        Picker("", selection: $appState.currentPreset.oddPageOrientation) {
                            ForEach(PageOrientation.allCases, id: \.self) { orientation in
                                Text(orientation.displayName).tag(orientation)
                            }
                        }
                        .labelsHidden()
                    }

                    if appState.currentPreset.source == .adfDuplex {
                        HStack {
                            Text("Even pages:")
                                .font(.caption)
                            Picker("", selection: $appState.currentPreset.evenPageOrientation) {
                                ForEach(PageOrientation.allCases, id: \.self) { orientation in
                                    Text(orientation.displayName).tag(orientation)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    Toggle("Reverse feeder page order", isOn: $appState.currentPreset.reverseFeederPageOrder)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                        .padding(.top, 4)
                }
            }

            // Blank page detection (moved from Filing to Basic like ExactScan)
            SettingsSection(title: "Blank Page Detection") {
                Picker("", selection: $appState.currentPreset.blankPageHandling) {
                    ForEach(BlankPageHandling.allCases, id: \.self) { handling in
                        Text(handling == .delete ? "Delete blank page" : handling.rawValue).tag(handling)
                    }
                }
                .labelsHidden()

                if appState.currentPreset.blankPageHandling != .keep {
                    VStack(spacing: 4) {
                        Text("Sensitivity")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Slider(value: $appState.currentPreset.blankPageSensitivity, in: 0...1, step: 0.1)
                        HStack {
                            Text("high").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("low").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Advanced Settings Tab

    private var advancedSettingsTab: some View {
        @Bindable var appState = appState

        return VStack(alignment: .leading, spacing: 20) {
            // Image processing
            SettingsSection(title: "Processing") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("De-screen (reduce moiré)", isOn: $appState.currentPreset.descreen)
                    Toggle("Sharpen", isOn: $appState.currentPreset.sharpen)
                    Toggle("Invert image", isOn: $appState.currentPreset.invertColors)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            // B&W Threshold (only for B&W mode)
            if appState.currentPreset.colorMode == .blackWhite {
                SettingsSection(title: "B&W Threshold") {
                    VStack(spacing: 4) {
                        Slider(value: Binding(
                            get: { Double(appState.currentPreset.bwThreshold) },
                            set: { appState.currentPreset.bwThreshold = Int($0) }
                        ), in: 0...255, step: 1)
                        HStack {
                            Text("0").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(appState.currentPreset.bwThreshold)").font(.caption2).monospacedDigit()
                            Spacer()
                            Text("255").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Photo enhancements
            if appState.currentPreset.documentType == .photo {
                SettingsSection(title: "Photo Enhancement") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Restore faded colors", isOn: $appState.currentPreset.restoreColor)
                        Toggle("Remove red-eye", isOn: $appState.currentPreset.removeRedEye)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }

            // Brightness
            SettingsSection(title: "Brightness") {
                VStack(spacing: 4) {
                    Slider(value: $appState.currentPreset.brightness, in: -1...1, step: 0.1)
                    HStack {
                        Text("-1").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(appState.currentPreset.brightness, specifier: "%.1f")").font(.caption2).monospacedDigit()
                        Spacer()
                        Text("+1").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            // Contrast
            SettingsSection(title: "Contrast") {
                VStack(spacing: 4) {
                    Slider(value: $appState.currentPreset.contrast, in: -1...1, step: 0.1)
                    HStack {
                        Text("-1").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(appState.currentPreset.contrast, specifier: "%.1f")").font(.caption2).monospacedDigit()
                        Spacer()
                        Text("+1").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            // Gamma
            SettingsSection(title: "Gamma") {
                VStack(spacing: 4) {
                    Slider(value: $appState.currentPreset.gamma, in: 0.5...3.0, step: 0.1)
                    HStack {
                        Text("0.5").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(appState.currentPreset.gamma, specifier: "%.1f")").font(.caption2).monospacedDigit()
                        Spacer()
                        Text("3.0").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            // Color adjustments (only for color mode)
            if appState.currentPreset.colorMode == .color {
                // Hue
                SettingsSection(title: "Hue") {
                    VStack(spacing: 4) {
                        Slider(value: $appState.currentPreset.hue, in: -1...1, step: 0.1)
                        HStack {
                            Text("-1").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(appState.currentPreset.hue, specifier: "%.1f")").font(.caption2).monospacedDigit()
                            Spacer()
                            Text("+1").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }

                // Saturation
                SettingsSection(title: "Saturation") {
                    VStack(spacing: 4) {
                        Slider(value: $appState.currentPreset.saturation, in: -1...1, step: 0.1)
                        HStack {
                            Text("-1").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(appState.currentPreset.saturation, specifier: "%.1f")").font(.caption2).monospacedDigit()
                            Spacer()
                            Text("+1").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }

                // Lightness
                SettingsSection(title: "Lightness") {
                    VStack(spacing: 4) {
                        Slider(value: $appState.currentPreset.lightness, in: -1...1, step: 0.1)
                        HStack {
                            Text("-1").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(appState.currentPreset.lightness, specifier: "%.1f")").font(.caption2).monospacedDigit()
                            Spacer()
                            Text("+1").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Multi-page options
            if appState.currentPreset.source != .flatbed {
                SettingsSection(title: "Multi-page") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Split in half for book pages", isOn: $appState.currentPreset.splitBookPages)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
        }
    }

    #if os(macOS)
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose scan destination folder"

        if panel.runModal() == .OK, let url = panel.url {
            appState.currentPreset.destination = url.path
        }
    }
    #endif
}

// MARK: - Helper Views

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }
}

extension View {
    @ViewBuilder
    func settingsFieldStyle() -> some View {
        if #available(macOS 26.0, *) {
            self
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .rect(cornerRadius: 6))
        } else {
            self
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

#Preview {
    ControlPanelView()
        .environment(AppState())
        .frame(width: 320, height: 700)
}
