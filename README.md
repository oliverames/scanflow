# ScanFlow

A professional document scanning application for macOS built with SwiftUI, featuring intelligent document processing, OCR, and batch scanning capabilities.

## Features

### Scanner Support
- ImageCaptureCore integration (500+ scanner drivers)
- Network scanner discovery (Bonjour/WiFi Direct)
- Epson FastFoto FF-680W support
- USB and network scanner protocols

### Image Processing
- Auto-deskew with Vision-based perspective correction
- Auto-rotate using horizon detection
- Blank page detection
- Color restoration for faded photos
- Red-eye removal with face detection

### OCR & Text Recognition
- Searchable PDFs with invisible text layer
- 25+ language support
- Spotlight integration for system-wide search
- Export formats: PDF, TXT, RTF

### Workflow
- Queue-based batch scanning
- Professional scan presets
- Drag & drop export
- Quick Look preview
- Keyboard shortcuts

## Requirements

- macOS 14.0+
- Xcode 16.0+
- Swift 5.9+

## Getting Started

### Build & Run

```bash
# Using Xcode
open PhotoFlow.xcodeproj
# Build: Cmd+B
# Run: Cmd+R

# Using xcodebuild
xcodebuild -scheme PhotoFlow -configuration Debug build
```

### First Launch

1. The app opens to the Scanner Selection screen
2. Available scanners are discovered automatically
3. Select your scanner to connect
4. Use the Scan button to start scanning

For testing without hardware, enable "Use mock scanner" in Settings.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+R | Start Scan |
| Cmd+1 | Scan View |
| Cmd+2 | Scan Queue |
| Cmd+3 | Library |
| Cmd+4 | Presets |
| Cmd+, | Settings |
| Space | Quick Look |

## Project Structure

```
ScanFlow/
├── PhotoFlow/
│   ├── PhotoFlowApp.swift      # App entry point
│   ├── Models/                  # Data models
│   ├── ViewModels/              # State management
│   │   ├── AppState.swift
│   │   ├── ScannerManager.swift
│   │   ├── ImageProcessor.swift
│   │   └── PDFExporter.swift
│   └── Views/
│       ├── macOS/               # macOS-specific views
│       └── Shared/              # Cross-platform views
└── PhotoFlow.xcodeproj
```

## Configuration

Default scan destination: `~/Pictures/Scans`

Configurable settings:
- Resolution: 300/600/1200 DPI
- Format: JPEG/PNG/TIFF
- File organization: Single folder / By date / By month
- Custom naming patterns

## License

Copyright 2024. All rights reserved.
