//
//  ScannerSelectionView.swift
//  ScanFlow
//
//  Scanner selection view shown on app launch.
//  Continuously discovers available scanners (wired and wireless) using ImageCaptureCore.
//

#if os(macOS)
import SwiftUI
import ImageCaptureCore
import os.log

private let logger = Logger(subsystem: "com.scanflow.app", category: "ScannerSelectionView")

struct ScannerSelectionView: View {
    @Environment(AppState.self) private var appState
    @Binding var hasSelectedScanner: Bool

    @State private var isRefreshing = false
    @State private var autoRefreshTask: Task<Void, Never>?
    @State private var lastRefreshTime: Date = Date()

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 16) {
                headerView

                if appState.scannerManager.availableScanners.isEmpty {
                    emptyStateView
                } else {
                    scannerListView
                }

                footerView
            }
            .padding(16)
        }
        .frame(minWidth: 360, idealWidth: 460, minHeight: 320, idealHeight: 420)
        .onAppear {
            logger.info("ScannerSelectionView appeared, starting scanner discovery")
            startAutoRefresh()
        }
        .onDisappear {
            logger.info("ScannerSelectionView disappeared, stopping auto-refresh")
            stopAutoRefresh()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "scanner.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No Scanners Found")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Make sure your scanner is on and connected")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appState.scannerManager.connectionState == .discovering {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Search Again") {
                    refreshScanners()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .modifier(GlassCardModifier(cornerRadius: 18))
    }

    private func connectToScanner(_ scanner: ICScannerDevice) {
        logger.info("User selected scanner: \(scanner.name ?? "Unknown")")
        Task {
            do {
                try await appState.scannerManager.connect(to: scanner)
                logger.info("Successfully connected to scanner")
                hasSelectedScanner = true
            } catch {
                logger.error("Failed to connect to scanner: \(error.localizedDescription)")
                appState.showAlert(message: "Failed to connect: \(error.localizedDescription)")
            }
        }
    }

    private func refreshScanners() {
        logger.info("Manual refresh triggered")
        isRefreshing = true
        Task {
            await appState.scannerManager.discoverScanners()
            isRefreshing = false
            lastRefreshTime = Date()
        }
    }

    private func startAutoRefresh() {
        // Start continuous browsing - the device browser will call delegates as devices appear/disappear
        // The delegate callbacks (didAdd/didRemove) maintain the availableScanners list automatically
        appState.scannerManager.startBrowsing()

        // Do one initial discovery call to populate the list
        // After this, the device browser delegates will keep it updated
        Task {
            await appState.scannerManager.discoverScanners()
        }

        // We don't need to call discoverScanners repeatedly - the device browser
        // delegates handle adding/removing scanners as they appear/disappear.
        // Just update the lastRefreshTime for UI feedback
        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if !Task.isCancelled {
                    logger.debug("Auto-refresh: updating timestamp")
                    lastRefreshTime = Date()
                }
            }
        }
    }

    private func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        // Don't stop browsing - keep discovering in background
    }
}

struct ScannerRowView: View {
    let scanner: ICScannerDevice
    let isSelected: Bool
    let isConnecting: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Scanner icon - compact
                Image(systemName: scannerIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    )

                // Scanner info
                VStack(alignment: .leading, spacing: 2) {
                    Text(scanner.name ?? "Unknown Scanner")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(connectionType)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status indicator
                if isConnecting && isSelected {
                    ProgressView()
                        .controlSize(.small)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .modifier(ScannerRowStyle(isSelected: isSelected))
    }

    private var scannerIcon: String {
        if scanner.usbLocationID != 0 {
            return "scanner.fill"
        } else {
            return "wifi"
        }
    }

    private var connectionType: String {
        if scanner.usbLocationID != 0 {
            return "USB"
        } else {
            return "Network"
        }
    }

    private var connectionIcon: String {
        if scanner.usbLocationID != 0 {
            return "cable.connector"
        } else {
            return "wifi"
        }
    }
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 16.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
                )
        }
    }
}

private struct ScannerRowStyle: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(macOS 16.0, *) {
            content
                .glassEffect(
                    isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(),
                    in: .rect(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 1)
                )
        }
    }
}

private extension ScannerSelectionView {
    var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "scanner")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Select a Scanner")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Available scanners are discovered automatically")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Updated \(lastRefreshTime, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isRefreshing || appState.scannerManager.connectionState == .discovering {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    refreshScanners()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .modifier(GlassCardModifier(cornerRadius: 18))
    }

    var scannerListView: some View {
        ScrollView {
            if #available(macOS 16.0, *) {
                GlassEffectContainer(spacing: 14) {
                    LazyVStack(spacing: 12) {
                        scannerRows
                    }
                    .padding(2)
                }
            } else {
                LazyVStack(spacing: 12) {
                    scannerRows
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    var scannerRows: some View {
        ForEach(appState.scannerManager.availableScanners, id: \.self) { scanner in
            ScannerRowView(
                scanner: scanner,
                isSelected: scanner == appState.scannerManager.selectedScanner,
                isConnecting: appState.scannerManager.connectionState == .connecting
            ) {
                connectToScanner(scanner)
            }
        }
    }

    var footerView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.scannerManager.availableScanners.isEmpty ? .orange : .green)
                .frame(width: 6, height: 6)

            Text("\(appState.scannerManager.availableScanners.count) scanner\(appState.scannerManager.availableScanners.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if appState.useMockScanner {
                Button {
                    logger.info("Using mock scanner for testing")
                    Task {
                        await appState.scannerManager.connectMockScanner()
                        hasSelectedScanner = true
                    }
                } label: {
                    Label("Mock Scanner", systemImage: "ladybug")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .modifier(GlassCardModifier(cornerRadius: 16))
    }

    var backgroundView: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(0.6),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    ScannerSelectionView(hasSelectedScanner: .constant(false))
        .environment(AppState())
        .frame(width: 600, height: 500)
}
#endif
