//
//  AIFileNamer.swift
//  ScanFlow
//
//  AI-assisted file renaming using Apple's FoundationModels framework
//  Uses on-device LLM to generate intelligent filenames from document content
//

import Foundation
#if os(macOS)
import AppKit

#if canImport(FoundationModels)
import FoundationModels
#endif
#endif

/// Settings for AI-assisted file naming
struct NamingSettings: Codable, Equatable {
    var enabled: Bool = false

    // Standard Mode Options
    var useDatePrefix: Bool = true
    var dateSource: DateSource = .documentContent
    var includeDocumentType: Bool = true
    var includeKeyEntities: Bool = true
    var maxLength: Int = 60

    // Advanced Mode
    var useAdvancedMode: Bool = false
    var customPrompt: String = Self.defaultPrompt

    // Fallback Behavior (user preference)
    var fallbackBehavior: FallbackBehavior = .promptManual

    enum DateSource: String, Codable, CaseIterable {
        case documentContent = "From Document"
        case scanDate = "Scan Date"
        case none = "No Date"
    }
    
    enum FallbackBehavior: String, Codable, CaseIterable {
        case promptManual = "Prompt for manual entry"
        case notifyAndFallback = "Notify and use date-based"
        case silentFallback = "Silent fallback to date-based"
    }
    
    static let defaultPrompt = """
        Generate a filename for this scanned document following these rules:

        NAMING CONVENTIONS:
        - Use Title Case with spaces (not underscores or hyphens between words)
        - Target under 60 characters for Finder readability
        - Filenames in English even if document content is in another language

        DATE PREFIX RULES:
        - Use YYYY-MM-DD prefix ONLY when date is critical to the document's purpose
        - Date should be the document's creation/event date from content, NOT scan date
        - Examples needing date: "2024-03-15 Board Meeting Notes", "2024-01-30 Tax Receipt"
        - Examples NOT needing date: "Oliver Ames – Media Release", "Q1 Marketing Report"

        SPECIAL CHARACTERS:
        - Use en dashes (–) for year ranges: "EastRise 2019–2025"
        - Use spaced en dashes to separate distinct elements: "Oliver Ames – Media Release"

        VERSIONS:
        - Use: v2, Draft, Final
        - NEVER use: (2), (copy), Copy of, New

        GOOD EXAMPLES:
        - "2024-03-15 Board Meeting Notes"
        - "Lawson's Finest Interview Prep"
        - "Oliver Ames – Media Release"
        - "Q1 Marketing Report Final"

        BAD EXAMPLES (don't do these):
        - "board_meeting_notes_03-15-24"
        - "lawsons-finest-interview-prep (2)"
        - "media release copy"
        """
    
    static let `default` = NamingSettings()

    init() {}
}

/// Response structure for AI-generated filename
struct FilenameResponse {
    var filename: String
    var documentType: String
    var documentDate: String
    var reasoning: String
    var confidence: Double
    
    init(filename: String = "", documentType: String = "Other", documentDate: String = "", reasoning: String = "", confidence: Double = 0.0) {
        self.filename = filename
        self.documentType = documentType
        self.documentDate = documentDate
        self.reasoning = reasoning
        self.confidence = confidence
    }
}

#if !os(macOS)
@MainActor
class AIFileNamer {
    static func isAvailable() async -> Bool {
        false
    }
}
#endif

#if os(macOS)
#if canImport(FoundationModels)
/// Generable version for FoundationModels (macOS 26+)
@available(macOS 26.0, *)
@Generable
struct GenerableFilenameResponse {
    @Guide(description: "Suggested filename without extension, max 60 characters, Title Case with spaces")
    var filename: String
    
    @Guide(description: "Document type detected: Invoice, Receipt, Letter, Contract, Report, Photo, Form, Article, Manual, Other")
    var documentType: String
    
    @Guide(description: "Key date found in document in YYYY-MM-DD format, or empty if none found")
    var documentDate: String
    
    @Guide(description: "Brief explanation of why this name was chosen, under 100 characters")
    var reasoning: String
    
    @Guide(description: "Confidence score from 0.0 to 1.0")
    var confidence: Double
    
