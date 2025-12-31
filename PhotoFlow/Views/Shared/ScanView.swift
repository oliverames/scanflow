//
//  ScanView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI

struct ScanView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            // Preview Area
            PreviewView()
                .frame(minWidth: 400, maxWidth: .infinity)

            // Control Panel (Inspector style)
            ControlPanelView()
                .frame(width: 300)
                .background(.thinMaterial)
        }
        #else
        VStack {
            PreviewView()
            ControlPanelView()
        }
        #endif
    }
}

#Preview {
    ScanView()
        .environment(AppState())
        .frame(width: 900, height: 600)
}
