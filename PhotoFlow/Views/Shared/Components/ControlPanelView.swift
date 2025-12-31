//
//  ControlPanelView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI

struct ControlPanelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                // Scanner Info
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("Scanner")
                            .font(.headline)
                    } icon: {
                        Image(systemName: "scanner")
                    }

                    HStack {
                        Text(appState.scannerManager.mockScannerName)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Circle()
                            .fill(appState.scannerManager.connectionState.isConnected ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(appState.scannerManager.connectionState.isConnected ? "Ready" : "Not Connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading)

                    if !appState.scannerManager.connectionState.isConnected && !appState.useMockScanner {
                        Button {
                            Task {
                                await appState.scannerManager.discoverScanners()
                            }
                        } label: {
                            Label("Connect Scanner", systemImage: "link")
                        }
                        .buttonStyle(.bordered)
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
                        if appState.scannerManager.connectionState.isConnected || appState.useMockScanner {
                            await appState.startScanning()
                        } else {
                            await appState.scannerManager.connectMockScanner()
                        }
                    }
                } label: {
                    Label(
                        appState.isScanning ? "Scanning..." : "Scan Photos",
                        systemImage: appState.isScanning ? "stop.circle.fill" : "play.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appState.isScanning)
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
