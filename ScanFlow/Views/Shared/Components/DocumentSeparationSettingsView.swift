//
//  DocumentSeparationSettingsView.swift
//  ScanFlow
//
//  Settings UI for intelligent document separation
//  Configures how batch scans are split into separate documents
//

import SwiftUI

struct DocumentSeparationSettingsView: View {
    @Binding var settings: SeparationSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main toggle
            Toggle("Enable Document Separation", isOn: $settings.enabled)
                .toggleStyle(.switch)
            
            if settings.enabled {
                Divider()
                
                // Separation methods
                separationMethodsView
                
                Divider()
                
                // Additional options
                additionalOptionsView
            }
        }
    }
    
    // MARK: - Separation Methods
    
    private var separationMethodsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Separation Methods")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            // Blank page detection
            Toggle("Split on blank pages", isOn: $settings.useBlankPages)
                .toggleStyle(.checkbox)
            
            if settings.useBlankPages {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Blank sensitivity:")
                            .font(.caption)
                        Slider(value: $settings.blankSensitivity, in: 0...1, step: 0.1)
                        Text(blankSensitivityLabel)
                            .font(.caption)
                            .frame(width: 50)
                    }
                    .padding(.leading, 20)
                    
                    Toggle("Delete blank separator pages", isOn: $settings.deleteBlankPages)
                        .toggleStyle(.checkbox)
                        .padding(.leading, 20)
                }
            }
            
            // Barcode-based separation
            Toggle("Split on barcode markers", isOn: $settings.useBarcodes)
                .toggleStyle(.checkbox)
            
            if settings.useBarcodes {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Barcode pattern (regex):")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField(".*", text: $settings.barcodePattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                    
                    Text("Use .* to match any barcode, or specify a pattern")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 20)
            }
            
            // Content analysis (advanced)
            Toggle("Analyze content changes", isOn: $settings.useContentAnalysis)
                .toggleStyle(.checkbox)
            
            if settings.useContentAnalysis {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Similarity threshold:")
                            .font(.caption)
                        Slider(value: $settings.similarityThreshold, in: 0.1...0.8, step: 0.1)
                        Text("\(Int(settings.similarityThreshold * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                    
                    Text("Lower = more likely to split on content changes")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.leading, 20)
            }
        }
        .controlSize(.small)
    }
    
    // MARK: - Additional Options
    
    private var additionalOptionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Options")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            // Minimum pages per document
            HStack {
                Text("Minimum pages per document:")
                    .font(.caption)
                Stepper(value: $settings.minimumPagesPerDocument, in: 1...10) {
                    Text("\(settings.minimumPagesPerDocument)")
                        .monospacedDigit()
                }
            }
            
            // Manual adjustment option (advanced)
            Toggle("Allow manual boundary adjustment", isOn: $settings.allowManualAdjustment)
                .toggleStyle(.checkbox)
            
            if settings.allowManualAdjustment {
                Text("Shows a review screen before saving separated documents")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 20)
            }
        }
        .controlSize(.small)
    }
    
    // MARK: - Helpers
    
    private var blankSensitivityLabel: String {
        if settings.blankSensitivity < 0.3 {
            return "Low"
        } else if settings.blankSensitivity < 0.7 {
            return "Medium"
        } else {
            return "High"
        }
    }
}

// MARK: - Preview

#Preview {
    Form {
        DocumentSeparationSettingsView(settings: .constant(SeparationSettings()))
    }
    .frame(width: 400, height: 500)
    .padding()
}
