//
//  PreviewView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI

struct PreviewView: View {
    @Environment(AppState.self) private var appState
    @State private var previewImage: Image?

    var body: some View {
        VStack(spacing: 0) {
            // Preview Header
            HStack {
                Text("Preview")
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        await loadPreview()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(!appState.scannerManager.connectionState.isConnected && !appState.useMockScanner)
            }
            .padding()

            Divider()

            // Preview Image Area
            ZStack {
                if let previewImage {
                    previewImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                        .background(.ultraThinMaterial)
                } else {
                    ContentUnavailableView {
                        Label("No Preview", systemImage: "viewfinder")
                    } description: {
                        if appState.scannerManager.connectionState.isConnected || appState.useMockScanner {
                            Text("Click refresh to load preview")
                        } else {
                            Text("Connect to scanner first")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
    }

    private func loadPreview() async {
        #if os(macOS)
        do {
            let nsImage = try await appState.scannerManager.requestOverviewScan()
            previewImage = Image(nsImage: nsImage)
        } catch {
            appState.showAlert(message: "Failed to load preview: \(error.localizedDescription)")
        }
        #endif
    }
}

#Preview {
    PreviewView()
        .environment(AppState())
        .frame(width: 500, height: 600)
}
