//
//  RemoteScanModels.swift
//  ScanFlow
//
//  Shared models and codec for remote scanning.
//

import Foundation

enum RemoteScanMessageType: String, Codable {
    case hello
    case scanRequest
    case scanResult
    case status
    case error
}

struct RemoteScanRequest: Codable {
    let presetName: String?
    let searchablePDF: Bool

    init(presetName: String?, searchablePDF: Bool) {
        self.presetName = presetName
        self.searchablePDF = searchablePDF
    }
}

struct RemoteScanDocument: Codable {
    let filename: String
    let pdfDataBase64: String
    let pageCount: Int
}

struct RemoteScanResult: Codable {
    let documents: [RemoteScanDocument]
    let scannedAt: Date
}

struct RemoteScanStatus: Codable {
    let message: String
}

struct RemoteScanError: Codable {
    let message: String
}

struct RemoteScanMessage: Codable {
    let type: RemoteScanMessageType
    let request: RemoteScanRequest?
    let result: RemoteScanResult?
    let status: RemoteScanStatus?
    let error: RemoteScanError?

    static func hello() -> RemoteScanMessage {
        RemoteScanMessage(type: .hello, request: nil, result: nil, status: nil, error: nil)
    }

    static func request(_ request: RemoteScanRequest) -> RemoteScanMessage {
        RemoteScanMessage(type: .scanRequest, request: request, result: nil, status: nil, error: nil)
    }

    static func result(_ result: RemoteScanResult) -> RemoteScanMessage {
        RemoteScanMessage(type: .scanResult, request: nil, result: result, status: nil, error: nil)
    }

    static func status(_ message: String) -> RemoteScanMessage {
        RemoteScanMessage(type: .status, request: nil, result: nil, status: RemoteScanStatus(message: message), error: nil)
    }

    static func error(_ message: String) -> RemoteScanMessage {
        RemoteScanMessage(type: .error, request: nil, result: nil, status: nil, error: RemoteScanError(message: message))
    }
}

struct RemoteScanCodec {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func encode(_ message: RemoteScanMessage) throws -> Data {
        let data = try encoder.encode(message)
        var framed = data
        framed.append(0x0A)
        return framed
    }

    mutating func decodeMessages(from buffer: inout Data) -> [RemoteScanMessage] {
        var messages: [RemoteScanMessage] = []

        while let newlineRange = buffer.firstRange(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
            buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)
            guard !lineData.isEmpty else { continue }

            if let message = try? decoder.decode(RemoteScanMessage.self, from: lineData) {
                messages.append(message)
            }
        }

        return messages
    }
}
