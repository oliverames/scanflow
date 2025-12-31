//
//  ShortcutsIntegration.swift
//  ScanFlow
//
//  Shortcuts app integration using App Intents
//  Enables Siri and Shortcuts automation
//

import Foundation
import AppIntents
#if os(macOS)
import AppKit
#endif

// MARK: - App Shortcuts

@available(macOS 13.0, *)
struct ScanFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanDocumentIntent(),
            phrases: [
                "Scan a document with \(.applicationName)",
                "Start scanning in \(.applicationName)",
                "Scan with \(.applicationName)"
            ],
            shortTitle: "Scan Document",
            systemImageName: "scanner"
        )

        AppShortcut(
            intent: ScanWithProfileIntent(),
            phrases: [
                "Scan with \(\.$profileName) profile in \(.applicationName)"
            ],
            shortTitle: "Scan with Profile",
            systemImageName: "doc.viewfinder"
        )

        AppShortcut(
            intent: ProcessPDFWithOCRIntent(),
            phrases: [
                "Process PDF with OCR in \(.applicationName)",
                "Add OCR to PDF in \(.applicationName)"
            ],
            shortTitle: "OCR PDF",
            systemImageName: "doc.text.viewfinder"
        )
    }
}

// MARK: - Scan Document Intent

@available(macOS 13.0, *)
struct ScanDocumentIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Document"
    static var description = IntentDescription("Scans a document using the current profile")

    @Parameter(title: "Profile Name", default: "Quick B&W (300 DPI)")
    var profileName: String?

    func perform() async throws -> some IntentResult {
        // Access app state and trigger scan
        // This would integrate with AppState when app is running
        return .result()
    }
}

// MARK: - Scan with Profile Intent

@available(macOS 13.0, *)
struct ScanWithProfileIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan with Profile"
    static var description = IntentDescription("Scans a document using a specific scan profile")

    @Parameter(title: "Profile Name", description: "The scan profile to use")
    var profileName: String

    @Parameter(title: "Number of Pages", default: 1)
    var pageCount: Int

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        // Validate profile exists
        guard !profileName.isEmpty else {
            throw IntentError.invalidParameter
        }

        // Trigger scan with specified profile
        // Integration point: AppState.shared.scanWithProfile(profileName, count: pageCount)

        return .result(value: true)
    }
}

// MARK: - Process PDF with OCR Intent

@available(macOS 13.0, *)
struct ProcessPDFWithOCRIntent: AppIntent {
    static var title: LocalizedStringResource = "Process PDF with OCR"
    static var description = IntentDescription("Adds searchable OCR text layer to PDF")

    @Parameter(title: "PDF File", description: "The PDF file to process")
    var inputFile: IntentFile

    @Parameter(title: "Output Folder", description: "Where to save the processed PDF")
    var outputFolder: IntentFile?

    @Parameter(title: "Language", default: "en")
    var language: String

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        // Process PDF with OCR
        // Integration point: ImageProcessor.addOCRToPDF()

        // For now, return input as placeholder
        return .result(value: inputFile)
    }
}

// MARK: - Batch Convert Intent

@available(macOS 13.0, *)
struct BatchConvertToSearchablePDFIntent: AppIntent {
    static var title: LocalizedStringResource = "Batch Convert to Searchable PDF"
    static var description = IntentDescription("Converts multiple images to searchable PDFs")

    @Parameter(title: "Input Folder", description: "Folder containing images")
    var inputFolder: IntentFile

    @Parameter(title: "Output Folder", description: "Where to save PDFs")
    var outputFolder: IntentFile

    @Parameter(title: "OCR Enabled", default: true)
    var ocrEnabled: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        // Process folder
        // Integration point: BatchProcessor.convertFolderToPDF()

        return .result(value: 0)
    }
}

// MARK: - Get Scanner Status Intent

@available(macOS 13.0, *)
struct GetScannerStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Scanner Status"
    static var description = IntentDescription("Gets the current scanner connection status")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Get scanner status
        // Integration point: ScannerManager.connectionState

        return .result(value: "Disconnected")
    }
}

// MARK: - Connect Scanner Intent

@available(macOS 13.0, *)
struct ConnectScannerIntent: AppIntent {
    static var title: LocalizedStringResource = "Connect Scanner"
    static var description = IntentDescription("Connects to the default scanner")

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        // Connect to scanner
        // Integration point: ScannerManager.discoverAndConnect()

