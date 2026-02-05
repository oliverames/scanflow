//
//  MainWindow.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

#if os(macOS)
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.scanflow.app", category: "MainWindow")

struct MainWindow: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        mainContentView
            .frame(minWidth: 780, minHeight: 600)
            .sheet(isPresented: $appState.showScannerSelection) {
                ScannerSelectionView(hasSelectedScanner: .init(
                    get: { !appState.showScannerSelection },
                    set: { if $0 { appState.showScannerSelection = false } }
                ))
                .frame(minWidth: 380, idealWidth: 450, minHeight: 320, idealHeight: 400)
                .interactiveDismissDisabled(!appState.scannerManager.connectionState.isConnected && !appState.useMockScanner)
            }
            .alert("Error", isPresented: $appState.showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(appState.alertMessage)
            }
            .onChange(of: appState.scannerManager.connectionState) { oldState, newState in
                logger.info("Connection state changed: \(oldState.description) -> \(newState.description)")
                // If we connect, dismiss the sheet
                if newState.isConnected && !oldState.isConnected {
                    logger.info("Scanner connected, dismissing selection view")
                    appState.markScannerUsed()
                    appState.showScannerSelection = false
                }
                // If we disconnect, show the sheet
                if case .disconnected = newState, oldState.isConnected {
                    logger.info("Scanner disconnected, showing selection view")
                    appState.showScannerSelection = true
                }
            }
            .onAppear {
                appState.exitBackgroundMode()
                // Show sheet if not connected
                if !appState.scannerManager.connectionState.isConnected && !appState.useMockScanner {
                    appState.showScannerSelection = true
                }
            }
    }

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var mainContentView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            DetailView()
                .navigationSplitViewColumnWidth(min: 700, ideal: 900)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            logger.info("Main content view appeared")
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                ScannerStatusView()

                Spacer()

                // Toggle scan settings panel
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.showScanSettings.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help("Toggle Scan Settings")

                // Change Scanner button - shows the scanner selection sheet
                Button {
                    logger.info("User requested scanner change")
                    appState.showScannerSelection = true
                } label: {
                    Label("Change Scanner", systemImage: "scanner")
                }
                .help("Change Scanner")

                Menu {
                    ForEach(appState.presets) { preset in
                        Button {
                            appState.currentPreset = preset
                        } label: {
                            HStack {
                                Text(preset.name)
                                if preset.id == appState.currentPreset.id {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption)
                        Text(appState.currentPreset.name)
                            .font(.callout)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .modifier(GlassToolbarPill())
                }
                .menuIndicator(.hidden)
                .help("Select Preset")

                Button {
                    Task {
                        if appState.scannerManager.connectionState.isConnected || appState.useMockScanner {
                            logger.info("Starting scan from toolbar with preset: \(appState.currentPreset.name)")
                            // Add to queue first, then start scanning
                            appState.addToQueue(preset: appState.currentPreset, count: 1)
                            await appState.startScanning()
                        }
                    }
                } label: {
                    Label(
                        appState.isScanning ? "Cancel Scan" : "Start Scan",
                        systemImage: appState.isScanning ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appState.scannerManager.connectionState.isConnected && !appState.useMockScanner)
                .help("Start Scan (⌘R)")
            }
        }
    }
}

struct DetailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.selectedSection {
            case .scan:
                ScanView()
            case .queue:
                QueueView()
            case .library:
                LibraryView()
            case .presets:
                PresetView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct GlassToolbarPill: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 16.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
        } else {
            content
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
        }
    }
}

#Preview {
    MainWindow()
        .environment(AppState())
        .frame(width: 1000, height: 700)
}
#endif
