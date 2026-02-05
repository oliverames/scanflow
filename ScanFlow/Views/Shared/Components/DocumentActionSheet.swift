//
//  DocumentActionSheet.swift
//  ScanFlow
//
//  Presents detected document actions and allows creation in Calendar or Contacts.
//

import SwiftUI

struct DocumentActionSheet: View {
    @Environment(AppState.self) private var appState
    let file: ScannedFile
    let suggestions: [DocumentActionSuggestion]
    let onDismiss: () -> Void

    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create From Document")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(file.filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            if suggestions.isEmpty {
                ContentUnavailableView {
                    Label("No Actions Found", systemImage: "sparkle.magnifyingglass")
                } description: {
                    Text("No events or contacts were detected in this document.")
                }
            } else {
                List(suggestions) { suggestion in
                    HStack(spacing: 12) {
                        Image(systemName: iconName(for: suggestion.kind))
                            .foregroundStyle(Color.accentColor)
                            .font(.system(size: 18))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.title)
                                .font(.headline)
                            Text(suggestion.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Create") {
                            create(suggestion)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isProcessing)
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .frame(minWidth: 420, idealWidth: 520, minHeight: 320, idealHeight: 420)
    }

    private func iconName(for kind: DocumentActionKind) -> String {
        switch kind {
        case .event:
            return "calendar.badge.plus"
        case .contact:
            return "person.crop.circle.badge.plus"
        }
    }

    private func create(_ suggestion: DocumentActionSuggestion) {
        isProcessing = true
        Task { @MainActor in
            do {
                #if os(macOS)
                try await appState.documentActionService.createAction(from: suggestion)
                appState.showAlert(message: successMessage(for: suggestion.kind))
                #endif
            } catch {
                appState.showAlert(message: "Failed to create action: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }

    private func successMessage(for kind: DocumentActionKind) -> String {
        switch kind {
        case .event:
            return "Event created in Calendar"
        case .contact:
            return "Contact created"
        }
    }
}