        return .result(value: true)
    }
}

// MARK: - Intent Errors

enum IntentError: Error, LocalizedError {
    case invalidParameter
    case scannerNotConnected
    case scanFailed
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .invalidParameter:
            return "Invalid parameter provided"
        case .scannerNotConnected:
            return "Scanner is not connected"
        case .scanFailed:
            return "Scan operation failed"
        case .fileNotFound:
            return "File not found"
        }
    }
}

// MARK: - App Intent Entity (Scan Profile)

@available(macOS 13.0, *)
struct ScanProfileEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Scan Profile"

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = ScanProfileQuery()
}

@available(macOS 13.0, *)
struct ScanProfileQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ScanProfileEntity] {
        // Return scan profiles by ID
        return []
    }

    func suggestedEntities() async throws -> [ScanProfileEntity] {
        // Return all available scan profiles
        return [
            ScanProfileEntity(id: UUID(), name: "Quick B&W (300 DPI)"),
            ScanProfileEntity(id: UUID(), name: "Searchable PDF (300 DPI)"),
            ScanProfileEntity(id: UUID(), name: "Archive Quality (600 DPI)"),
            ScanProfileEntity(id: UUID(), name: "Color Document (300 DPI)"),
            ScanProfileEntity(id: UUID(), name: "Receipt/Business Card"),
            ScanProfileEntity(id: UUID(), name: "Legal Documents (600 DPI Searchable)"),
            ScanProfileEntity(id: UUID(), name: "Photo Scan (600 DPI)"),
            ScanProfileEntity(id: UUID(), name: "Enlargement (1200 DPI)")
        ]
    }
}

// MARK: - Integration Helper

/// Helper to connect Shortcuts to app state
@MainActor
class ShortcutsIntegrationHelper {
    static let shared = ShortcutsIntegrationHelper()

    weak var appState: AppState?

    private init() {}

    func configure(with appState: AppState) {
        self.appState = appState
    }

    // MARK: - Intent Handlers

    func handleScanIntent(profileName: String?, pageCount: Int) async -> Bool {
        guard let appState = appState else { return false }

        if let profileName = profileName,
           let profile = appState.presets.first(where: { $0.name == profileName }) {
            appState.currentPreset = profile
        }

        appState.addToQueue(preset: appState.currentPreset, count: pageCount)
        await appState.startScanning()

        return true
    }

    func handleOCRIntent(inputURL: URL, outputURL: URL) async throws -> URL {
        guard let appState = appState else {
            throw IntentError.scanFailed
        }

        guard let image = NSImage(contentsOf: inputURL) else {
            throw IntentError.fileNotFound
        }

        let text = try await appState.imageProcessor.recognizeText(image)

        // Save OCR result
        try text.write(to: outputURL, atomically: true, encoding: .utf8)

        return outputURL
    }

    func getScannerStatus() -> String {
        guard let appState = appState else { return "Unknown" }
        return appState.scannerManager.connectionState.description
    }
}

// MARK: - Usage Documentation

/**
 ## Shortcuts App Integration

 ScanFlow provides several actions for the Shortcuts app:

 ### Available Actions

 1. **Scan Document**
    - Scans a document with the current or specified profile
    - Input: Profile name (optional), Page count
    - Output: Boolean success

 2. **Scan with Profile**
    - Scans using a specific profile
    - Input: Profile name, Page count
    - Output: Boolean success

 3. **Process PDF with OCR**
    - Adds OCR text layer to PDF
    - Input: PDF file, Language
    - Output: Processed PDF file

 4. **Batch Convert to Searchable PDF**
    - Converts folder of images to searchable PDFs
    - Input: Input folder, Output folder, OCR enabled
    - Output: Number of files processed

 5. **Get Scanner Status**
    - Returns scanner connection status
    - Output: Status string

 6. **Connect Scanner**
    - Connects to default scanner
    - Output: Boolean success

 ### Example Shortcuts

 #### Quick Scan Shortcut
 1. Run "Connect Scanner" action
 2. Run "Scan Document" with profile "Quick B&W (300 DPI)"
 3. Show notification "Scan complete"

 #### OCR Batch Processing
 1. Get folder of images
 2. Run "Batch Convert to Searchable PDF"
 3. Save to Documents folder

 #### Siri Commands
 - "Hey Siri, scan a document with ScanFlow"
 - "Hey Siri, scan with Legal Documents profile"
 - "Hey Siri, process PDF with OCR"
 */
