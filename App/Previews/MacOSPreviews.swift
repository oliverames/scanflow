#if DEBUG
import SwiftUI
@testable import ScanFlow

#if os(macOS)
#Preview("Main Window") {
    MainWindow()
        .environment(AppState())
        .frame(width: 1000, height: 700)
}

#Preview("Sidebar") {
    SidebarView()
        .environment(AppState())
        .frame(width: 200, height: 600)
}

#Preview("Settings") {
    SettingsView()
        .environment(AppState())
}

#Preview("Scanner Selection") {
    ScannerSelectionView(hasSelectedScanner: .constant(false))
        .environment(AppState())
        .frame(width: 600, height: 500)
}
#endif
#endif
