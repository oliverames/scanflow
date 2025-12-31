//
//  Imprinter.swift
//  ScanFlow
//
//  Dynamic text overlay service for stamping scanned documents
//  Supports date/time, custom text, page numbers, barcode content, etc.
//

import Foundation
#if os(macOS)
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
#endif

#if os(macOS)

/// Dynamic text overlay for scanned documents
@MainActor
class Imprinter {

    /// Imprint configuration
    struct ImprintConfig: Codable {
        var enabled: Bool = false
        var text: String = ""
        var position: Position = .bottomRight
        var rotation: Rotation = .none
        var opacity: Double = 1.0
        var fontSize: CGFloat = 24.0
        var fontName: String = "Helvetica-Bold"
        var textColor: String = "#000000"  // Hex color
        var includeDate: Bool = false
        var includeTime: Bool = false
        var includePageNumbers: Bool = false
        var barcodeContent: String? = nil

        enum Position: String, Codable, CaseIterable {
            case topLeft = "Top Left"
            case topRight = "Top Right"
            case bottomLeft = "Bottom Left"
            case bottomRight = "Bottom Right"
            case center = "Center"

            var point: (x: CGFloat, y: CGFloat) {
                switch self {
                case .topLeft: return (0.05, 0.95)
                case .topRight: return (0.95, 0.95)
                case .bottomLeft: return (0.05, 0.05)
                case .bottomRight: return (0.95, 0.05)
                case .center: return (0.5, 0.5)
                }
            }
        }

        enum Rotation: Int, Codable, CaseIterable {
            case none = 0
            case rotate90 = 90
            case rotate180 = 180
            case rotate270 = 270

            var description: String {
                switch self {
                case .none: return "0°"
                case .rotate90: return "90°"
                case .rotate180: return "180°"
                case .rotate270: return "270°"
                }
            }
        }
    }

    // MARK: - Imprinting

    /// Apply imprint to image
    func imprint(_ image: NSImage, config: ImprintConfig, pageNumber: Int? = nil, barcodeContent: String? = nil) -> NSImage {
        guard config.enabled else { return image }

        let size = image.size

        // Create graphics context
        let targetImage = NSImage(size: size)
        targetImage.lockFocus()

        // Draw original image
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)

        // Generate imprint text
        let text = generateImprintText(config: config, pageNumber: pageNumber, barcodeContent: barcodeContent)

        // Configure text attributes
        let attributes = textAttributes(for: config)

        // Calculate position
        let textSize = text.size(withAttributes: attributes)
        let position = calculatePosition(config.position, imageSize: size, textSize: textSize)

        // Apply rotation if needed
        if config.rotation != .none {
            let transform = NSAffineTransform()
            transform.translateX(by: position.x, yBy: position.y)
            transform.rotate(byDegrees: CGFloat(config.rotation.rawValue))
            transform.translateX(by: -position.x, yBy: -position.y)
            transform.concat()
        }

        // Draw text with opacity
        NSGraphicsContext.current?.saveGraphicsState()
        NSGraphicsContext.current?.cgContext.setAlpha(config.opacity)

        text.draw(at: position, withAttributes: attributes)

        NSGraphicsContext.current?.restoreGraphicsState()

        targetImage.unlockFocus()

        return targetImage
    }

    // MARK: - Text Generation

    /// Generate imprint text from configuration
    private func generateImprintText(config: ImprintConfig, pageNumber: Int?, barcodeContent: String?) -> String {
        var components: [String] = []

        // Custom text
        if !config.text.isEmpty {
            components.append(config.text)
        }

        // Date
        if config.includeDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            components.append(formatter.string(from: Date()))
        }

        // Time
        if config.includeTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            components.append(formatter.string(from: Date()))
        }

        // Page number
        if config.includePageNumbers, let page = pageNumber {
            components.append("Page \(page)")
        }

        // Barcode content
        if let barcode = barcodeContent ?? config.barcodeContent, !barcode.isEmpty {
            components.append(barcode)
        }

        return components.joined(separator: " • ")
    }

    /// Generate text attributes
    private func textAttributes(for config: ImprintConfig) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]

        // Font
        if let font = NSFont(name: config.fontName, size: config.fontSize) {
            attributes[.font] = font
        } else {
            attributes[.font] = NSFont.systemFont(ofSize: config.fontSize, weight: .bold)
        }

        // Color
        if let color = NSColor(hexString: config.textColor) {
            attributes[.foregroundColor] = color
        } else {
            attributes[.foregroundColor] = NSColor.black
        }

        // Drop shadow for readability
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 1, height: -1)
        shadow.shadowBlurRadius = 2.0
        shadow.shadowColor = NSColor.white.withAlphaComponent(0.8)
        attributes[.shadow] = shadow

        return attributes
    }

    /// Calculate text position
    private func calculatePosition(_ position: ImprintConfig.Position, imageSize: NSSize, textSize: NSSize) -> NSPoint {
        let coords = position.point

        var x = imageSize.width * coords.x
        var y = imageSize.height * coords.y

        // Adjust for text size based on position
        switch position {
        case .topRight, .bottomRight:
            x -= textSize.width
        case .center:
            x -= textSize.width / 2
            y -= textSize.height / 2
        default:
            break
        }

        return NSPoint(x: x, y: y)
    }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        hex = hex.replacingOccurrences(of: "#", with: "")

        guard hex.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

#endif
