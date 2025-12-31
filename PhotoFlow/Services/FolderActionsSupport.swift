//
//  FolderActionsSupport.swift
//  ScanFlow
//
//  Folder Actions and file system monitoring support
//  Auto-process images dropped into watched folders
//

import Foundation
#if os(macOS)
import AppKit
#endif

#if os(macOS)

/// Folder actions manager for auto-processing
@MainActor
class FolderActionsSupport {

    /// Folder watch configuration
    struct WatchedFolder: Codable, Identifiable {
        let id: UUID
        var path: String
        var enabled: Bool
        var autoProcess: Bool
        var ocrEnabled: Bool
        var profileName: String
        var deleteOriginals: Bool
        var outputFolder: String?

        init(id: UUID = UUID(),
             path: String,
             enabled: Bool = true,
             autoProcess: Bool = true,
             ocrEnabled: Bool = false,
             profileName: String = "Quick B&W (300 DPI)",
             deleteOriginals: Bool = false,
             outputFolder: String? = nil) {
            self.id = id
            self.path = path
            self.enabled = enabled
            self.autoProcess = autoProcess
            self.ocrEnabled = ocrEnabled
            self.profileName = profileName
            self.deleteOriginals = deleteOriginals
            self.outputFolder = outputFolder
        }
    }

    // MARK: - Properties

    private var watchedFolders: [WatchedFolder] = []
    private nonisolated(unsafe) var fileSystemWatcher: FSEventStreamRef?
    weak var appState: AppState?

    // MARK: - Initialization

    init(appState: AppState? = nil) {
        self.appState = appState
        loadWatchedFolders()
    }

    deinit {
        stopWatching()
    }

    // MARK: - Configuration

    /// Add folder to watch list
    func addWatchedFolder(_ folder: WatchedFolder) {
        watchedFolders.append(folder)
        saveWatchedFolders()
        startWatching()
    }

    /// Remove watched folder
    func removeWatchedFolder(id: UUID) {
        watchedFolders.removeAll { $0.id == id }
        saveWatchedFolders()
        startWatching()
    }

    /// Update watched folder
    func updateWatchedFolder(_ folder: WatchedFolder) {
        if let index = watchedFolders.firstIndex(where: { $0.id == folder.id }) {
            watchedFolders[index] = folder
            saveWatchedFolders()
        }
    }

    /// Get all watched folders
    func getWatchedFolders() -> [WatchedFolder] {
        return watchedFolders
    }

    // MARK: - File System Watching

    /// Start watching all enabled folders
    func startWatching() {
        stopWatching()

        let enabledFolders = watchedFolders.filter { $0.enabled }
        guard !enabledFolders.isEmpty else { return }

        let paths = enabledFolders.map { $0.path as CFString } as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<FolderActionsSupport>.fromOpaque(info).takeUnretainedValue()

            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

            Task { @MainActor in
                for path in paths {
                    await watcher.handleFileSystemEvent(at: path)
                }
            }
        }

