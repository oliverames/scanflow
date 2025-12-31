//
//  PresetView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI

struct PresetView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPreset: ScanPreset.ID?

    var body: some View {
        @Bindable var appState = appState

        HSplitView {
            // Preset List
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
                .padding()

                Divider()

                List(appState.presets, selection: $selectedPreset) { preset in
                    PresetListItem(preset: preset)
                        .tag(preset.id)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 250, maxWidth: 350)

            // Preset Detail
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
    }

    private func binding(for preset: ScanPreset) -> Binding<ScanPreset> {
        guard let index = appState.presets.firstIndex(where: { $0.id == preset.id }) else {
            fatalError("Preset not found")
        }
        return Binding(
            get: { appState.presets[index] },
            set: { appState.presets[index] = $0 }
        )
    }

    private func createNewPreset() {
        let newPreset = ScanPreset(name: "New Preset")
        appState.presets.append(newPreset)
        selectedPreset = newPreset.id
        appState.savePresets()
    }
}

struct PresetListItem: View {
    let preset: ScanPreset

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
        .padding(.vertical, 4)
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
        .padding()
        .onChange(of: preset) {
            appState.savePresets()
        }
    }
}

#Preview {
    PresetView()
        .environment(AppState())
        .frame(width: 800, height: 600)
}
