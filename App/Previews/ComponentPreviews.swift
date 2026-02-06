import SwiftUI
@testable import ScanFlow

#Preview("Control Panel") {
    ControlPanelView()
        .environment(AppState())
        .frame(width: 320, height: 700)
}

#Preview("Preview Area") {
    PreviewView()
        .environment(AppState())
        .frame(width: 500, height: 600)
}

#Preview("Scanner Status") {
    HStack {
        ScannerStatusView()
            .environment(AppState())
    }
    .padding()
}

#Preview("AI Renaming Settings") {
    Form {
        AIRenamingSettingsView(settings: .constant(NamingSettings()))
    }
    .frame(width: 400, height: 500)
    .padding()
}

#Preview("Document Separation Settings") {
    Form {
        DocumentSeparationSettingsView(settings: .constant(SeparationSettings()))
    }
    .frame(width: 400, height: 500)
    .padding()
}
