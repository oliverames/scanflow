//
//  PreviewView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.scanflow.app", category: "PreviewView")

struct PreviewView: View {
    @Environment(AppState.self) private var appState
    @State private var previewImage: Image?
    @State private var isLoadingPreview = false

    var body: some View {
        VStack(spacing: 0) {
            // Preview Header
            HStack {
                Text("Preview")
                    .font(.headline)

                Spacer()

                if isLoadingPreview {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Button {
                    Task {
                        await loadPreview()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled((!appState.scannerManager.connectionState.isConnected && !appState.useMockScanner) || isLoadingPreview)
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
                        .modifier(GlassPanelStyle(cornerRadius: 12))
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
            .modifier(GlassPanelStyle(cornerRadius: 16))
        }
        .onAppear {
            logger.info("PreviewView appeared")
        }
    }

    private func loadPreview() async {
        logger.info("Loading preview scan...")
        isLoadingPreview = true
        defer { isLoadingPreview = false }

        #if os(macOS)
        do {
            let nsImage = try await appState.scannerManager.requestOverviewScan()
            previewImage = Image(nsImage: nsImage)
            logger.info("Preview loaded successfully")
        } catch {
            logger.error("Failed to load preview: \(error.localizedDescription)")
            appState.showAlert(message: "Failed to load preview: \(error.localizedDescription)")
        }
        #endif
    }
}

private struct GlassPanelStyle: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

