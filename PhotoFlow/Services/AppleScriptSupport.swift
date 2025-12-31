//
//  AppleScriptSupport.swift
//  ScanFlow
//
//  AppleScript and automation support for ScanFlow
//  Enables scriptable scanning workflows
//

import Foundation
#if os(macOS)
import AppKit
#endif

#if os(macOS)

/// AppleScript command handler for ScanFlow
@MainActor
class AppleScriptSupport: NSObject {

    weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    // MARK: - AppleScript Commands

    /// Scan with specified profile name
    @objc func scanWithProfile(_ profileName: String) async -> Bool {
        guard let appState = appState else { return false }

        // Find profile by name
        guard let profile = appState.presets.first(where: { $0.name == profileName }) else {
            return false
        }

        // Set as current preset
        appState.currentPreset = profile

        // Start scanning
        await appState.startScanning()

        return true
    }

    /// Scan with current profile
    @objc func scan() async -> Bool {
        guard let appState = appState else { return false }
        await appState.startScanning()
        return true
    }

    /// Add to queue
    @objc func addToQueue(count: Int) -> Bool {
        guard let appState = appState else { return false }
        appState.addToQueue(preset: appState.currentPreset, count: count)
        return true
    }

    /// Get scanner status
    @objc func getScannerStatus() -> String {
        guard let appState = appState else { return "Unknown" }
        return appState.scannerManager.connectionState.description
    }

    /// Connect to scanner
    @objc func connectScanner() async -> Bool {
        guard let appState = appState else { return false }

        if appState.useMockScanner {
            await appState.scannerManager.connectMockScanner()
        } else {
            await appState.scannerManager.discoverScanners()
        }

        return appState.scannerManager.connectionState.isConnected
    }

    /// Disconnect scanner
    @objc func disconnectScanner() async -> Bool {
        guard let appState = appState else { return false }
        await appState.scannerManager.disconnect()
        return true
    }

    /// Get list of available profiles
    @objc func getProfiles() -> [String] {
        guard let appState = appState else { return [] }
        return appState.presets.map { $0.name }
    }

    /// Set current profile
    @objc func setProfile(_ profileName: String) -> Bool {
        guard let appState = appState else { return false }

        if let profile = appState.presets.first(where: { $0.name == profileName }) {
            appState.currentPreset = profile
            return true
        }

        return false
    }

    /// Get scanned file count
    @objc func getScannedFileCount() -> Int {
        guard let appState = appState else { return 0 }
        return appState.scannedFiles.count
    }

    /// Export last scanned files to folder
    @objc func exportLastScanToFolder(_ folderPath: String) async -> Bool {
        guard let appState = appState else { return false }
        guard !appState.scannedFiles.isEmpty else { return false }

        let destURL = URL(fileURLWithPath: folderPath)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)

        // Copy last scanned file
        guard let lastFile = appState.scannedFiles.last else { return false }
        let destFileURL = destURL.appendingPathComponent(lastFile.filename)

        do {
            try FileManager.default.copyItem(at: lastFile.fileURL, to: destFileURL)
            return true
        } catch {
            return false
        }
    }

    /// Process folder of images with OCR
    @objc func processFolder(_ folderPath: String, withOCR: Bool) async -> Int {
        guard let appState = appState else { return 0 }

        let folderURL = URL(fileURLWithPath: folderPath)
        var processedCount = 0

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            for fileURL in fileURLs {
                guard let image = NSImage(contentsOf: fileURL) else { continue }

                // Process image
                if withOCR {
                    _ = try? await appState.imageProcessor.recognizeText(image)
                }

                processedCount += 1
            }
        } catch {
            return 0
        }

        return processedCount
    }
}

// MARK: - AppleScript Integration Helper

/// Extension to make AppState scriptable
extension AppState {

    /// AppleScript handler instance
    private static var scriptHandler: AppleScriptSupport?

    /// Register AppleScript support
    func registerAppleScriptSupport() {
        Self.scriptHandler = AppleScriptSupport(appState: self)
    }

    /// Get AppleScript handler
    static func getScriptHandler() -> AppleScriptSupport? {
        return scriptHandler
    }
}

// MARK: - AppleScript Definition (SDEF)

/// This is a comment showing what the .sdef file should contain:
/**
 <?xml version="1.0" encoding="UTF-8"?>
 <!DOCTYPE dictionary SYSTEM "file://localhost/System/Library/DTDs/sdef.dtd">
 <dictionary title="ScanFlow Terminology">
     <suite name="ScanFlow Suite" code="ScFl" description="Commands for controlling ScanFlow">

         <command name="scan" code="ScFlScan" description="Start scanning with current profile">
             <result type="boolean" description="Success"/>
         </command>

         <command name="scan with profile" code="ScFlScPr" description="Scan with specified profile">
             <direct-parameter type="text" description="Profile name"/>
             <result type="boolean" description="Success"/>
         </command>

         <command name="connect scanner" code="ScFlCnct" description="Connect to scanner">
             <result type="boolean" description="Success"/>
         </command>

         <command name="disconnect scanner" code="ScFlDisc" description="Disconnect scanner">
             <result type="boolean" description="Success"/>
         </command>

         <command name="add to queue" code="ScFlAddQ" description="Add scans to queue">
             <direct-parameter type="integer" description="Number of scans"/>
             <result type="boolean" description="Success"/>
         </command>

         <command name="get scanner status" code="ScFlGtSt" description="Get scanner connection status">
             <result type="text" description="Status"/>
         </command>

         <command name="get profiles" code="ScFlGtPf" description="Get list of available profiles">
             <result type="list" description="Profile names"/>
         </command>

         <command name="set profile" code="ScFlStPf" description="Set current profile">
             <direct-parameter type="text" description="Profile name"/>
             <result type="boolean" description="Success"/>
         </command>

         <command name="export last scan" code="ScFlExpL" description="Export last scan to folder">
             <direct-parameter type="text" description="Folder path"/>
             <result type="boolean" description="Success"/>
         </command>

         <command name="process folder" code="ScFlPrFl" description="Process folder with OCR">
             <direct-parameter type="text" description="Folder path"/>
             <parameter name="with ocr" code="WthO" type="boolean" description="Enable OCR" optional="yes">
                 <cocoa key="withOCR"/>
             </parameter>
             <result type="integer" description="Number of files processed"/>
         </command>

     </suite>
 </dictionary>
 */

// MARK: - Usage Examples

/**
 Example AppleScript usage:

 ```applescript
 tell application "ScanFlow"
     -- Connect to scanner
     connect scanner

     -- Set profile
     set profile "Legal Documents (600 DPI Searchable)"

     -- Scan
     scan

     -- Export
     export last scan to "/Users/username/Documents/Scans"
 end tell
 ```

 ```applescript
 tell application "ScanFlow"
     -- Scan with specific profile
     scan with profile "Quick B&W (300 DPI)"

     -- Get status
     set scannerStatus to get scanner status

     -- Process folder with OCR
     set processedCount to process folder "/path/to/folder" with ocr true
 end tell
 ```

 ```applescript
 tell application "ScanFlow"
     -- Get available profiles
     set profileList to get profiles

     -- Add multiple to queue
     add to queue 5

     -- Disconnect
     disconnect scanner
 end tell
 ```
 */

#endif
