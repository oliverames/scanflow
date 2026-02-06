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
                HStack(spacing: 12) {
                    Image(systemName: section.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(section.rawValue)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ScanFlow")
        .frame(minWidth: 180, idealWidth: 200, maxWidth: 240)
    }
}

#endif
