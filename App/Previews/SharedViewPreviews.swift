import SwiftUI
@testable import ScanFlow

#Preview("Scan View") {
    ScanView()
        .environment(AppState())
        .frame(width: 900, height: 600)
}

#Preview("Queue View") {
    QueueView()
        .environment(AppState())
        .frame(width: 700, height: 500)
}

#Preview("Library View") {
    LibraryView()
        .environment(AppState())
        .frame(width: 700, height: 500)
}

#Preview("Preset View") {
    PresetView()
        .environment(AppState())
        .frame(width: 800, height: 600)
}

#if os(iOS)
#Preview("Content View") {
    ContentView()
        .environment(AppState())
}

#Preview("Remote Scan Panel") {
    RemoteScanPanel()
        .environment(AppState())
        .padding()
}
#endif
