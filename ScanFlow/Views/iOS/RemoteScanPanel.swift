//
//  RemoteScanPanel.swift
//  ScanFlow
//
//  iOS UI for connecting to remote ScanFlow servers.
//

#if os(iOS)
import SwiftUI

struct RemoteScanPanel: View {
    @Environment(AppState.self) private var appState
    @State private var selectedServiceID: RemoteScanClient.RemoteScanService.ID?
    @State private var splitDocuments = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Remote Scanner", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)

                Spacer()

                Text(connectionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Refresh") {
                    appState.remoteScanClient.startBrowsing()
                }
                .controlSize(.small)
                .accessibilityLabel("Refresh Remote Scanner List")
            }

            if appState.remoteScanClient.availableServices.isEmpty {
                Text("No Mac scanners found on your network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Available Macs", selection: $selectedServiceID) {
                    ForEach(appState.remoteScanClient.availableServices) { service in
                        Text(service.name).tag(Optional(service.id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Available Mac Scanners")

                Toggle("Split documents", isOn: $splitDocuments)
                    .font(.caption)
                    .accessibilityHint("When enabled, document separation settings are applied on Mac")

                TextField("Pairing token (if required)", text: Binding(
                    get: { appState.remoteScanClientPairingToken },
                    set: { appState.remoteScanClientPairingToken = $0 }
                ))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.caption)
                .accessibilityLabel("Pairing Token")
                .accessibilityHint("Enter the token from ScanFlow on Mac")

                HStack {
                    Button(appState.remoteScanClient.connectionState == .connected ? "Disconnect" : "Connect") {
                        handleConnectionToggle()
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedServiceID == nil && appState.remoteScanClient.connectionState != .connected)
                    .accessibilityLabel(appState.remoteScanClient.connectionState == .connected ? "Disconnect from Mac Scanner" : "Connect to Mac Scanner")

                    Spacer()

                    Button("Scan on Mac") {
                        appState.remoteScanClient.requestScan(
                            presetName: appState.currentPreset.name,
                            searchablePDF: appState.currentPreset.searchablePDF,
                            forceSingleDocument: !splitDocuments,
                            pairingToken: appState.remoteScanClientPairingToken
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.remoteScanClient.connectionState != .connected || appState.remoteScanClient.isScanning)
                    .accessibilityLabel("Start Remote Scan")
                    .accessibilityHint("Triggers a scan on the connected Mac")
                }
            }

            if let status = appState.remoteScanClient.statusMessage {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if appState.remoteScanClient.isScanning || appState.remoteScanClient.bytesReceived > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    if let expected = appState.remoteScanClient.expectedBytes, expected > 0 {
                        ProgressView(value: Double(transferReceived), total: Double(expected))
                        Text("Received \(formattedBytes(transferReceived)) of \(formattedBytes(expected))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Received \(formattedBytes(appState.remoteScanClient.bytesReceived))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = appState.remoteScanClient.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(remoteGlassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            if let selected = appState.remoteScanClient.selectedService {
                selectedServiceID = selected.id
            }
        }
        .onChange(of: appState.remoteScanClient.availableServices) { _, newServices in
            if selectedServiceID == nil, let first = newServices.first {
                selectedServiceID = first.id
            }
        }
    }

    private var remoteGlassBackground: some View {
        Group {
            if #available(iOS 26.0, *) {
                Rectangle()
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }

    private func handleConnectionToggle() {
        if appState.remoteScanClient.connectionState == .connected {
            appState.remoteScanClient.disconnect()
            return
        }

        guard let selectedID = selectedServiceID,
              let service = appState.remoteScanClient.availableServices.first(where: { $0.id == selectedID }) else {
            return
        }
        appState.remoteScanClient.connect(to: service)
    }

    private var transferReceived: Int {
        if let expected = appState.remoteScanClient.expectedBytes {
            return min(appState.remoteScanClient.bytesReceived, expected)
        }
        return appState.remoteScanClient.bytesReceived
    }

    private func formattedBytes(_ value: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }

    private var connectionLabel: String {
        switch appState.remoteScanClient.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting…"
        case .browsing:
            return "Browsing…"
        case .disconnected:
            return "Disconnected"
        }
    }
}

#endif
