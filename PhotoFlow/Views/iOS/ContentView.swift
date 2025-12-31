//
//  ContentView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

#if os(iOS)
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedSection) {
            ForEach(NavigationSection.allCases) { section in
                NavigationStack {
                    sectionView(for: section)
                        .navigationTitle(section.rawValue)
                        .toolbar {
                            if section == .scan {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button {
                                        Task {
                                            if appState.useMockScanner {
                                                await appState.scannerManager.connectMockScanner()
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "gearshape")
                                    }
                                }
                            }
                        }
                }
                .tabItem {
                    Label(section.rawValue, systemImage: section.iconName)
                }
                .tag(section)
            }
        }
    }

    @ViewBuilder
    private func sectionView(for section: NavigationSection) -> some View {
        switch section {
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
}

#Preview {
    ContentView()
        .environment(AppState())
}
#endif
