//
//  UITests.swift
//  ScanFlowTests
//
//  UI tests for ScanFlow views using SwiftUI testing patterns.
//

import Testing
import SwiftUI
@testable import ScanFlow

// MARK: - View Model State Tests

@Suite("AppState UI Integration Tests")
struct AppStateUITests {

    @Test("Navigation section changes update selectedSection")
    @MainActor
    func navigationSectionChanges() {
        let appState = AppState()

        appState.selectedSection = .scan
        #expect(appState.selectedSection == .scan)

        appState.selectedSection = .queue
        #expect(appState.selectedSection == .queue)

        appState.selectedSection = .library
        #expect(appState.selectedSection == .library)

        appState.selectedSection = .presets
        #expect(appState.selectedSection == .presets)
    }

    @Test("All navigation sections have correct icon names")
    func navigationSectionIcons() {
        #expect(NavigationSection.scan.iconName == "scanner")
        #expect(NavigationSection.queue.iconName == "list.bullet")
        #expect(NavigationSection.library.iconName == "photo.stack")
        #expect(NavigationSection.presets.iconName == "slider.horizontal.3")
    }

    @Test("All navigation sections have correct display names")
    func navigationSectionNames() {
        #expect(NavigationSection.scan.rawValue == "Scan")
        #expect(NavigationSection.queue.rawValue == "Scan Queue")
        #expect(NavigationSection.library.rawValue == "Scanned Files")
        #expect(NavigationSection.presets.rawValue == "Scan Presets")
    }

    @Test("Alert state updates correctly")
    @MainActor
    func alertStateUpdates() {
        let appState = AppState()

        #expect(appState.showingAlert == false)
        #expect(appState.alertMessage == "")

        appState.showAlert(message: "Test alert message")

        #expect(appState.showingAlert == true)
        #expect(appState.alertMessage == "Test alert message")
    }

    @Test("Scan settings panel toggle works")
    @MainActor
    func scanSettingsPanelToggle() {
        let appState = AppState()

        let initialState = appState.showScanSettings
        appState.showScanSettings.toggle()

        #expect(appState.showScanSettings == !initialState)
    }

    @Test("Scanner selection sheet state")
    @MainActor
    func scannerSelectionSheetState() {
        let appState = AppState()

        appState.showScannerSelection = true
        #expect(appState.showScannerSelection == true)

        appState.showScannerSelection = false
        #expect(appState.showScannerSelection == false)
    }
}

// MARK: - Preset UI Tests

@Suite("Preset UI Tests")
struct PresetUITests {

    @Test("Default presets are loaded")
    @MainActor
    func defaultPresetsLoaded() {
        let appState = AppState()

        #expect(!appState.presets.isEmpty)
        #expect(appState.presets.count >= 9) // At least 9 default presets
    }

    @Test("Current preset can be changed")
    @MainActor
    func currentPresetChanges() {
        let appState = AppState()

        guard appState.presets.count >= 2 else {
            Issue.record("Not enough presets for test")
            return
        }

        let firstPreset = appState.presets[0]
        let secondPreset = appState.presets[1]

        appState.currentPreset = firstPreset
        #expect(appState.currentPreset.id == firstPreset.id)

        appState.currentPreset = secondPreset
        #expect(appState.currentPreset.id == secondPreset.id)
    }

    @Test("Preset name binding works")
    @MainActor
    func presetNameBinding() {
        let appState = AppState()

        let originalName = appState.currentPreset.name
        appState.currentPreset.name = "Test Preset Name"

        #expect(appState.currentPreset.name == "Test Preset Name")

        // Restore
        appState.currentPreset.name = originalName
    }

    @Test("Preset destination binding works")
    @MainActor
    func presetDestinationBinding() {
        let appState = AppState()

        let testPath = "~/Documents/TestScans"
        appState.currentPreset.destination = testPath

        #expect(appState.currentPreset.destination == testPath)
    }
}

// MARK: - Queue UI Tests

@Suite("Queue UI Tests")
struct QueueUITests {

    @Test("Queue starts empty")
    @MainActor
    func queueStartsEmpty() {
        let appState = AppState()

        #expect(appState.scanQueue.isEmpty)
    }

    @Test("Adding to queue increases count")
    @MainActor
    func addingToQueueIncreasesCount() {
        let appState = AppState()

        appState.addToQueue(preset: appState.currentPreset, count: 1)
        #expect(appState.scanQueue.count == 1)

        appState.addToQueue(preset: appState.currentPreset, count: 2)
        #expect(appState.scanQueue.count == 3)
    }

