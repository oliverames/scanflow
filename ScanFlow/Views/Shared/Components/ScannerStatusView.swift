//
//  ScannerStatusView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.scanflow.app", category: "ScannerStatusView")

struct ScannerStatusView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        #if os(macOS)
        Button {
            appState.showScannerSelection = true
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .overlay {
                        if appState.scannerManager.connectionState == .scanning {
                            Circle()
                                .fill(statusColor.opacity(0.3))
                                .frame(width: 16, height: 16)
                                .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                                .animation(
                                    reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(),
                                    value: pulseAnimation
                                )
                        }
                    }

                VStack(alignment: .leading, spacing: 0) {
                    if let scanner = appState.scannerManager.selectedScanner {
                        Text(scanner.name ?? "Unknown Scanner")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    } else if appState.useMockScanner && appState.scannerManager.connectionState.isConnected {
                        Text("Mock Scanner")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    } else {
                        Text("No Scanner")
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    Text(statusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .modifier(GlassBadgeStyle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onAppear {
            pulseAnimation = !reduceMotion
        }
        .accessibilityLabel("Scanner Status")
        .accessibilityValue(statusText)
        .accessibilityHint("Opens scanner selection")
        #else
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(iOSGlassBackground)
        .accessibilityLabel("Scanner Status")
        .accessibilityValue(statusText)
        #endif
    }

    @State private var pulseAnimation = false

    private var statusColor: Color {
        switch appState.scannerManager.connectionState {
        case .connected, .scanning:
            return .green
        case .connecting, .discovering:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }

    private var statusText: String {
        appState.scannerManager.connectionState.description
    }

    #if os(iOS)
    @ViewBuilder
    private var iOSGlassBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .glassEffect(.regular, in: .rect(cornerRadius: 999))
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }
    #endif
}

private struct GlassBadgeStyle: ViewModifier {
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
