//
//  ControlPanelView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI
#if os(macOS)
import ImageCaptureCore
#endif

struct ControlPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var showingScannerSheet = false

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // Scanner Info
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Scanner")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "scanner")
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                #if os(macOS)
                                if let scanner = appState.scannerManager.selectedScanner {
                                    Text(scanner.name ?? "Unknown Scanner")
                                        .font(.subheadline)
                                } else {
                                    Text("No scanner selected")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                #endif
                                Text(appState.scannerManager.connectionState.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Circle()
                                .fill(appState.scannerManager.connectionState.isConnected ? .green : .gray)
                                .frame(width: 8, height: 8)
                        }

                        #if os(macOS)
                        // Available scanners list
                        if !appState.scannerManager.availableScanners.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Available Scanners:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(appState.scannerManager.availableScanners, id: \.self) { scanner in
                                    Button {
                                        Task {
                                            try? await appState.scannerManager.connect(to: scanner)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "scanner")
                                            Text(scanner.name ?? "Unknown")
                                                .lineLimit(1)
                                            Spacer()
                                            if scanner == appState.scannerManager.selectedScanner {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading)
                        }
                        #endif

                        HStack {
                            Button {
                                Task {
                                    await appState.scannerManager.discoverScanners()
                                }
                            } label: {
                                Label(
                                    appState.scannerManager.connectionState == .discovering ? "Searching..." : "Find Scanners",
                                    systemImage: "magnifyingglass"
                                )
                            }
                            .buttonStyle(.bordered)
                            .disabled(appState.scannerManager.connectionState == .discovering)

                            if appState.scannerManager.connectionState.isConnected {
                                Button {
                                    Task {
                                        await appState.scannerManager.disconnect()
                                    }
                                } label: {
                                    Label("Disconnect", systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                Divider()

                // Current Preset
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Preset")
                        .font(.headline)

                    Menu {
                        ForEach(appState.presets) { preset in
                            Button(preset.name) {
                                appState.currentPreset = preset
                            }
                        }
                    } label: {
                        HStack {
                            Text(appState.currentPreset.name)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // Scan Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scan Settings")
                        .font(.headline)

                    // Document Type
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Document Type")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("", selection: $appState.currentPreset.documentType) {
                            ForEach(DocumentType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Resolution
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Resolution")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(appState.currentPreset.resolution) DPI")
                                .font(.subheadline)
                                .monospacedDigit()
                        }

                        Slider(
                            value: Binding(
                                get: { Double(appState.currentPreset.resolution) },
                                set: { appState.currentPreset.resolution = Int($0) }
                            ),
                            in: 300...1200,
                            step: 300
                        )
                    }

                    // Format
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Format")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Picker("", selection: $appState.currentPreset.format) {
                                ForEach(ScanFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .labelsHidden()

                            if appState.currentPreset.format == .jpeg {
                                Text("Quality:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(appState.currentPreset.quality * 100))%")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }
                }

                Divider()

                // Auto-Enhancement
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-Enhancement")
                        .font(.headline)

                    Toggle("Restore Faded Colors", isOn: $appState.currentPreset.restoreColor)
                    Toggle("Remove Red-Eye", isOn: $appState.currentPreset.removeRedEye)
                    Toggle("Auto Rotate", isOn: $appState.currentPreset.autoRotate)
                    Toggle("Deskew", isOn: $appState.currentPreset.deskew)
                }
                .toggleStyle(.switch)

                Divider()

                // Destination
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("Destination")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "folder")
                    }

                    TextField("", text: $appState.currentPreset.destination)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                // Scan Button
                Button {
                    Task {
                        appState.addToQueue(preset: appState.currentPreset, count: 1)
                        await appState.startScanning()
                    }
                } label: {
                    Label(
                        appState.isScanning ? "Scanning..." : "Scan",
                        systemImage: appState.isScanning ? "stop.circle.fill" : "play.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appState.isScanning || (!appState.scannerManager.connectionState.isConnected && !appState.useMockScanner))
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ControlPanelView()
        .environment(AppState())
        .frame(width: 320, height: 800)
}
