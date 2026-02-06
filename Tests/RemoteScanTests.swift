//
//  RemoteScanTests.swift
//  ScanFlowTests
//
//  Comprehensive tests for remote scanning models, codec, and communication.
//

import Testing
import Foundation
@testable import ScanFlow

@Suite("RemoteScanModels Tests")
struct RemoteScanModelsTests {

    // MARK: - RemoteScanRequest Tests

    @Test("RemoteScanRequest custom initialization")
    func remoteScanRequestCustom() {
        let request = RemoteScanRequest(
            presetName: "High Quality PDF",
            searchablePDF: true,
            forceSingleDocument: true
        )

        #expect(request.presetName == "High Quality PDF")
        #expect(request.searchablePDF == true)
        #expect(request.forceSingleDocument == true)
    }

    @Test("RemoteScanRequest with nil preset name")
    func remoteScanRequestNilPreset() {
        let request = RemoteScanRequest(
            presetName: nil,
            searchablePDF: false,
            forceSingleDocument: false
        )

        #expect(request.presetName == nil)
        #expect(request.searchablePDF == false)
        #expect(request.forceSingleDocument == false)
    }

    @Test("RemoteScanRequest is Codable")
    func remoteScanRequestCodable() throws {
        let request = RemoteScanRequest(
            presetName: "Test Preset",
            searchablePDF: true,
            forceSingleDocument: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RemoteScanRequest.self, from: data)

        #expect(decoded.presetName == request.presetName)
        #expect(decoded.searchablePDF == request.searchablePDF)
        #expect(decoded.forceSingleDocument == request.forceSingleDocument)
    }

    // MARK: - RemoteScanResult Tests

    @Test("RemoteScanResult with documents")
    func remoteScanResultWithDocuments() {
        let document = RemoteScanDocument(
            filename: "Scan001.pdf",
            pdfDataBase64: "SGVsbG8gV29ybGQ=",  // "Hello World" in base64
            pageCount: 3,
            byteCount: 1024
        )

        let result = RemoteScanResult(
            documents: [document],
            totalBytes: 1024,
            scannedAt: Date()
        )

        #expect(result.documents.count == 1)
        #expect(result.totalBytes == 1024)
        #expect(result.documents.first?.filename == "Scan001.pdf")
        #expect(result.documents.first?.pageCount == 3)
    }

    @Test("RemoteScanResult is Codable")
    func remoteScanResultCodable() throws {
        let document = RemoteScanDocument(
            filename: "Test.pdf",
            pdfDataBase64: "dGVzdA==",
            pageCount: 1,
            byteCount: 100
        )

        let result = RemoteScanResult(
            documents: [document],
            totalBytes: 100,
            scannedAt: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(result)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RemoteScanResult.self, from: data)

        #expect(decoded.documents.count == result.documents.count)
        #expect(decoded.totalBytes == result.totalBytes)
    }

    // MARK: - RemoteScanDocument Tests

    @Test("RemoteScanDocument properties")
    func remoteScanDocumentProperties() {
        let document = RemoteScanDocument(
            filename: "Invoice_2024.pdf",
            pdfDataBase64: "YmFzZTY0ZGF0YQ==",
            pageCount: 5,
            byteCount: 50000
        )

        #expect(document.filename == "Invoice_2024.pdf")
        #expect(document.pageCount == 5)
        #expect(document.byteCount == 50000)
        #expect(document.pdfDataBase64.isEmpty == false)
    }

    @Test("RemoteScanDocument base64 decoding")
    func remoteScanDocumentBase64Decoding() {
        // "Hello PDF" encoded in base64
        let base64 = "SGVsbG8gUERG"
        let document = RemoteScanDocument(
            filename: "test.pdf",
            pdfDataBase64: base64,
            pageCount: 1,
            byteCount: 9
        )

        let decodedData = Data(base64Encoded: document.pdfDataBase64)
        #expect(decodedData != nil)

        if let data = decodedData, let string = String(data: data, encoding: .utf8) {
            #expect(string == "Hello PDF")
        }
    }
}

