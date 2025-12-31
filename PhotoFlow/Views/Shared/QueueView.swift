//
//  QueueView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI

struct QueueView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Scan Queue")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    appState.addToQueue(preset: appState.currentPreset, count: 1)
                } label: {
                    Label("Add to Queue", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button {
                    Task {
                        await appState.startScanning()
                    }
                } label: {
                    Label("Start Scanning", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.scanQueue.isEmpty || appState.isScanning)
            }
            .padding()

            Divider()

            // Queue List
            if appState.scanQueue.isEmpty {
                ContentUnavailableView {
                    Label("No Scans Queued", systemImage: "tray")
                } description: {
                    Text("Add scans to the queue to begin batch scanning")
                }
            } else {
                List {
                    ForEach(appState.scanQueue) { scan in
                        QueueItemRow(scan: scan)
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            appState.removeFromQueue(scan: appState.scanQueue[index])
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct QueueItemRow: View {
    let scan: QueuedScan

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.title3)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(scan.name)
                    .font(.headline)

                HStack {
                    Text("\(scan.preset.resolution) DPI")
                    Text("•")
                    Text(scan.preset.format.rawValue)
                    Text("•")
                    Text(scan.status.description)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if case .scanning = scan.status {
                ProgressView(value: scan.progress)
                    .frame(width: 100)
            }
        }
        .padding(.vertical, 8)
    }

    private var statusIcon: String {
        switch scan.status {
        case .pending: return "circle"
        case .scanning: return "arrow.down.circle.fill"
        case .processing: return "gearshape.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch scan.status {
        case .pending: return .secondary
        case .scanning: return .blue
        case .processing: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    QueueView()
        .environment(AppState())
        .frame(width: 700, height: 500)
}