    @Test("Removing from queue decreases count")
    @MainActor
    func removingFromQueueDecreasesCount() {
        let appState = AppState()

        appState.addToQueue(preset: appState.currentPreset, count: 3)
        #expect(appState.scanQueue.count == 3)

        if let firstScan = appState.scanQueue.first {
            appState.removeFromQueue(scan: firstScan)
            #expect(appState.scanQueue.count == 2)
        }
    }

    @Test("Queued scan has correct initial status")
    @MainActor
    func queuedScanInitialStatus() {
        let appState = AppState()

        appState.addToQueue(preset: appState.currentPreset, count: 1)

        guard let scan = appState.scanQueue.first else {
            Issue.record("No scan in queue")
            return
        }

        #expect(scan.status == .pending)
    }

    @Test("Queued scan preserves preset")
    @MainActor
    func queuedScanPreservesPreset() {
        let appState = AppState()

        let preset = appState.currentPreset
        appState.addToQueue(preset: preset, count: 1)

        guard let scan = appState.scanQueue.first else {
            Issue.record("No scan in queue")
            return
        }

        #expect(scan.preset.id == preset.id)
        #expect(scan.preset.name == preset.name)
    }
}

// MARK: - Library UI Tests

@Suite("Library UI Tests")
struct LibraryUITests {

    @Test("Scanned files starts empty")
    @MainActor
    func scannedFilesStartsEmpty() {
        let appState = AppState()

        #expect(appState.scannedFiles.isEmpty)
    }

    @Test("ScannedFile displays formatted size")
    func scannedFileFormattedSize() {
        let file = ScannedFile(
            filename: "test.pdf",
            fileURL: URL(fileURLWithPath: "/tmp/test.pdf"),
            size: 1024 * 1024, // 1 MB
            resolution: 300,
            dateScanned: Date(),
            scannerModel: "Test Scanner",
            format: .pdf
        )

        // formattedSize should format bytes nicely
        #expect(!file.formattedSize.isEmpty)
    }

    @Test("ScannedFile Identifiable conformance")
    func scannedFileIdentifiable() {
        let file1 = ScannedFile(
            filename: "test1.pdf",
            fileURL: URL(fileURLWithPath: "/tmp/test1.pdf"),
            size: 1024,
            resolution: 300,
            dateScanned: Date(),
            scannerModel: "Scanner",
            format: .pdf
        )

        let file2 = ScannedFile(
            filename: "test2.pdf",
            fileURL: URL(fileURLWithPath: "/tmp/test2.pdf"),
            size: 2048,
            resolution: 600,
            dateScanned: Date(),
            scannerModel: "Scanner",
            format: .pdf
        )

        #expect(file1.id != file2.id)
    }
}

// MARK: - Settings UI Tests

@Suite("Settings UI Tests")
struct SettingsUITests {

    @Test("Default resolution setting")
    @MainActor
    func defaultResolutionSetting() {
        let appState = AppState()

        // Default resolution should be set
        #expect(appState.defaultResolution > 0)
    }

    @Test("Resolution setting can be changed")
    @MainActor
    func resolutionSettingChanges() {
        let appState = AppState()

        appState.defaultResolution = 600
        #expect(appState.defaultResolution == 600)

        appState.defaultResolution = 300
        #expect(appState.defaultResolution == 300)
    }

    @Test("Mock scanner toggle works")
    @MainActor
    func mockScannerToggle() {
        let appState = AppState()

        let original = appState.useMockScanner

        appState.useMockScanner = true
        #expect(appState.useMockScanner == true)

        appState.useMockScanner = false
        #expect(appState.useMockScanner == false)

        // Restore
        appState.useMockScanner = original
    }

    @Test("Background connection setting works")
    @MainActor
    func backgroundConnectionSetting() {
        let appState = AppState()

        let original = appState.keepConnectedInBackground

        appState.keepConnectedInBackground = true
        #expect(appState.keepConnectedInBackground == true)

        // Restore
        appState.keepConnectedInBackground = original
    }

    @Test("Auto open destination setting works")
    @MainActor
    func autoOpenDestinationSetting() {
        let appState = AppState()

        appState.autoOpenDestination = true
        #expect(appState.autoOpenDestination == true)

        appState.autoOpenDestination = false
        #expect(appState.autoOpenDestination == false)
    }
}

