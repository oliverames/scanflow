//
//  AppLifecycleDelegate.swift
//  ScanFlow
//
//  Handles app termination prompts for background scanner connectivity.
//

#if os(macOS)
import AppKit

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    var appStateProvider: (() -> AppState)?
    private var statusBarController: StatusBarController?
    private var keepConnectedObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(appStateProvider: { [weak self] in
            self?.appStateProvider?()
        })
        statusBarController?.setEnabled(appStateProvider?().keepConnectedInBackground ?? false)

        keepConnectedObserver = NotificationCenter.default.addObserver(
            forName: .scanflowKeepConnectedChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let enabled = notification.userInfo?["enabled"] as? Bool else { return }
            Task { @MainActor in
                self?.statusBarController?.setEnabled(enabled)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let observer = keepConnectedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appState = appStateProvider?() else { return .terminateNow }

        if appState.keepConnectedInBackground {
            appState.enterBackgroundMode()
            return .terminateCancel
        }

        if !appState.hasConnectedScanner {
            return .terminateNow
        }

        if !appState.shouldPromptForBackgroundConnection {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "Keep ScanFlow connected in the background?"
        alert.informativeText = "ScanFlow can stay connected to your scanner so it's ready if documents are detected. This keeps the app running without an open window."
        alert.addButton(withTitle: "Keep Connected")
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Don't Ask Again")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            appState.keepConnectedInBackground = true
            appState.shouldPromptForBackgroundConnection = false
            appState.autoStartScanWhenReady = true
            appState.handleKeepConnectedToggle(true)
            appState.enterBackgroundMode()
            return .terminateCancel
        case .alertThirdButtonReturn:
            appState.shouldPromptForBackgroundConnection = false
            return .terminateNow
        default:
            return .terminateNow
        }
    }
}

extension Notification.Name {
    static let scanflowKeepConnectedChanged = Notification.Name("scanflow.keepConnectedChanged")
}

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let appStateProvider: () -> AppState?
    private let menu: NSMenu

    private let statusItemTitle = "ScanFlow"

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
            button.title = statusItemTitle
            button.image = NSImage(systemSymbolName: "scanner", accessibilityDescription: "ScanFlow")
            button.imagePosition = .imageLeading
        }
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.delegate = self
        menu.items = [
            NSMenuItem(title: "Open ScanFlow", action: #selector(openApp), keyEquivalent: ""),
            NSMenuItem(title: "Start Scan", action: #selector(startScan), keyEquivalent: ""),
            NSMenuItem(title: "Discover Scanners", action: #selector(discoverScanners), keyEquivalent: ""),
            NSMenuItem.separator(),
            NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","),
            NSMenuItem.separator(),
            NSMenuItem(title: "Quit ScanFlow", action: #selector(quitApp), keyEquivalent: "q")
        ]
        for item in menu.items {
            item.target = self
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard let appState = appStateProvider() else { return }
        if let startScanItem = menu.items.first(where: { $0.action == #selector(startScan) }) {
            startScanItem.isEnabled = appState.scannerManager.connectionState.isConnected || appState.useMockScanner
        }
        if let discoverItem = menu.items.first(where: { $0.action == #selector(discoverScanners) }) {
            discoverItem.isEnabled = true
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
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        bringAppToFront()
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
