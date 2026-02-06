//
//  AIRenamingSettingsView.swift
//  ScanFlow
//
//  Settings UI for AI-assisted file renaming
//  Provides both Standard mode (checkboxes/sliders) and Advanced mode (custom prompt)
//

import SwiftUI

struct AIRenamingSettingsView: View {
    @Binding var settings: NamingSettings
    @State private var isAIAvailable: Bool = false
    @State private var checkingAvailability: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main toggle
            Toggle("Enable AI-Assisted Renaming", isOn: $settings.enabled)
                .toggleStyle(.switch)
            
            if checkingAvailability {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking Apple Intelligence availability...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !isAIAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Apple Intelligence not available on this device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if settings.enabled && isAIAvailable {
                Divider()
                
                // Mode selector
                Picker("Mode", selection: $settings.useAdvancedMode) {
                    Text("Standard").tag(false)
                    Text("Advanced").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
                
                if settings.useAdvancedMode {
                    advancedModeView
                } else {
                    standardModeView
                }
                
                Divider()
                
                // Fallback behavior (always visible when enabled)
                fallbackSettingsView
            }
        }
        .task {
            checkingAvailability = true
            isAIAvailable = await AIFileNamer.isAvailable()
            checkingAvailability = false
        }
    }
    
    // MARK: - Standard Mode
    
    private var standardModeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Date options
            Toggle("Include date prefix when relevant", isOn: $settings.useDatePrefix)
                .toggleStyle(.checkbox)
            
            if settings.useDatePrefix {
                Picker("Date source:", selection: $settings.dateSource) {
                    ForEach(NamingSettings.DateSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .padding(.leading, 20)
            }
            
            Toggle("Identify document type", isOn: $settings.includeDocumentType)
                .toggleStyle(.checkbox)
            
            Toggle("Include key entities (names, companies)", isOn: $settings.includeKeyEntities)
                .toggleStyle(.checkbox)
            
            // Max length slider
            HStack {
                Text("Max length:")
                Slider(
                    value: Binding(
                        get: { Double(settings.maxLength) },
                        set: { settings.maxLength = Int($0) }
                    ),
                    in: 30...80,
                    step: 5
                )
                Text("\(settings.maxLength)")
                    .monospacedDigit()
                    .frame(width: 30)
            }
        }
        .controlSize(.small)
    }
    
    // MARK: - Advanced Mode
    
    private var advancedModeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom Naming Prompt")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextEditor(text: $settings.customPrompt)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 200)
                .scrollContentBackground(.hidden)
                .modifier(GlassTextEditorStyle())
            
            HStack {
                Button("Reset to Default") {
                    settings.customPrompt = NamingSettings.defaultPrompt
                }
                .controlSize(.small)
                
                Spacer()
                
                Text("\(settings.customPrompt.count) characters")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // MARK: - Fallback Settings
    
    private var fallbackSettingsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When AI naming fails:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Picker("", selection: $settings.fallbackBehavior) {
                ForEach(NamingSettings.FallbackBehavior.allCases, id: \.self) { behavior in
                    Text(behavior.rawValue).tag(behavior)
                }
            }
            .labelsHidden()
            
            // Description of current fallback
            Text(fallbackDescription)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var fallbackDescription: String {
        switch settings.fallbackBehavior {
        case .promptManual:
            return "Shows a dialog with document preview for manual filename entry."
        case .notifyAndFallback:
            return "Shows a notification and uses date-based naming (e.g., Scan-2024-03-15-001)."
        case .silentFallback:
            return "Silently falls back to date-based naming without notification."
        }
    }
}

private struct GlassTextEditorStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 6))
        } else {
            content
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}