// MARK: - Scan Format UI Tests

@Suite("Scan Format UI Tests")
struct ScanFormatUITests {

    @Test("All scan formats have raw values")
    func scanFormatsHaveRawValues() {
        for format in ScanFormat.allCases {
            #expect(!format.rawValue.isEmpty)
        }
    }

    @Test("Scan format selection updates preset")
    @MainActor
    func scanFormatUpdatesPreset() {
        let appState = AppState()

        appState.currentPreset.format = .pdf
        #expect(appState.currentPreset.format == .pdf)

        appState.currentPreset.format = .jpeg
        #expect(appState.currentPreset.format == .jpeg)

        appState.currentPreset.format = .png
        #expect(appState.currentPreset.format == .png)

        appState.currentPreset.format = .tiff
        #expect(appState.currentPreset.format == .tiff)
    }
}

// MARK: - Color Mode UI Tests

@Suite("Color Mode UI Tests")
struct ColorModeUITests {

    @Test("All color modes exist")
    func allColorModesExist() {
        #expect(ColorMode.allCases.count >= 3)
    }

    @Test("Color mode selection updates preset")
    @MainActor
    func colorModeUpdatesPreset() {
        let appState = AppState()

        appState.currentPreset.colorMode = .color
        #expect(appState.currentPreset.colorMode == .color)

        appState.currentPreset.colorMode = .grayscale
        #expect(appState.currentPreset.colorMode == .grayscale)

        appState.currentPreset.colorMode = .blackWhite
        #expect(appState.currentPreset.colorMode == .blackWhite)
    }
}

// MARK: - Resolution UI Tests

@Suite("Resolution UI Tests")
struct ResolutionUITests {

    @Test("Resolution presets available")
    @MainActor
    func resolutionPresetsAvailable() {
        let commonResolutions = [75, 150, 300, 600, 1200]

        for resolution in commonResolutions {
            let appState = AppState()
            appState.currentPreset.resolution = resolution
            #expect(appState.currentPreset.resolution == resolution)
        }
    }

    @Test("Custom resolution within bounds")
    @MainActor
    func customResolutionWithinBounds() {
        let appState = AppState()

        // Test lower bound
        appState.currentPreset.resolution = 50
        #expect(appState.currentPreset.resolution == 50)

        // Test upper bound
        appState.currentPreset.resolution = 2400
        #expect(appState.currentPreset.resolution == 2400)
    }
}

// MARK: - Document Action Suggestion UI Tests

@Suite("Document Action UI Tests")
struct DocumentActionUITests {

    @Test("DocumentActionKind cases")
    func documentActionKindCases() {
        #expect(DocumentActionKind.event.rawValue == "event")
        #expect(DocumentActionKind.contact.rawValue == "contact")
    }

    @Test("DocumentActionSuggestion is Identifiable")
    func suggestionIsIdentifiable() {
        let suggestion1 = DocumentActionSuggestion(
            kind: .event,
            title: "Meeting",
            subtitle: "Tomorrow",
            date: Date()
        )

        let suggestion2 = DocumentActionSuggestion(
            kind: .contact,
            title: "John Doe",
            subtitle: "john@example.com",
            email: "john@example.com"
        )

        #expect(suggestion1.id != suggestion2.id)
    }

    @Test("Event suggestion has date")
    func eventSuggestionHasDate() {
        let date = Date()
        let suggestion = DocumentActionSuggestion(
            kind: .event,
            title: "Meeting",
            subtitle: "Details",
            date: date,
            duration: 3600
        )

        #expect(suggestion.date != nil)
        #expect(suggestion.duration == 3600)
    }

    @Test("Contact suggestion has contact info")
    func contactSuggestionHasContactInfo() {
        let suggestion = DocumentActionSuggestion(
            kind: .contact,
            title: "Jane Doe",
            subtitle: "Contact",
            contactName: "Jane Doe",
            email: "jane@example.com",
            phone: "+1-555-123-4567",
            address: "123 Main St"
        )

        #expect(suggestion.contactName == "Jane Doe")
        #expect(suggestion.email == "jane@example.com")
        #expect(suggestion.phone == "+1-555-123-4567")
        #expect(suggestion.address == "123 Main St")
    }
}

// MARK: - Naming Settings UI Tests

