//
//  ScanView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.scanflow.app", category: "ScanView")

struct ScanView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            // Preview Area - takes remaining space
            PreviewView()
                .frame(minWidth: 400, maxWidth: .infinity)
                .layoutPriority(1)

            // Control Panel (Inspector style) - toggleable
            if appState.showScanSettings {
                Divider()

                ControlPanelView()
                    .fixedSize(horizontal: true, vertical: false)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onAppear {
            logger.info("ScanView appeared")
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
