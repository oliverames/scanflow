//
//  AppStateScanningTests.swift
//  ScanFlowTests
//
//  Queue scanning behavior tests using protocol-driven fake scanner executors.
//

import Testing
import Foundation
#if os(macOS)
import AppKit
#endif
@testable import ScanFlow

#if os(macOS)
@MainActor
private final class FakeScanExecutor: ScanExecuting {
    var scriptedResults: [Result<ScanResult, Error>]
    private(set) var callCount = 0

    init(scriptedResults: [Result<ScanResult, Error>]) {
        self.scriptedResults = scriptedResults
    }

    func scan(with preset: ScanPreset) async throws -> ScanResult {
        let index = callCount
        callCount += 1
        guard index < scriptedResults.count else {
            throw ScannerError.scanFailed
        }
        return try scriptedResults[index].get()
    }
}

@MainActor
private func sampleScanResult() -> ScanResult {
    let imageSize = NSSize(width: 180, height: 240)
    let image = makeImage(size: imageSize, fill: NSColor(white: 0.35, alpha: 1))
    return sampleScanResult(images: [image])
}

@MainActor
private func sampleScanResult(images: [NSImage]) -> ScanResult {
    let metadata = ScanMetadata(resolution: 300, scannerModel: "Fake Scanner")
    return ScanResult(images: images, metadata: metadata)
}

@MainActor
private func makeImage(size: NSSize, fill: NSColor) -> NSImage {
    NSImage(size: size, flipped: false) { rect in
        fill.setFill()
        rect.fill()
        return true
    }
}

@Suite("AppState Scanning Recovery Tests")
struct AppStateScanningRecoveryTests {
    @Test("Retries transient errors and completes scan")
    @MainActor
    func retriesTransientErrorsAndCompletes() async throws {
        let executor = FakeScanExecutor(scriptedResults: [
            .failure(ScannerError.scanTimeout),
            .success(sampleScanResult())
        ])
        let appState = AppState(scanExecutor: executor)

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanFlow-Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }

        var preset = appState.currentPreset
        preset.destination = destination.path
        preset.format = .png
        appState.addToQueue(preset: preset, count: 1)

        await appState.startScanning()

        #expect(executor.callCount == 2)
        #expect(appState.scanQueue.count == 1)
        #expect(appState.scannedFiles.count == 1)
        #expect(appState.scanQueue.first?.status == .completed)
    }

    @Test("Non-transient failure does not block later queue items")
    @MainActor
    func nonTransientFailureAllowsQueueProgress() async throws {
        let executor = FakeScanExecutor(scriptedResults: [
            .failure(ScannerError.noFunctionalUnit),
            .success(sampleScanResult())
        ])
        let appState = AppState(scanExecutor: executor)

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanFlow-Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }

        var preset = appState.currentPreset
        preset.destination = destination.path
        preset.format = .png
        appState.addToQueue(preset: preset, count: 2)

        await appState.startScanning()

        #expect(executor.callCount == 2)
        #expect(appState.scanQueue.count == 2)

        if case .failed = appState.scanQueue[0].status {
            // expected
        } else {
            Issue.record("Expected first queue item to fail")
        }

        #expect(appState.scanQueue[1].status == .completed)
        #expect(appState.scannedFiles.count == 1)
    }

    @Test("Blank pages are removed when blank handling is delete")
    @MainActor
    func blankPagesAreRemovedForDeleteMode() async throws {
        let blank = makeImage(size: NSSize(width: 240, height: 320), fill: NSColor.white)
        let content = makeImage(size: NSSize(width: 240, height: 320), fill: NSColor(white: 0.2, alpha: 1))
        let executor = FakeScanExecutor(scriptedResults: [
            .success(sampleScanResult(images: [blank, content]))
        ])
        let appState = AppState(scanExecutor: executor)

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanFlow-Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }

        var preset = appState.currentPreset
        preset.destination = destination.path
        preset.format = .png
        preset.autoRotate = false
        preset.autoCrop = false
        preset.deskew = false
        preset.blankPageHandling = .delete
        preset.blankPageSensitivity = 0.5

        appState.addToQueue(preset: preset, count: 1)
        await appState.startScanning()

        #expect(executor.callCount == 1)
        #expect(appState.scanQueue.first?.status == .completed)
        #expect(appState.scannedFiles.count == 1)
    }

    @Test("Split book pages creates two output pages for a single source page")
    @MainActor
    func splitBookPagesCreatesTwoOutputs() async throws {
        let spread = makeImage(size: NSSize(width: 600, height: 320), fill: NSColor(white: 0.7, alpha: 1))
        let executor = FakeScanExecutor(scriptedResults: [
            .success(sampleScanResult(images: [spread]))
        ])
        let appState = AppState(scanExecutor: executor)

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanFlow-Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }

        var preset = appState.currentPreset
        preset.destination = destination.path
        preset.format = .png
        preset.autoRotate = false
        preset.autoCrop = false
        preset.deskew = false
        preset.splitBookPages = true
        preset.blankPageHandling = .keep

        appState.addToQueue(preset: preset, count: 1)
        await appState.startScanning()

        #expect(executor.callCount == 1)
        #expect(appState.scanQueue.first?.status == .completed)
        #expect(appState.scannedFiles.count == 2)
    }
}
#endif