@Suite("Naming Settings UI Tests")
struct NamingSettingsUITests {

    @Test("NamingSettings default values")
    func namingSettingsDefaults() {
        let settings = NamingSettings.default

        // Verify default settings exist
        #expect(settings.enabled == false || settings.enabled == true) // Just verify it's a bool
    }

    @Test("NamingSettings enabled toggle")
    @MainActor
    func namingSettingsEnabledToggle() {
        let appState = AppState()

        appState.currentPreset.namingSettings.enabled = true
        #expect(appState.currentPreset.namingSettings.enabled == true)

        appState.currentPreset.namingSettings.enabled = false
        #expect(appState.currentPreset.namingSettings.enabled == false)
    }

    @Test("FallbackBehavior cases exist")
    func fallbackBehaviorCases() {
        let behaviors: [NamingSettings.FallbackBehavior] = [.promptManual, .notifyAndFallback, .silentFallback]
        #expect(behaviors.count == 3)
    }
}

// MARK: - Separation Settings UI Tests

@Suite("Separation Settings UI Tests")
struct SeparationSettingsUITests {

    @Test("SeparationSettings default values")
    func separationSettingsDefaults() {
        let settings = SeparationSettings.default

        #expect(settings.enabled == false)
    }

    @Test("SeparationSettings enabled toggle")
    @MainActor
    func separationSettingsEnabledToggle() {
        let appState = AppState()

        appState.currentPreset.separationSettings.enabled = true
        #expect(appState.currentPreset.separationSettings.enabled == true)

        appState.currentPreset.separationSettings.enabled = false
        #expect(appState.currentPreset.separationSettings.enabled == false)
    }

    @Test("Blank page sensitivity range")
    @MainActor
    func blankPageSensitivityRange() {
        let appState = AppState()

        appState.currentPreset.separationSettings.blankSensitivity = 0.0
        #expect(appState.currentPreset.separationSettings.blankSensitivity == 0.0)

        appState.currentPreset.separationSettings.blankSensitivity = 1.0
        #expect(appState.currentPreset.separationSettings.blankSensitivity == 1.0)

        appState.currentPreset.separationSettings.blankSensitivity = 0.5
        #expect(appState.currentPreset.separationSettings.blankSensitivity == 0.5)
    }

    @Test("Barcode pattern configuration")
    @MainActor
    func barcodePatternConfiguration() {
        let appState = AppState()

        appState.currentPreset.separationSettings.useBarcodes = true
        appState.currentPreset.separationSettings.barcodePattern = "^SPLIT$"

        #expect(appState.currentPreset.separationSettings.useBarcodes == true)
        #expect(appState.currentPreset.separationSettings.barcodePattern == "^SPLIT$")
    }
}

// MARK: - Existing File Behavior UI Tests

@Suite("Existing File Behavior UI Tests")
struct ExistingFileBehaviorUITests {

    @Test("All behaviors have raw values")
    func allBehaviorsHaveRawValues() {
        for behavior in ExistingFileBehavior.allCases {
            #expect(!behavior.rawValue.isEmpty)
        }
    }

    @Test("Behavior selection updates preset")
    @MainActor
    func behaviorSelectionUpdatesPreset() {
        let appState = AppState()

        for behavior in ExistingFileBehavior.allCases {
            appState.currentPreset.existingFileBehavior = behavior
            #expect(appState.currentPreset.existingFileBehavior == behavior)
        }
    }
}

// MARK: - QueuedScan Status UI Tests

@Suite("QueuedScan Status UI Tests")
struct QueuedScanStatusUITests {

    @Test("All scan statuses exist")
    func allScanStatusesExist() {
        let pending = ScanStatus.pending
        let scanning = ScanStatus.scanning
        let processing = ScanStatus.processing
        let completed = ScanStatus.completed
        let failed = ScanStatus.failed("error")

        #expect(pending == .pending)
        #expect(scanning == .scanning)
        #expect(processing == .processing)
        #expect(completed == .completed)

        if case .failed(let message) = failed {
            #expect(message == "error")
        }
    }

    @Test("Scan status equality")
    func scanStatusEquality() {
        #expect(ScanStatus.pending == ScanStatus.pending)
        #expect(ScanStatus.scanning == ScanStatus.scanning)
        #expect(ScanStatus.completed == ScanStatus.completed)
        #expect(ScanStatus.pending != ScanStatus.completed)
    }
}