        fileSystemWatcher = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // Latency in seconds
            UInt32(kFSEventStreamCreateFlagFileEvents)
        )

        if let stream = fileSystemWatcher {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
        }
    }

    /// Stop watching folders
    nonisolated func stopWatching() {
        if let stream = fileSystemWatcher {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    // MARK: - Event Handling

    /// Handle file system event
    private func handleFileSystemEvent(at path: String) async {
        // Check if this is a new image file
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path),
              isImageFile(url) else {
            return
        }

        // Find matching watched folder
        guard let watchedFolder = watchedFolders.first(where: {
            path.hasPrefix($0.path) && $0.enabled && $0.autoProcess
        }) else {
            return
        }

        // Process the file
        await processFile(at: url, with: watchedFolder)
    }

    /// Process a file according to folder rules
    private func processFile(at url: URL, with folder: WatchedFolder) async {
        guard let appState = appState else { return }

        // Load image
        guard let image = NSImage(contentsOf: url) else { return }

        // Find profile
        guard let profile = appState.presets.first(where: { $0.name == folder.profileName }) else {
            return
        }

        // Process image
        var processedImage = image

        if profile.autoEnhance || profile.deskew || profile.autoRotate {
            processedImage = (try? await appState.imageProcessor.process(image, with: profile)) ?? image
        }

        // Perform OCR if enabled
        var ocrText: String?
        if folder.ocrEnabled {
            ocrText = try? await appState.imageProcessor.recognizeText(processedImage)
        }

        // Determine output location
        let outputFolder = folder.outputFolder ?? folder.path
        let outputURL = URL(fileURLWithPath: outputFolder)

        // Create output directory
        try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        // Save processed image
        let filename = url.deletingPathExtension().lastPathComponent + "_processed.\(profile.format.rawValue.lowercased())"
        let outputFileURL = outputURL.appendingPathComponent(filename)

        if let tiffData = processedImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {

            var imageData: Data?
            switch profile.format {
            case .jpeg:
                imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: profile.quality])
            case .png:
                imageData = bitmap.representation(using: .png, properties: [:])
            case .tiff:
                imageData = tiffData
            }

            try? imageData?.write(to: outputFileURL)

            // Save OCR text if available
            if let ocrText = ocrText {
                let txtURL = outputFileURL.deletingPathExtension().appendingPathExtension("txt")
                try? ocrText.write(to: txtURL, atomically: true, encoding: .utf8)
            }

            // Delete original if requested
            if folder.deleteOriginals {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    /// Check if file is an image
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "tiff", "tif", "bmp", "gif"]
        let ext = url.pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }

    // MARK: - Persistence

    private func saveWatchedFolders() {
        if let data = try? JSONEncoder().encode(watchedFolders) {
            UserDefaults.standard.set(data, forKey: "watchedFolders")
        }
    }

    private func loadWatchedFolders() {
        if let data = UserDefaults.standard.data(forKey: "watchedFolders"),
           let folders = try? JSONDecoder().decode([WatchedFolder].self, from: data) {
            watchedFolders = folders
        }
    }
}

// MARK: - Automator Action Support

/// Extension for Automator workflow support
extension FolderActionsSupport {

    /// Process files from Automator
    func processFilesFromAutomator(_ filePaths: [String], profileName: String, ocrEnabled: Bool) async -> [String] {
        guard let appState = appState else { return [] }

        var processedFiles: [String] = []

        for path in filePaths {
            let url = URL(fileURLWithPath: path)

            guard let image = NSImage(contentsOf: url) else { continue }
            guard let profile = appState.presets.first(where: { $0.name == profileName }) else { continue }

            // Process
            var processedImage = image
            if profile.autoEnhance || profile.deskew {
                processedImage = (try? await appState.imageProcessor.process(image, with: profile)) ?? image
            }

            // OCR
            if ocrEnabled {
                _ = try? await appState.imageProcessor.recognizeText(processedImage)
            }

            // Save
            let outputURL = url.deletingLastPathComponent()
                .appendingPathComponent(url.deletingPathExtension().lastPathComponent + "_processed")
                .appendingPathExtension(profile.format.rawValue.lowercased())

            if let tiffData = processedImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let imageData = bitmap.representation(using: .jpeg, properties: [:]) {
                try? imageData.write(to: outputURL)
                processedFiles.append(outputURL.path)
            }
        }

        return processedFiles
    }
}

// MARK: - Usage Documentation

/**
 ## Folder Actions Setup

 1. **Add Watched Folder**
    ```swift
    let folder = WatchedFolder(
        path: "/Users/username/Desktop/ScanInbox",
        enabled: true,
        autoProcess: true,
        ocrEnabled: true,
        profileName: "Searchable PDF (300 DPI)",
        deleteOriginals: false,
        outputFolder: "/Users/username/Documents/ProcessedScans"
    )
    folderActions.addWatchedFolder(folder)
    ```

 2. **Automator Workflow**
    - Open Automator
    - Create new Folder Action
    - Add "Run AppleScript" action:
    ```applescript
    on run {input, parameters}
        tell application "ScanFlow"
            process files input with profile "Quick B&W (300 DPI)" with ocr true
        end tell
        return input
    end run
    ```

 3. **Manual Processing**
    ```swift
    await folderActions.processFilesFromAutomator(
        ["/path/to/file1.jpg", "/path/to/file2.jpg"],
        profileName: "Archive Quality (600 DPI)",
        ocrEnabled: true
    )
    ```
 */

#endif