    func toFilenameResponse() -> FilenameResponse {
        FilenameResponse(
            filename: filename,
            documentType: documentType,
            documentDate: documentDate,
            reasoning: reasoning,
            confidence: confidence
        )
    }
}
#endif

/// AI-assisted file naming service
@MainActor
class AIFileNamer {
    private let imageProcessor: ImageProcessor
    
    init(imageProcessor: ImageProcessor) {
        self.imageProcessor = imageProcessor
    }
    
    convenience init() {
        self.init(imageProcessor: ImageProcessor())
    }
    
    // MARK: - Public API
    
    /// Suggest a filename for a set of document pages
    func suggestFilename(
        for pages: [NSImage],
        settings: NamingSettings,
        scanDate: Date = Date()
    ) async throws -> FilenameResponse {
        // 1. Extract text from first few pages
        var fullText = ""
        for page in pages.prefix(3) {
            let text = try await imageProcessor.recognizeText(page)
            fullText += text + "\n\n---PAGE BREAK---\n\n"
        }
        
        // Truncate to avoid context limits (keep first ~3000 chars)
        let truncatedText = String(fullText.prefix(3000))
        
        // 2. Build prompt
        let prompt = buildPrompt(
            documentText: truncatedText,
            settings: settings,
            scanDate: scanDate
        )
        
        // 3. Query FoundationModels (macOS 26+)
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let session = LanguageModelSession(
                instructions: settings.useAdvancedMode ? settings.customPrompt : NamingSettings.defaultPrompt
            )
            
            let response = try await session.respond(
                to: prompt,
                generating: GenerableFilenameResponse.self
            )
            
            // 4. Post-process the filename
            var result = response.content.toFilenameResponse()
            result.filename = sanitizeFilename(result.filename, maxLength: settings.maxLength)
            
            return result
        }
        #endif
        
        // Fallback for older macOS versions
        throw AIFileNamerError.modelUnavailable
    }
    
    /// Check if AI naming is available on this device
    static func isAvailable() async -> Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let availability = SystemLanguageModel.default.availability
            switch availability {
            case .available:
                return true
            case .unavailable:
                return false
            @unknown default:
                return false
            }
        }
        #endif
        return false
    }
    
    // MARK: - Private Methods
    
    private func buildPrompt(
        documentText: String,
        settings: NamingSettings,
        scanDate: Date
    ) -> String {
        var prompt = "DOCUMENT TEXT:\n\(documentText)\n\n"
        
        if !settings.useAdvancedMode {
            prompt += "REQUIREMENTS:\n"
            
            switch settings.dateSource {
            case .documentContent:
                prompt += "- Extract date from document content if present and relevant\n"
            case .scanDate:
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                prompt += "- Use scan date: \(formatter.string(from: scanDate))\n"
            case .none:
                prompt += "- Do not include a date prefix\n"
            }
            
            if settings.includeDocumentType {
                prompt += "- Identify and include document type in the name if it adds clarity\n"
            }
            if settings.includeKeyEntities {
                prompt += "- Include key entities (company names, people, project names) when relevant\n"
            }
            prompt += "- Maximum \(settings.maxLength) characters\n"
        }
        
        prompt += "\nGenerate the filename now."
        return prompt
    }
    
    /// Sanitize filename to ensure it's valid for filesystem
    private func sanitizeFilename(_ filename: String, maxLength: Int) -> String {
        var sanitized = filename
        
        // Remove or replace invalid characters
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?*\"<>|")
        sanitized = sanitized.components(separatedBy: invalidCharacters).joined(separator: "")
        
        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Truncate if too long
        if sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength))
            // Try to break at word boundary
            if let lastSpace = sanitized.lastIndex(of: " ") {
                sanitized = String(sanitized[..<lastSpace])
            }
        }
        
        // Remove trailing punctuation (except for dashes which might be intentional)
        while let last = sanitized.last, ".,:;".contains(last) {
            sanitized.removeLast()
        }
        
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum AIFileNamerError: LocalizedError {
    case modelUnavailable
    case textExtractionFailed
    case generationFailed(underlying: Error)
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device"
        case .textExtractionFailed:
            return "Failed to extract text from document"
        case .generationFailed(let error):
            return "AI naming failed: \(error.localizedDescription)"
        case .emptyResponse:
            return "AI returned an empty filename"
        }
    }
}

#endif
