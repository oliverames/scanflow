//
//  AppLifecycleDelegate.swift
//  ScanFlow
//
//  Handles app termination prompts for background scanner connectivity.
//

#if os(macOS)
import AppKit
import os.log

private let logger = Logger(subsystem: "com.scanflow.app", category: "AppLifecycleDelegate")

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    var appStateProvider: (() -> AppState)?
    private var statusBarController: StatusBarController?
    private var keepConnectedObserver: NSObjectProtocol?
    private var menuBarSettingObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(appStateProvider: { [weak self] in
            self?.appStateProvider?()
        })
        
        // Enable menu bar if either keepConnected or menuBarAlwaysEnabled is true
        updateMenuBarVisibility()

        keepConnectedObserver = NotificationCenter.default.addObserver(
            forName: .scanflowKeepConnectedChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard notification.userInfo?["enabled"] is Bool else { return }
            Task { @MainActor in
                self?.updateMenuBarVisibility()
            }
        }

        menuBarSettingObserver = NotificationCenter.default.addObserver(
            forName: .scanflowMenuBarSettingChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarVisibility()
            }
        }
    }

    private func updateMenuBarVisibility() {
        guard let appState = appStateProvider?() else { return }
        let shouldShowMenuBar = appState.keepConnectedInBackground || appState.menuBarAlwaysEnabled
        statusBarController?.setEnabled(shouldShowMenuBar)
        logger.debug("Menu bar visibility updated: \(shouldShowMenuBar)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = keepConnectedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = menuBarSettingObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appState = appStateProvider?() else { return .terminateNow }

        // If keepConnectedInBackground is already enabled, go to background mode
        if appState.keepConnectedInBackground {
            logger.info("Entering background mode (keepConnectedInBackground enabled)")
            appState.enterBackgroundMode()
            return .terminateCancel
        }

        // Only prompt if:
        // 1. A scanner was used in this session OR a scanner was used before (hasConnectedScanner)
        // 2. User hasn't disabled the prompt
        // 3. A scanner is currently connected or was connected this session
        let shouldPrompt = appState.shouldPromptForBackgroundConnection &&
                          (appState.didScanThisSession || appState.hasConnectedScanner) &&
                          (appState.scannerManager.connectionState.isConnected || appState.didScanThisSession)

        if !shouldPrompt {
            logger.info("Quitting without prompt (conditions not met)")
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "Keep ScanFlow Running?"
        alert.informativeText = """
        ScanFlow can stay connected to your scanner in the background. \
        When a document is placed in the scanner, ScanFlow will be ready to scan immediately.
        
        You can access ScanFlow from the menu bar when running in background mode.
        """
        alert.addButton(withTitle: "Keep Running")
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Don't Ask Again")
        
        // Add checkbox for "Also enable menu bar icon"
        let checkbox = NSButton(checkboxWithTitle: "Always show menu bar icon", target: nil, action: nil)
        checkbox.state = appState.menuBarAlwaysEnabled ? .on : .off
        alert.accessoryView = checkbox

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            appState.keepConnectedInBackground = true
            appState.shouldPromptForBackgroundConnection = false
            appState.autoStartScanWhenReady = true
            if checkbox.state == .on {
                appState.menuBarAlwaysEnabled = true
                NotificationCenter.default.post(name: .scanflowMenuBarSettingChanged, object: nil)
            }
            appState.handleKeepConnectedToggle(true)
            appState.enterBackgroundMode()
            logger.info("User chose to keep running in background")
            return .terminateCancel
        case .alertThirdButtonReturn:
            appState.shouldPromptForBackgroundConnection = false
            logger.info("User chose 'Don't Ask Again'")
            return .terminateNow
        default:
            logger.info("User chose to quit")
            return .terminateNow
        }
    }
}

extension Notification.Name {
    static let scanflowKeepConnectedChanged = Notification.Name("scanflow.keepConnectedChanged")
    static let scanflowMenuBarSettingChanged = Notification.Name("scanflow.menuBarSettingChanged")
}

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let appStateProvider: () -> AppState?
    private let menu: NSMenu
    private var statusMenuItem: NSMenuItem?

    init(appStateProvider: @escaping () -> AppState?) {
        self.appStateProvider = appStateProvider
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        super.init()
        configureStatusItem()
        configureMenu()
    }

    func setEnabled(_ enabled: Bool) {
        statusItem.isVisible = enabled
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "scanner", accessibilityDescription: "ScanFlow")
            button.imagePosition = .imageOnly
        }
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.delegate = self
        
        // Status header (disabled, shows scanner status)
        let statusItem = NSMenuItem(title: "ScanFlow", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        self.statusMenuItem = statusItem
        
        menu.items = [
            statusItem,
            NSMenuItem.separator(),
            NSMenuItem(title: "Open ScanFlow", action: #selector(openApp), keyEquivalent: "o"),
            NSMenuItem(title: "Start Scan", action: #selector(startScan), keyEquivalent: "s"),
            NSMenuItem(title: "Discover Scanners", action: #selector(discoverScanners), keyEquivalent: "d"),
            NSMenuItem.separator(),
            NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","),
            NSMenuItem.separator(),
            NSMenuItem(title: "Quit ScanFlow", action: #selector(quitApp), keyEquivalent: "q")
        ]
        for item in menu.items {
            item.target = self
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard let appState = appStateProvider() else { return }
        
        // Update status text
        if let statusItem = self.statusMenuItem {
            let isConnected = appState.scannerManager.connectionState.isConnected
            let scannerName = appState.scannerManager.selectedScanner?.name ?? "No scanner"
            
            if isConnected {
                statusItem.title = "✓ \(scannerName)"
            } else if appState.scannerManager.connectionState == .discovering {
                statusItem.title = "Searching for scanners..."
            } else {
                let count = appState.scannerManager.availableScanners.count
                if count > 0 {
                    statusItem.title = "\(count) scanner\(count == 1 ? "" : "s") available"
                } else {
                    statusItem.title = "No scanners found"
                }
            }
        }
        
        // Enable/disable scan button based on connection
        if let startScanItem = menu.items.first(where: { $0.action == #selector(startScan) }) {
            let canScan = appState.scannerManager.connectionState.isConnected || appState.useMockScanner
            startScanItem.isEnabled = canScan
            startScanItem.title = appState.isScanning ? "Scanning..." : "Start Scan"
        }
    }

    @objc private func openApp() {
        appStateProvider()?.exitBackgroundMode()
        bringAppToFront()
    }

    @objc private func startScan() {
        guard let appState = appStateProvider() else { return }
        Task {
            appState.addToQueue(preset: appState.currentPreset, count: 1)
            await appState.startScanning()
        }
    }

    @objc private func discoverScanners() {
        guard let appState = appStateProvider() else { return }
        Task {
            await appState.scannerManager.discoverScanners()
        }
    }

    @objc private func openSettings() {
        bringAppToFront()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quitApp() {
        guard let appState = appStateProvider() else {
            NSApp.terminate(nil)
            return
        }
        if appState.keepConnectedInBackground {
            appState.enterBackgroundMode()
            return
        }
        NSApp.terminate(nil)
    }

    private func bringAppToFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
#endif
