//
//  MainWindow.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

#if os(macOS)
import SwiftUI

struct MainWindow: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } detail: {
            DetailView()
                .navigationSplitViewColumnWidth(min: 700, ideal: 900)
        }
        .navigationSplitViewStyle(.balanced)
        .background(.ultraThinMaterial)
        .onAppear {
            // Automatically discover scanners on launch
            Task {
                await appState.scannerManager.discoverScanners()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                ScannerStatusView()

                Spacer()

                Menu {
                    Button("Quick Scan (300 DPI)") {
                        appState.currentPreset = ScanPreset.defaults[0]
                    }
                    Button("Archive Quality (600 DPI)") {
                        appState.currentPreset = ScanPreset.defaults[1]
                    }
                } label: {
                    Image(systemName: "doc.viewfinder")
                }
                .help("Quick Presets")

                Button {
                    Task {
                        if appState.scannerManager.connectionState.isConnected {
                            await appState.startScanning()
                        } else {
                            if appState.useMockScanner {
                                await appState.scannerManager.connectMockScanner()
                            } else {
                                await appState.scannerManager.discoverScanners()
                            }
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
        .alert("Error", isPresented: $appState.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appState.alertMessage)
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
        .background(.ultraThinMaterial)
    }
}

#Preview {
    MainWindow()
        .environment(AppState())
        .frame(width: 1000, height: 700)
}
#endif
