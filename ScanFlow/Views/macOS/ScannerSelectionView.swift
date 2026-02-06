//
//  ScannerSelectionView.swift
//  ScanFlow
//
//  Scanner selection view shown on app launch.
//  Continuously discovers available scanners (wired and wireless) using ImageCaptureCore.
//  Updated for Liquid Glass design system (macOS 26+).
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
    @State private var hoveredScanner: ICScannerDevice?
    @Namespace private var scannerNamespace

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 20) {
                headerView

                if appState.scannerManager.availableScanners.isEmpty {
                    emptyStateView
                } else {
                    scannerListView
                }

                footerView
            }
            .padding(20)
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 360, idealHeight: 480)
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
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "scanner.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("No Scanners Found")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Make sure your scanner is powered on and connected via USB or network")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            if appState.scannerManager.connectionState == .discovering {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                if #available(macOS 26.0, *) {
                    Button("Search Again") {
                        refreshScanners()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.regular)
                } else {
                    Button("Search Again") {
                        refreshScanners()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .modifier(GlassCardModifier(cornerRadius: 20))
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
    let isHovered: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Scanner icon with connection type indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconBackgroundColor)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: scannerIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white : .primary)
                }
                .overlay(alignment: .bottomTrailing) {
                    // Connection type badge
                    Image(systemName: connectionBadgeIcon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(connectionBadgeColor, in: Circle())
                        .offset(x: 4, y: 4)
                }

                // Scanner info
                VStack(alignment: .leading, spacing: 3) {
                    Text(scanner.name ?? "Unknown Scanner")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: connectionIcon)
                            .font(.system(size: 10))
                        Text(connectionType)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Status indicator
                if isConnecting && isSelected {
                    ProgressView()
                        .controlSize(.small)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                        .symbolEffect(.pulse)
                } else if isHovered {
                    Text("Connect")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(ScannerRowStyle(isSelected: isSelected, isHovered: isHovered))
    }

    private var iconBackgroundColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovered {
            return Color.secondary.opacity(0.15)
        } else {
            return Color.secondary.opacity(0.08)
        }
    }

    private var scannerIcon: String {
        "scanner.fill"
    }

    private var connectionType: String {
        if scanner.usbLocationID != 0 {
            return "USB Connected"
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

    private var connectionBadgeIcon: String {
        if scanner.usbLocationID != 0 {
            return "link"
        } else {
            return "antenna.radiowaves.left.and.right"
        }
    }

    private var connectionBadgeColor: Color {
        if scanner.usbLocationID != 0 {
            return .blue
        } else {
            return .green
        }
    }
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
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
    let isHovered: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(
                    glassVariant,
                    in: .rect(cornerRadius: 14)
                )
                .shadow(color: isSelected ? Color.accentColor.opacity(0.2) : .clear, radius: 8, y: 2)
                .scaleEffect(isHovered && !isSelected ? 1.01 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: isSelected ? Color.accentColor.opacity(0.15) : .clear, radius: 6, y: 2)
                .scaleEffect(isHovered && !isSelected ? 1.01 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
    }

    @available(macOS 26.0, *)
    private var glassVariant: Glass {
        if isSelected {
            return .regular.tint(.accentColor).interactive()
        } else if isHovered {
            return .regular.interactive()
        } else {
            return .regular
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovered {
            return Color(nsColor: .controlBackgroundColor).opacity(0.8)
        } else {
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.8)
        } else if isHovered {
            return Color.secondary.opacity(0.3)
        } else {
            return Color.clear
        }
    }
}

private extension ScannerSelectionView {
    var headerView: some View {
        HStack(spacing: 14) {
            // Scanner icon with animated ring when discovering
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                if appState.scannerManager.connectionState == .discovering {
                    Circle()
                        .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .scaleEffect(isRefreshing ? 1.2 : 1.0)
                        .opacity(isRefreshing ? 0 : 1)
                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isRefreshing)
                }
                
                Image(systemName: "scanner")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Select a Scanner")
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 6) {
                    if appState.scannerManager.connectionState == .discovering {
                        Text("Discovering scanners...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Last updated")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(lastRefreshTime, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Refresh scanner list")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .modifier(GlassCardModifier(cornerRadius: 20))
    }

    var scannerListView: some View {
        ScrollView {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 16) {
                    LazyVStack(spacing: 10) {
                        scannerRows
                    }
                    .padding(4)
                }
            } else {
                LazyVStack(spacing: 10) {
                    scannerRows
                }
            }
        }
        .scrollIndicators(.automatic)
    }

    var scannerRows: some View {
        ForEach(appState.scannerManager.availableScanners, id: \.self) { scanner in
            ScannerRowView(
                scanner: scanner,
                isSelected: scanner == appState.scannerManager.selectedScanner,
                isConnecting: appState.scannerManager.connectionState == .connecting,
                isHovered: hoveredScanner == scanner
            ) {
                connectToScanner(scanner)
            }
            .onHover { isHovered in
                hoveredScanner = isHovered ? scanner : nil
            }
        }
    }

    var footerView: some View {
        HStack(spacing: 10) {
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.5), radius: 3)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if appState.useMockScanner {
                if #available(macOS 26.0, *) {
                    Button {
                        logger.info("Using mock scanner for testing")
                        Task {
                            await appState.scannerManager.connectMockScanner()
                            hasSelectedScanner = true
                        }
                    } label: {
                        Label("Mock Scanner", systemImage: "ladybug")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                } else {
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .modifier(GlassCardModifier(cornerRadius: 18))
    }

    private var statusColor: Color {
        if appState.scannerManager.connectionState == .discovering {
            return .blue
        } else if appState.scannerManager.availableScanners.isEmpty {
            return .orange
        } else if appState.scannerManager.connectionState.isConnected {
            return .green
        } else {
            return .green
        }
    }

    private var statusText: String {
        let count = appState.scannerManager.availableScanners.count
        if appState.scannerManager.connectionState == .discovering {
            return "Searching..."
        } else if count == 0 {
            return "No scanners found"
        } else if count == 1 {
            return "1 scanner available"
        } else {
            return "\(count) scanners available"
        }
    }

    var backgroundView: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.4),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle accent color wash
            RadialGradient(
                colors: [
                    Color.accentColor.opacity(0.03),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ScannerSelectionView(hasSelectedScanner: .constant(false))
        .environment(AppState())
        .frame(width: 600, height: 500)
}
#endif
