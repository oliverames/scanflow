#if os(macOS)
import Testing
import AppKit
import PDFKit
@testable import ScanFlow

struct PDFExporterTests {
    @Test("Export with OCR writes a PDF file")
    func exportWithOCROutput() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
        let outputURL = tempDirectory.appendingPathComponent("scanflow-ocr-test.pdf")
        try? FileManager.default.removeItem(at: outputURL)

        let image = NSImage(size: NSSize(width: 400, height: 400), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            return true
        }

        let imageURL = tempDirectory.appendingPathComponent("scanflow-ocr-image.png")
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            #expect(Bool(false), "Failed to create PNG data")
            return
        }
        try pngData.write(to: imageURL)

        let scannedFile = ScannedFile(
            filename: imageURL.lastPathComponent,
            fileURL: imageURL,
            size: Int64(pngData.count),
            resolution: 300,
            dateScanned: Date(),
            scannerModel: "Test",
            format: .png
        )

        try await PDFExporter.exportWithOCR(files: [scannedFile], to: outputURL, imageProcessor: ImageProcessor())

        let pdfDocument = PDFDocument(url: outputURL)
        #expect(pdfDocument != nil)
        #expect(pdfDocument?.pageCount == 1)
    }
}
#endif
