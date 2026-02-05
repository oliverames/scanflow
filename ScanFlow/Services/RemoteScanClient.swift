//
//  RemoteScanClient.swift
//  ScanFlow
//
//  iOS client for discovering and connecting to remote scan servers.
//

import Foundation
import Network

@MainActor
@Observable
final class RemoteScanClient {
    enum ConnectionState: String {
        case disconnected
        case connecting
        case connected
        case browsing
    }

    struct RemoteScanService: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let endpoint: NWEndpoint
    }

    private let queue = DispatchQueue(label: "com.scanflow.remotescan.client")
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var buffer = Data()
    private var codec = RemoteScanCodec()

    var availableServices: [RemoteScanService] = []
    var selectedService: RemoteScanService?
    var connectionState: ConnectionState = .disconnected
    var statusMessage: String?
    var lastError: String?
    var isScanning: Bool = false

    var onScanResult: ((RemoteScanResult) -> Void)?

    func startBrowsing() {
        guard browser == nil else { return }
        let parameters = NWParameters.tcp
        let browser = NWBrowser(for: .bonjour(type: "_scanflow._tcp", domain: nil), using: parameters)
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleBrowserState(state)
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.updateServices(from: results)
            }
        }
        self.browser = browser
        browser.start(queue: queue)
        connectionState = .browsing
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        if connectionState == .browsing {
            connectionState = .disconnected
        }
    }

    func connect(to service: RemoteScanService) {
        disconnect()
        selectedService = service
        let connection = NWConnection(to: service.endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionState(state)
            }
        }
        self.connection = connection
        connection.start(queue: queue)
        connectionState = .connecting
        receive()
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        buffer.removeAll()
        connectionState = .disconnected
        statusMessage = nil
        isScanning = false
    }

    func requestScan(presetName: String?, searchablePDF: Bool) {
        guard connectionState == .connected else { return }
        isScanning = true
        let request = RemoteScanRequest(presetName: presetName, searchablePDF: searchablePDF)
        send(.request(request))
    }

    private func updateServices(from results: Set<NWBrowser.Result>) {
        let services = results.compactMap { result -> RemoteScanService? in
            switch result.endpoint {
            case .service(let name, _, _, _):
                return RemoteScanService(name: name, endpoint: result.endpoint)
            default:
                return nil
            }
        }
        availableServices = services.sorted { $0.name < $1.name }
        if let selected = selectedService, !availableServices.contains(selected) {
            selectedService = nil
        }
    }

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .failed(let error):
            lastError = error.localizedDescription
            stopBrowsing()
        default:
            break
        }
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connectionState = .connected
            send(.hello())
        case .failed(let error):
            lastError = error.localizedDescription
            disconnect()
        case .cancelled:
            disconnect()
        default:
            break
        }
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                buffer.append(data)
                let messages = codec.decodeMessages(from: &buffer)
                messages.forEach { handle($0) }
            }

            if isComplete || error != nil {
                Task { @MainActor in
                    self.disconnect()
                }
                return
            }

            receive()
        }
    }

    private func handle(_ message: RemoteScanMessage) {
        switch message.type {
        case .status:
            statusMessage = message.status?.message
        case .scanResult:
            if let result = message.result {
                isScanning = false
                onScanResult?(result)
            }
        case .error:
            isScanning = false
            lastError = message.error?.message
        default:
            break
        }
    }

    private func send(_ message: RemoteScanMessage) {
        guard let data = try? codec.encode(message) else { return }
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }
}
