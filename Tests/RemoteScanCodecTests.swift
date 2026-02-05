//
//  RemoteScanCodecTests.swift
//  ScanFlowTests
//
//  Tests for remote scan message encoding/decoding.
//

import Testing
import Foundation
@testable import ScanFlow

@Suite("RemoteScanCodec Tests")
struct RemoteScanCodecTests {
    @Test("Encodes and decodes a scan request with split flag")
    func encodeDecodeRequest() throws {
        var codec = RemoteScanCodec()
        let request = RemoteScanRequest(presetName: "Searchable PDF", searchablePDF: true, forceSingleDocument: true)
        let message = RemoteScanMessage.request(request)

        let data = try codec.encode(message)
        var buffer = data
        let decoded = codec.decodeMessages(from: &buffer)

        #expect(decoded.count == 1)
        #expect(decoded.first?.request?.forceSingleDocument == true)
    }

    @Test("Encodes and decodes a scan result")
    func encodeDecodeResult() throws {
        var codec = RemoteScanCodec()
        let doc = RemoteScanDocument(filename: "Doc-001.pdf", pdfDataBase64: "abc", pageCount: 2, byteCount: 1234)
        let result = RemoteScanResult(documents: [doc], totalBytes: 1234, scannedAt: Date())
        let message = RemoteScanMessage.result(result)

        let data = try codec.encode(message)
        var buffer = data
        let decoded = codec.decodeMessages(from: &buffer)

        #expect(decoded.count == 1)
        #expect(decoded.first?.result?.documents.first?.byteCount == 1234)
    }
}
