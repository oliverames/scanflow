//
//  ModelsTests.swift
//  ScanFlowTests
//
//  Comprehensive tests for data models.
//

import Testing
import Foundation
@testable import ScanFlow

@Suite("QueuedScan Tests")
struct QueuedScanTests {

    @Test("QueuedScan default initialization")
    func queuedScanDefaults() {
        let preset = ScanPreset.quickScan
        let scan = QueuedScan(name: "Test Scan", preset: preset)

        #expect(scan.name == "Test Scan")
        #expect(scan.status == .pending)
        #expect(scan.progress == 0)
        #expect(scan.estimatedFileSize == nil)
        #expect(scan.thumbnailData == nil)
    }

    @Test("QueuedScan custom initialization")
    func queuedScanCustom() {
        let preset = ScanPreset.quickScan
        let scan = QueuedScan(
            name: "Custom Scan",
            preset: preset,
            status: .scanning,
            progress: 0.5,
            estimatedFileSize: 1024
        )

        #expect(scan.status == .scanning)
        #expect(scan.progress == 0.5)
        #expect(scan.estimatedFileSize == 1024)
    }

    @Test("QueuedScan is identifiable")
    func queuedScanIdentifiable() {
        let scan1 = QueuedScan(name: "Scan 1", preset: ScanPreset.quickScan)
        let scan2 = QueuedScan(name: "Scan 2", preset: ScanPreset.quickScan)

        #expect(scan1.id != scan2.id)
    }

    @Test("QueuedScan is Codable")
    func queuedScanCodable() throws {
        let scan = QueuedScan(
            name: "Codable Test",
            preset: ScanPreset.quickScan,
            status: .completed,
            progress: 1.0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(scan)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QueuedScan.self, from: data)

        #expect(decoded.name == scan.name)
        #expect(decoded.status == scan.status)
        #expect(decoded.progress == scan.progress)
    }
}

@Suite("ScanStatus Tests")
struct ScanStatusTests {

    @Test("ScanStatus descriptions are human readable")
    func scanStatusDescriptions() {
        #expect(ScanStatus.pending.description == "Pending")
        #expect(ScanStatus.scanning.description == "Scanning...")
        #expect(ScanStatus.processing.description == "Processing...")
        #expect(ScanStatus.completed.description == "Completed")
        #expect(ScanStatus.failed("Test error").description == "Failed: Test error")
    }

    @Test("ScanStatus equality")
    func scanStatusEquality() {
        #expect(ScanStatus.pending == ScanStatus.pending)
        #expect(ScanStatus.scanning == ScanStatus.scanning)
        #expect(ScanStatus.pending != ScanStatus.scanning)
        #expect(ScanStatus.failed("Error 1") == ScanStatus.failed("Error 1"))
        #expect(ScanStatus.failed("Error 1") != ScanStatus.failed("Error 2"))
    }

    @Test("ScanStatus is Codable")
    func scanStatusCodable() throws {
        let statuses: [ScanStatus] = [
            .pending,
            .scanning,
            .processing,
            .completed,
            .failed("Test error")
        ]

        for status in statuses {
            let encoder = JSONEncoder()
            let data = try encoder.encode(status)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ScanStatus.self, from: data)

            #expect(decoded == status)
        }
    }
}

@Suite("ScannedFile Tests")
struct ScannedFileTests {

    @Test("ScannedFile initialization")
    func scannedFileInit() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let file = ScannedFile(
            filename: "test.pdf",
            fileURL: url,
            size: 1024 * 1024,  // 1MB
            resolution: 300,
            scannerModel: "Test Scanner",
            format: .pdf
        )

        #expect(file.filename == "test.pdf")
        #expect(file.fileURL == url)
        #expect(file.size == 1024 * 1024)
        #expect(file.resolution == 300)
        #expect(file.scannerModel == "Test Scanner")
        #expect(file.format == .pdf)
    }

    @Test("ScannedFile formatted size")
    func scannedFileFormattedSize() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")

        let smallFile = ScannedFile(
            filename: "small.pdf",
            fileURL: url,
            size: 1024,  // 1KB
            resolution: 300,
            scannerModel: "Scanner",
            format: .pdf
        )
        #expect(smallFile.formattedSize.contains("KB") || smallFile.formattedSize.contains("bytes"))

        let largeFile = ScannedFile(
            filename: "large.pdf",
            fileURL: url,
            size: 1024 * 1024 * 5,  // 5MB
            resolution: 300,
            scannerModel: "Scanner",
            format: .pdf
        )
        #expect(largeFile.formattedSize.contains("MB"))
    }

    @Test("ScannedFile formatted date")
    func scannedFileFormattedDate() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let file = ScannedFile(
            filename: "test.pdf",
            fileURL: url,
            size: 1024,
            resolution: 300,
            dateScanned: Date(),
            scannerModel: "Scanner",
            format: .pdf
        )

        // The formatted date should not be empty
        #expect(!file.formattedDate.isEmpty)
    }

    @Test("ScannedFile is Codable")
    func scannedFileCodable() throws {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let file = ScannedFile(
            filename: "test.pdf",
            fileURL: url,
            size: 2048,
            resolution: 600,
            scannerModel: "Test Scanner",
            format: .jpeg
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(file)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScannedFile.self, from: data)

        #expect(decoded.filename == file.filename)
        #expect(decoded.size == file.size)
        #expect(decoded.resolution == file.resolution)
        #expect(decoded.format == file.format)
    }
}

@Suite("ScanMetadata Tests")
struct ScanMetadataTests {

    @Test("ScanMetadata default initialization")
    func scanMetadataDefaults() {
        let metadata = ScanMetadata(
            resolution: 300,
            scannerModel: "Test Scanner"
        )

        #expect(metadata.resolution == 300)
        #expect(metadata.colorSpace == "sRGB")
        #expect(metadata.scannerModel == "Test Scanner")
        #expect(metadata.width == nil)
        #expect(metadata.height == nil)
        #expect(metadata.bitDepth == nil)
    }

    @Test("ScanMetadata full initialization")
    func scanMetadataFull() {
        let metadata = ScanMetadata(
            resolution: 600,
            colorSpace: "Adobe RGB",
            scannerModel: "Pro Scanner",
            width: 2550,
            height: 3300,
            bitDepth: 16
        )

        #expect(metadata.resolution == 600)
        #expect(metadata.colorSpace == "Adobe RGB")
        #expect(metadata.width == 2550)
        #expect(metadata.height == 3300)
        #expect(metadata.bitDepth == 16)
    }

    @Test("ScanMetadata is Codable")
    func scanMetadataCodable() throws {
        let metadata = ScanMetadata(
            resolution: 300,
            colorSpace: "sRGB",
            scannerModel: "Scanner",
            width: 1700,
            height: 2200,
            bitDepth: 8
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ScanMetadata.self, from: data)

        #expect(decoded.resolution == metadata.resolution)
        #expect(decoded.colorSpace == metadata.colorSpace)
        #expect(decoded.width == metadata.width)
        #expect(decoded.height == metadata.height)
        #expect(decoded.bitDepth == metadata.bitDepth)
    }
}