@Suite("RemoteScanCodec Extended Tests")
struct RemoteScanCodecExtendedTests {

    @Test("Codec encodes and decodes request messages")
    func codecRequestRoundTrip() throws {
        var codec = RemoteScanCodec()

        let request = RemoteScanRequest(
            presetName: "Color PDF",
            searchablePDF: true,
            forceSingleDocument: false
        )

        let message = RemoteScanMessage.request(request)
        var encoded = try codec.encode(message)

        let decoded = codec.decodeMessages(from: &encoded)

        #expect(decoded.count == 1)
        if let first = decoded.first, let decodedRequest = first.request {
            #expect(decodedRequest.presetName == request.presetName)
            #expect(decodedRequest.searchablePDF == request.searchablePDF)
        } else {
            Issue.record("Expected request message type")
        }
    }

    @Test("Codec encodes and decodes result messages")
    func codecResultRoundTrip() throws {
        var codec = RemoteScanCodec()

        let document = RemoteScanDocument(
            filename: "doc.pdf",
            pdfDataBase64: "dGVzdA==",
            pageCount: 2,
            byteCount: 200
        )

        let result = RemoteScanResult(
            documents: [document],
            totalBytes: 200,
            scannedAt: Date()
        )

        let message = RemoteScanMessage.result(result)
        var encoded = try codec.encode(message)

        let decoded = codec.decodeMessages(from: &encoded)

        #expect(decoded.count == 1)
        if let first = decoded.first, let decodedResult = first.result {
            #expect(decodedResult.documents.count == 1)
            #expect(decodedResult.totalBytes == 200)
        } else {
            Issue.record("Expected result message type")
        }
    }

    @Test("Codec encodes and decodes error messages")
    func codecErrorRoundTrip() throws {
        var codec = RemoteScanCodec()

        let message = RemoteScanMessage.error("Scanner not connected")
        var encoded = try codec.encode(message)

        let decoded = codec.decodeMessages(from: &encoded)

        #expect(decoded.count == 1)
        if let first = decoded.first, let errorMsg = first.error {
            #expect(errorMsg.message == "Scanner not connected")
        } else {
            Issue.record("Expected error message type")
        }
    }

    @Test("Codec handles large payloads")
    func codecLargePayload() throws {
        var codec = RemoteScanCodec()

        // Create a large base64 string (simulating a PDF)
        let largeData = Data(repeating: 0x41, count: 100_000) // 100KB of 'A's
        let largeBase64 = largeData.base64EncodedString()

        let document = RemoteScanDocument(
            filename: "large.pdf",
            pdfDataBase64: largeBase64,
            pageCount: 50,
            byteCount: 100_000
        )

        let result = RemoteScanResult(
            documents: [document],
            totalBytes: 100_000,
            scannedAt: Date()
        )

        let message = RemoteScanMessage.result(result)
        var encoded = try codec.encode(message)

        // Should be able to decode without issues
        let decoded = codec.decodeMessages(from: &encoded)

        #expect(decoded.count == 1)
        if let first = decoded.first, let decodedResult = first.result {
            #expect(decodedResult.documents.first?.byteCount == 100_000)
        } else {
            Issue.record("Expected result message type")
        }
    }

    @Test("Codec handles multiple documents")
    func codecMultipleDocuments() throws {
        var codec = RemoteScanCodec()

        let documents = (1...5).map { index in
            RemoteScanDocument(
                filename: "doc\(index).pdf",
                pdfDataBase64: "dGVzdA==",
                pageCount: index,
                byteCount: index * 100
            )
        }

        let result = RemoteScanResult(
            documents: documents,
            totalBytes: documents.reduce(0) { $0 + $1.byteCount },
            scannedAt: Date()
        )

        let message = RemoteScanMessage.result(result)
        var encoded = try codec.encode(message)
        let decoded = codec.decodeMessages(from: &encoded)

        #expect(decoded.count == 1)
        if let first = decoded.first, let decodedResult = first.result {
            #expect(decodedResult.documents.count == 5)
        } else {
            Issue.record("Expected result message type")
        }
    }
}
