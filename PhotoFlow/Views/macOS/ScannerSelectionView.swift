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
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "scanner")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Select a Scanner")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Choose a scanner to begin. Available scanners are discovered automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)

            Divider()

            // Scanner list
            ScrollView {
                LazyVStack(spacing: 12) {
                    if appState.scannerManager.availableScanners.isEmpty {
                        emptyStateView
                    } else {
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
                }
                .padding()
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Footer with status and controls
            HStack {
                // Status indicator
                HStack(spacing: 8) {
                    if isRefreshing || appState.scannerManager.connectionState == .discovering {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Searching for scanners...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Circle()
                            .fill(appState.scannerManager.availableScanners.isEmpty ? .orange : .green)
                            .frame(width: 8, height: 8)
                        Text("\(appState.scannerManager.availableScanners.count) scanner\(appState.scannerManager.availableScanners.count == 1 ? "" : "s") found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Refresh button
                Button {
                    refreshScanners()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing || appState.scannerManager.connectionState == .discovering)

                // Use Mock Scanner button (for testing)
                if appState.useMockScanner {
                    Button {
                        logger.info("Using mock scanner for testing")
                        Task {
                            await appState.scannerManager.connectMockScanner()
                            hasSelectedScanner = true
                        }
                    } label: {
                        Label("Use Mock Scanner", systemImage: "ladybug")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.bar)
        }
        .frame(minWidth: 500, minHeight: 400)
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
        VStack(spacing: 16) {
            Image(systemName: "scanner.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("No Scanners Found")
                .font(.headline)

            Text("Make sure your scanner is powered on and connected.\nWireless scanners should be on the same network.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if appState.scannerManager.connectionState == .discovering {
                ProgressView()
                    .padding(.top, 8)
            } else {
                Button {
                    refreshScanners()
                } label: {
                    Label("Search Again", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .padding(40)
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
        appState.scannerManager.startBrowsing()

        // Also do an initial discovery call
        Task {
            await appState.scannerManager.discoverScanners()
        }

        // Periodic state refresh (device browser stays running, this just updates UI state)
        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                if !Task.isCancelled {
                    logger.debug("Auto-refresh: checking for scanners")
                    // Just trigger a state update, browser is already running
                    await appState.scannerManager.discoverScanners()
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
            HStack(spacing: 16) {
                // Scanner icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: 56, height: 56)

                    Image(systemName: scannerIcon)
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }

                // Scanner info
                VStack(alignment: .leading, spacing: 4) {
                    Text(scanner.name ?? "Unknown Scanner")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        // Connection type indicator
                        Label(connectionType, systemImage: connectionIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let location = scanner.uuidString {
                            Text(String(location.prefix(8)))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Status indicator
                if isConnecting && isSelected {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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

#Preview {
    ScannerSelectionView(hasSelectedScanner: .constant(false))
        .environment(AppState())
        .frame(width: 600, height: 500)
}
#endif
