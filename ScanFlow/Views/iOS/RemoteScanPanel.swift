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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Remote Scanner", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)

                Spacer()

                Button("Refresh") {
                    appState.remoteScanClient.startBrowsing()
                }
                .controlSize(.small)
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

                HStack {
                    Button(appState.remoteScanClient.connectionState == .connected ? "Disconnect" : "Connect") {
                        handleConnectionToggle()
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedServiceID == nil && appState.remoteScanClient.connectionState != .connected)

                    Spacer()

                    Button("Scan on Mac") {
                        appState.remoteScanClient.requestScan(
                            presetName: appState.currentPreset.name,
                            searchablePDF: appState.currentPreset.searchablePDF
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.remoteScanClient.connectionState != .connected || appState.remoteScanClient.isScanning)
                }
            }

            if let status = appState.remoteScanClient.statusMessage {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
}

#Preview {
    RemoteScanPanel()
        .environment(AppState())
        .padding()
}
#endif
