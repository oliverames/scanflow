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
    enum RemoteScanClientError: LocalizedError {
        case notConnected
        case busy
        case timeout
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Not connected to a ScanFlow server"
            case .busy:
                return "Remote scan already in progress"
            case .timeout:
                return "Remote scan timed out"
            case .serverError(let message):
                return message
            }
        }
    }

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

    init() {}

    private let queue = DispatchQueue(label: "com.scanflow.remotescan.client")
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var buffer = Data()
    private var codec = RemoteScanCodec()
    private var scanContinuation: CheckedContinuation<RemoteScanResult, Error>?

    var availableServices: [RemoteScanService] = []
    var selectedService: RemoteScanService?
    var connectionState: ConnectionState = .disconnected
    var statusMessage: String?
    var lastError: String?
    var isScanning: Bool = false
    var bytesReceived: Int = 0
    var expectedBytes: Int?

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
        if let continuation = scanContinuation {
            scanContinuation = nil
            continuation.resume(throwing: RemoteScanClientError.notConnected)
        }
        connectionState = .disconnected
        statusMessage = nil
        isScanning = false
        bytesReceived = 0
        expectedBytes = nil
    }

    func requestScan(
        presetName: String?,
        searchablePDF: Bool,
        forceSingleDocument: Bool,
        pairingToken: String?
    ) {
        guard connectionState == .connected else { return }
        if isScanning { return }
        isScanning = true
        bytesReceived = 0
        expectedBytes = nil
        lastError = nil
        statusMessage = "Requesting scan"
        let request = RemoteScanRequest(
            presetName: presetName,
            searchablePDF: searchablePDF,
            forceSingleDocument: forceSingleDocument,
            pairingToken: pairingToken
        )
        send(.request(request))
    }

    func performScan(
        presetName: String?,
        searchablePDF: Bool,
        forceSingleDocument: Bool,
        pairingToken: String?,
        timeoutSeconds: Int = 180
    ) async throws -> RemoteScanResult {
        guard connectionState == .connected else { throw RemoteScanClientError.notConnected }
        guard !isScanning else { throw RemoteScanClientError.busy }

        return try await withThrowingTaskGroup(of: RemoteScanResult.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RemoteScanResult, Error>) in
                    self.scanContinuation = continuation
                    self.requestScan(
                        presetName: presetName,
                        searchablePDF: searchablePDF,
                        forceSingleDocument: forceSingleDocument,
                        pairingToken: pairingToken
                    )
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(max(30, timeoutSeconds)))
                throw RemoteScanClientError.timeout
            }

            guard let result = try await group.next() else {
                throw RemoteScanClientError.timeout
            }
            group.cancelAll()
            return result
        }
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
        if selectedService == nil, let first = availableServices.first {
            selectedService = first
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
                Task { @MainActor in
                    self.handleIncomingData(data)
                }
            }

            if isComplete || error != nil {
                Task { @MainActor in
                    self.disconnect()
                }
                return
            }

            Task { @MainActor in
                self.receive()
            }
        }
    }

    @MainActor
    private func handleIncomingData(_ data: Data) {
        bytesReceived += data.count
        buffer.append(data)
        let messages = codec.decodeMessages(from: &buffer)
        messages.forEach { handle($0) }
    }

    private func handle(_ message: RemoteScanMessage) {
        switch message.type {
        case .status:
            statusMessage = message.status?.message
        case .scanResult:
            if let result = message.result {
                expectedBytes = result.totalBytes
                isScanning = false
                if let continuation = scanContinuation {
                    scanContinuation = nil
                    continuation.resume(returning: result)
                }
                onScanResult?(result)
            }
        case .error:
            isScanning = false
            let messageText = message.error?.message
            lastError = messageText
            if let continuation = scanContinuation {
                scanContinuation = nil
                continuation.resume(throwing: RemoteScanClientError.serverError(messageText ?? "Remote scan failed"))
            }
        default:
            break
        }
    }

    private func send(_ message: RemoteScanMessage) {
        guard let data = try? codec.encode(message) else { return }
        connection?.send(content: data, completion: .contentProcessed { _ in })
    }
}
