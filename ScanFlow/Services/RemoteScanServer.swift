//
//  RemoteScanServer.swift
//  ScanFlow
//
//  macOS scan server for remote scanning.
//

import Foundation
import Network
#if os(macOS)
import AppKit
import PDFKit
#endif

#if os(macOS)
@MainActor
final class RemoteScanServer {
    enum ServerError: LocalizedError {
        case alreadyRunning
        case serverUnavailable
        case busy

        var errorDescription: String? {
            switch self {
            case .alreadyRunning:
                return "Remote scan server is already running"
            case .serverUnavailable:
                return "Remote scan server is unavailable"
            case .busy:
                return "Scanner is currently busy"
            }
        }
    }

    private let queue = DispatchQueue(label: "com.scanflow.remotescan.server")
    private let scanHandler: (RemoteScanRequest) async throws -> RemoteScanResult
    private var listener: NWListener?
    private var activeConnections: [RemoteScanSession] = []

    private(set) var isRunning: Bool = false
    private(set) var lastError: String?

    init(scanHandler: @escaping (RemoteScanRequest) async throws -> RemoteScanResult) {
        self.scanHandler = scanHandler
    }

    func start() {
        guard listener == nil else { return }

        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: serviceName(), type: "_scanflow._tcp")
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerState(state)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }

            self.listener = listener
            listener.start(queue: queue)
            isRunning = true
        } catch {
            lastError = error.localizedDescription
            isRunning = false
        }
    }

    func stop() {
        activeConnections.forEach { $0.cancel() }
        activeConnections.removeAll()
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .failed(let error):
            lastError = error.localizedDescription
            stop()
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let session = RemoteScanSession(connection: connection, scanHandler: scanHandler)
        activeConnections.append(session)
        session.onClose = { [weak self] session in
            self?.activeConnections.removeAll { $0 === session }
        }
        session.start(queue: queue)
    }

    private func serviceName() -> String {
        Host.current().localizedName ?? "ScanFlow Mac"
    }
}

private final class RemoteScanSession {
    private let connection: NWConnection
    private var buffer = Data()
    private var codec = RemoteScanCodec()
    private let scanHandler: (RemoteScanRequest) async throws -> RemoteScanResult

    var onClose: ((RemoteScanSession) -> Void)?

    init(connection: NWConnection, scanHandler: @escaping (RemoteScanRequest) async throws -> RemoteScanResult) {
        self.connection = connection
        self.scanHandler = scanHandler
    }

    func start(queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                if let self {
                    self.onClose?(self)
                }
            default:
                break
            }
        }
        connection.start(queue: queue)
        send(.hello())
        receive()
    }

    func cancel() {
        connection.cancel()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, !data.isEmpty {
                buffer.append(data)
                let messages = codec.decodeMessages(from: &buffer)
                messages.forEach { handle($0) }
            }

            if isComplete || error != nil {
                connection.cancel()
                onClose?(self)
                return
            }

            receive()
        }
    }

    private func handle(_ message: RemoteScanMessage) {
        switch message.type {
        case .scanRequest:
            guard let request = message.request else { return }
            Task { @MainActor in
                await handleScanRequest(request)
            }
        default:
            break
        }
    }

    @MainActor
    private func handleScanRequest(_ request: RemoteScanRequest) async {
        send(.status("Starting scan"))
        do {
            let result = try await scanHandler(request)
            send(.result(result))
        } catch {
            send(.error(error.localizedDescription))
        }
    }

    private func send(_ message: RemoteScanMessage) {
        guard let data = try? codec.encode(message) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
}
#endif
