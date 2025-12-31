//
//  SidebarView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

#if os(macOS)
import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        List(NavigationSection.allCases, selection: $appState.selectedSection) { section in
            NavigationLink(value: section) {
                Label {
                    Text(section.rawValue)
                        .font(.body)
                } icon: {
                    Image(systemName: section.iconName)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
        .listStyle(.sidebar)
        .navigationTitle("ScanFlow")
        .frame(minWidth: 200)
        .background(.thinMaterial)
    }
}

#Preview {
    SidebarView()
        .environment(AppState())
        .frame(width: 200, height: 600)
}
#endif
