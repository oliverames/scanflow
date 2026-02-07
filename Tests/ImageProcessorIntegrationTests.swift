//
//  ImageProcessorIntegrationTests.swift
//  ScanFlowTests
//
//  Integration tests for the real ImageProcessor preset controls.
//

import Testing
import Foundation
#if os(macOS)
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
@testable import ScanFlow

@Suite("ImageProcessor Integration Tests")
struct ImageProcessorIntegrationTests {
    private let ciContext = CIContext()

    private func makeImage(size: NSSize = NSSize(width: 240, height: 240), fill: NSColor) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            fill.setFill()
            rect.fill()
            return true
        }
    }

    private func averageBrightness(_ image: NSImage) throws -> Double {
        guard let tiff = image.tiffRepresentation, let ciImage = CIImage(data: tiff) else {
            throw ImageProcessingError.invalidImage
        }
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent
        guard let output = filter.outputImage else {
            throw ImageProcessingError.processingFailed
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        )

        return Double(bitmap[0]) / 255.0
    }

    @Test("Invert colors preset control modifies output luminance")
    @MainActor
    func invertColorsChangesLuminance() async throws {
        let processor = ImageProcessor()
        let input = makeImage(fill: NSColor(white: 0.2, alpha: 1))

        var preset = ScanPreset(name: "Invert Test")
        preset.autoRotate = false
        preset.autoCrop = false
        preset.deskew = false
        preset.restoreColor = false
        preset.removeRedEye = false
        preset.mediaDetection = .none
        preset.invertColors = true

        let output = try await processor.process(input, with: preset)
        let inputBrightness = try averageBrightness(input)
        let outputBrightness = try averageBrightness(output)

        #expect(outputBrightness > inputBrightness + 0.1)
    }

    @Test("Brightness preset control increases output luminance")
    @MainActor
    func brightnessControlIncreasesLuminance() async throws {
        let processor = ImageProcessor()
        let input = makeImage(fill: NSColor(white: 0.35, alpha: 1))

        var preset = ScanPreset(name: "Brightness Test")
        preset.autoRotate = false
        preset.autoCrop = false
        preset.deskew = false
        preset.restoreColor = false
        preset.removeRedEye = false
        preset.mediaDetection = .none
        preset.brightness = 0.8

        let output = try await processor.process(input, with: preset)
        let inputBrightness = try averageBrightness(input)
        let outputBrightness = try averageBrightness(output)

        #expect(outputBrightness > inputBrightness + 0.05)
    }
}
#endif
