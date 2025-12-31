//
//  ImageProcessor.swift
//  ScanFlow
//
//  Advanced image processing pipeline using Core Image and Vision
//  Provides ExactScan-level capabilities for scanned documents and photos
//

import Foundation
#if os(macOS)
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
#endif

#if os(macOS)

/// Comprehensive image processing for scanned documents and photos
@MainActor
class ImageProcessor {

    private let context: CIContext

    init() {
        // Create high-quality processing context
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ]
        context = CIContext(options: options)
    }

    // MARK: - Main Processing Pipeline

    /// Process image with preset settings
    func process(_ image: NSImage, with preset: ScanPreset) async throws -> NSImage {
        guard let ciImage = CIImage(data: image.tiffRepresentation!) else {
            throw ImageProcessingError.invalidImage
        }

        var processedImage = ciImage

        // 1. Auto-rotate if enabled
        if preset.autoRotate {
            processedImage = try await detectAndCorrectOrientation(processedImage)
        }

        // 2. Deskew if enabled
        if preset.deskew {
            processedImage = try await detectAndCorrectSkew(processedImage)
        }

        // 3. Color restoration if enabled
        if preset.restoreColor {
            processedImage = enhanceColors(processedImage)
        }

        // 4. Auto-enhancement if enabled
        if preset.autoEnhance {
            processedImage = autoEnhance(processedImage)
        }

        // 5. Red-eye removal if enabled
        if preset.removeRedEye {
            processedImage = try await removeRedEyes(processedImage)
        }

        // Convert back to NSImage
        return try renderImage(processedImage)
    }

    // MARK: - Auto-Rotation

    /// Detect and correct image orientation using Vision
    func detectAndCorrectOrientation(_ image: CIImage) async throws -> CIImage {
        let request = VNDetectHorizonRequest()

        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return image
        }

        let angle = observation.angle

        // Only rotate if angle is significant (> 0.5 degrees)
        guard abs(angle) > 0.008726646 else { return image }

        let transform = CGAffineTransform(rotationAngle: angle)
        return image.transformed(by: transform)
    }

    // MARK: - Deskewing

    /// Detect and correct document skew using rectangle detection
    func detectAndCorrectSkew(_ image: CIImage) async throws -> CIImage {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.5
        request.minimumConfidence = 0.6

        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return image
        }

        // Calculate perspective correction
        let topLeft = observation.topLeft
        let topRight = observation.topRight
        let bottomLeft = observation.bottomLeft
        let bottomRight = observation.bottomRight

        // Convert normalized coordinates to image coordinates
        let imageSize = image.extent.size

        let correctedTopLeft = CGPoint(x: topLeft.x * imageSize.width, y: topLeft.y * imageSize.height)
        let correctedTopRight = CGPoint(x: topRight.x * imageSize.width, y: topRight.y * imageSize.height)
        let correctedBottomLeft = CGPoint(x: bottomLeft.x * imageSize.width, y: bottomLeft.y * imageSize.height)
        let correctedBottomRight = CGPoint(x: bottomRight.x * imageSize.width, y: bottomRight.y * imageSize.height)

        // Apply perspective correction
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = image
        filter.topLeft = correctedTopLeft
        filter.topRight = correctedTopRight
        filter.bottomLeft = correctedBottomLeft
        filter.bottomRight = correctedBottomRight

        return filter.outputImage ?? image
    }

    // MARK: - Color Enhancement

    /// Enhance and restore faded colors
    func enhanceColors(_ image: CIImage) -> CIImage {
        var enhanced = image

        // 1. Vibrance boost (gentle saturation increase)
        let vibrance = CIFilter.vibrance()
        vibrance.inputImage = enhanced
        vibrance.amount = 0.3
        enhanced = vibrance.outputImage ?? enhanced

        // 2. Color controls for faded photo restoration
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = enhanced
        colorControls.saturation = 1.2
        colorControls.brightness = 0.05
        colorControls.contrast = 1.1
        enhanced = colorControls.outputImage ?? enhanced

        // 3. Exposure adjustment
        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = enhanced
        exposure.ev = 0.15
        enhanced = exposure.outputImage ?? enhanced

        return enhanced
    }

    // MARK: - Auto-Enhancement

    /// Automatic image enhancement
    func autoEnhance(_ image: CIImage) -> CIImage {
        let filters = image.autoAdjustmentFilters(options: [
            .enhance: true,
            .redEye: false // We handle red-eye separately
        ])

        var enhanced = image
        for filter in filters {
            filter.setValue(enhanced, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                enhanced = output
            }
        }

        return enhanced
    }

    // MARK: - Red-Eye Removal

    /// Detect and remove red-eye using Vision
    func removeRedEyes(_ image: CIImage) async throws -> CIImage {
        let request = VNDetectFaceRectanglesRequest()

        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            return image
        }

        var corrected = image
        let imageSize = image.extent.size

        for face in observations {
            // Convert normalized face rectangle to image coordinates
            let boundingBox = face.boundingBox
            let faceRect = CGRect(
                x: boundingBox.origin.x * imageSize.width,
                y: boundingBox.origin.y * imageSize.height,
                width: boundingBox.size.width * imageSize.width,
                height: boundingBox.size.height * imageSize.height
            )

            // Apply red-eye correction using CIRedEyeCorrection filter
            guard let redEyeFilter = CIFilter(name: "CIRedEyeCorrection") else {
                continue
            }

            redEyeFilter.setValue(corrected, forKey: kCIInputImageKey)
            redEyeFilter.setValue(CIVector(cgRect: faceRect), forKey: "inputCorrectionInfo")

            if let output = redEyeFilter.outputImage {
                corrected = output
            }
        }

        return corrected
    }

    // MARK: - Blank Page Detection

    /// Detect if a scanned page is blank or nearly blank
    func isBlankPage(_ image: NSImage, threshold: Double = 0.98) async -> Bool {
        guard let ciImage = CIImage(data: image.tiffRepresentation!) else {
            return false
        }

        // Calculate average brightness
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent

        guard let outputImage = filter.outputImage else { return false }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)

        let brightness = Double(bitmap[0]) / 255.0

        // If brightness is very high, page is likely blank
        return brightness > threshold
    }

    // MARK: - Paper Size Detection

    /// Detect paper size from scanned image
    func detectPaperSize(_ image: NSImage) async -> PaperSize {
        let size = image.size
        let widthInches = size.width / 72.0 // Convert points to inches
        let heightInches = size.height / 72.0

        // Common photo and document sizes (with tolerance)
        let tolerance = 0.5

        // Photo sizes
        if abs(widthInches - 4.0) < tolerance && abs(heightInches - 6.0) < tolerance {
            return .photo4x6
        }
        if abs(widthInches - 5.0) < tolerance && abs(heightInches - 7.0) < tolerance {
            return .photo5x7
        }
        if abs(widthInches - 8.0) < tolerance && abs(heightInches - 10.0) < tolerance {
            return .photo8x10
        }

        // Document sizes
        if abs(widthInches - 8.5) < tolerance && abs(heightInches - 11.0) < tolerance {
            return .letter
        }
        if abs(widthInches - 8.27) < tolerance && abs(heightInches - 11.69) < tolerance {
            return .a4
        }

        return .custom(width: widthInches, height: heightInches)
    }

    // MARK: - OCR

    /// Extract text from image using Vision OCR
    func recognizeText(_ image: NSImage) async throws -> String {
        guard let ciImage = CIImage(data: image.tiffRepresentation!) else {
            throw ImageProcessingError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return ""
        }

        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        return recognizedStrings.joined(separator: "\n")
    }

    // MARK: - Utilities

    /// Render CIImage to NSImage
    private func renderImage(_ ciImage: CIImage) throws -> NSImage {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw ImageProcessingError.renderFailed
        }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: size)

        return image
    }
}

// MARK: - Paper Sizes

enum PaperSize: Equatable {
    case photo4x6
    case photo5x7
    case photo8x10
    case letter      // 8.5" x 11"
    case a4          // 8.27" x 11.69"
    case custom(width: Double, height: Double)

    var description: String {
        switch self {
        case .photo4x6: return "4\" × 6\" Photo"
        case .photo5x7: return "5\" × 7\" Photo"
        case .photo8x10: return "8\" × 10\" Photo"
        case .letter: return "Letter (8.5\" × 11\")"
        case .a4: return "A4 (8.27\" × 11.69\")"
        case .custom(let width, let height):
            return String(format: "%.2f\" × %.2f\"", width, height)
        }
    }
}

// MARK: - Errors

enum ImageProcessingError: LocalizedError {
    case invalidImage
    case renderFailed
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image format"
        case .renderFailed: return "Failed to render processed image"
        case .processingFailed: return "Image processing failed"
        }
    }
}

#endif
