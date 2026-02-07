//
//  PresetView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.scanflow.app", category: "PresetView")

struct PresetView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPreset: ScanPreset.ID?

    var body: some View {
        @Bindable var appState = appState

        Group {
            #if os(macOS)
            HSplitView {
                presetList
                    .frame(minWidth: 250, maxWidth: 350)
                presetDetail
            }
            #else
            VStack(spacing: 0) {
                presetList
                    .frame(maxHeight: 300)
                Divider()
                presetDetail
            }
            #endif
        }
        .onAppear {
            // Auto-select the current preset when view appears
            if selectedPreset == nil {
                selectedPreset = appState.currentPreset.id
            }
        }
    }

    private func binding(for preset: ScanPreset) -> Binding<ScanPreset> {
        guard let index = appState.presets.firstIndex(where: { $0.id == preset.id }) else {
            logger.error("Preset not found: \(preset.id)")
            return Binding(
                get: { preset },
                set: { _ in }
            )
        }
        return Binding(
            get: { appState.presets[index] },
            set: { appState.presets[index] = $0 }
        )
    }

    private var presetList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Presets")
                    .font(.headline)

                Spacer()

                Button {
                    createNewPreset()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(12)
            .modifier(GlassHeaderStyle(cornerRadius: 14))
            .padding(.horizontal, 12)
            .padding(.top, 12)

            List(appState.presets, selection: $selectedPreset) { preset in
                PresetListItem(preset: preset, isSelected: preset.id == selectedPreset)
                    .tag(preset.id)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.sidebar)
            .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private var presetDetail: some View {
        if let preset = appState.presets.first(where: { $0.id == selectedPreset }) {
            PresetDetailView(preset: binding(for: preset))
        } else {
            ContentUnavailableView {
                Label("No Preset Selected", systemImage: "slider.horizontal.3")
            } description: {
                Text("Select a preset to view details")
            }
        }
    }

    private func createNewPreset() {
        let newPreset = ScanPreset(
            name: "New Preset",
            destination: appState.scanDestination,
            separationSettings: appState.defaultSeparationSettings,
            namingSettings: appState.defaultNamingSettings
        )
        appState.presets.append(newPreset)
        selectedPreset = newPreset.id
        appState.savePresets()
    }
}

struct PresetListItem: View {
    let preset: ScanPreset
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(preset.name)
                .font(.body)

            HStack {
                Text("\(preset.resolution) DPI")
                Text("•")
                Text(preset.format.rawValue)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .modifier(GlassCardStyle(cornerRadius: 12, isSelected: isSelected))
    }
}

struct PresetDetailView: View {
    @Binding var preset: ScanPreset
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("General") {
                TextField("Name:", text: $preset.name)

                Picker("Document Type:", selection: $preset.documentType) {
                    ForEach(DocumentType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }

            Section("Quality") {
                HStack {
                    Text("Resolution:")
                    Slider(value: Binding(
                        get: { Double(preset.resolution) },
                        set: { preset.resolution = Int($0) }
                    ), in: 300...1200, step: 300)
                    Text("\(preset.resolution) DPI")
                        .frame(width: 80, alignment: .trailing)
                }

                Picker("Format:", selection: $preset.format) {
                    ForEach(ScanFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }

                if preset.format == .pdf || preset.format == .compressedPDF {
                    Toggle("Searchable PDF (OCR)", isOn: $preset.searchablePDF)
                }

                if preset.format == .jpeg {
                    HStack {
                        Text("Quality:")
                        Slider(value: $preset.quality, in: 0.5...1.0)
                        Text("\(Int(preset.quality * 100))%")
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }

            Section("Auto-Enhancement") {
                Toggle("Auto Rotate", isOn: $preset.autoRotate)
                Toggle("Deskew", isOn: $preset.deskew)
                Toggle("Restore Faded Colors", isOn: $preset.restoreColor)
                Toggle("Remove Red-Eye", isOn: $preset.removeRedEye)
            }

            Section("Destination") {
                TextField("Path:", text: $preset.destination)
                    .help("Use ~ for home directory")
            }

            HStack {
                Spacer()
                Button("Use This Preset") {
                    appState.currentPreset = preset
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .modifier(GlassPanelStyle(cornerRadius: 20))
        .padding(16)
        .onChange(of: preset) {
            appState.savePresets()
        }
    }
}


private struct GlassHeaderStyle: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
        }
    }
}

private struct GlassCardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.16), lineWidth: 1)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
        }
    }
}

private struct GlassPanelStyle: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
        } else {
            content
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 12)
        }
    }
}
