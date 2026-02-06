//
//  SoftwareUpdater.swift
//  ScanFlow
//
//  Sparkle framework integration for automatic software updates
//

import Foundation
#if os(macOS)
import Sparkle

/// Observable view model for tracking update availability
@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

/// Manages software updates using Sparkle framework
@MainActor
public final class SoftwareUpdater: ObservableObject {
    /// Shared instance for app-wide access
    public static let shared = SoftwareUpdater()

    /// The Sparkle updater controller
    public let updaterController: SPUStandardUpdaterController

    /// The underlying updater instance
    public var updater: SPUUpdater {
        updaterController.updater
    }

    /// Whether automatic update checks are enabled
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    /// Whether automatic downloads are enabled
    @Published var automaticallyDownloadsUpdates: Bool {
        didSet {
            updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
        }
    }

    /// The update check interval in seconds (default: 1 day)
    var updateCheckInterval: TimeInterval {
        get { updater.updateCheckInterval }
        set { updater.updateCheckInterval = newValue }
    }

    /// Last update check date
    var lastUpdateCheckDate: Date? {
        updater.lastUpdateCheckDate
    }

    private init() {
        // Initialize the updater controller
        // startingUpdater: true means it will start checking for updates automatically
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Sync published properties with updater state
        automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updaterController.updater.automaticallyDownloadsUpdates
    }

    /// Check for updates manually
    public func checkForUpdates() {
        updater.checkForUpdates()
    }

    /// Check for updates in the background
    func checkForUpdatesInBackground() {
        updater.checkForUpdatesInBackground()
    }
}

#endif
