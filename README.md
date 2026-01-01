# ScanFlow

A professional document scanning application for macOS built with SwiftUI and ImageCaptureCore, featuring multi-page ADF scanning, intelligent document processing, and comprehensive scan presets.

## Features

### Scanner Support
- **ImageCaptureCore Integration** - Access to 500+ scanner drivers built into macOS
- **Multi-source scanning** - Flatbed, ADF (single-sided), ADF Duplex
- **Network scanner discovery** - Bonjour, WiFi Direct, USB
- **Multi-page ADF scanning** - Automatically scans all pages and combines into single PDF
- **Auto-source detection** - Dynamically detects available scanner sources (flatbed/ADF)
- **Defaults to flatbed** - When available, flatbed is automatically selected

### Image Processing
- Auto-deskew with Vision-based perspective correction
- Auto-rotate using text orientation detection
- Blank page detection with configurable sensitivity
- Color restoration for faded photos
- Red-eye removal with face detection
- De-screening for printed materials (moiré removal)
- Image sharpening

### Output Formats
- **PDF** - Uncompressed, full quality
- **Compressed PDF** - JPEG-compressed pages for smaller file size
- **JPEG** - With configurable quality (50-100%)
- **TIFF** - Lossless archival format
- **PNG** - Lossless with transparency support

### Workflow
- Queue-based batch scanning
- Professional scan presets (8 built-in)
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
open ScanFlow.xcodeproj
# Build: Cmd+B
# Run: Cmd+R

# Using xcodebuild
xcodebuild -scheme ScanFlow -configuration Debug build
```

### First Launch

1. The app opens to the Scanner Selection screen
2. Available scanners are discovered automatically
3. Select your scanner to connect
4. Use the Scan button to start scanning

For testing without hardware, enable "Use mock scanner" in Settings.

## Scan Settings Reference

### Filing Tab

| Setting | Description | Default |
|---------|-------------|---------|
| Profile Name | Name of the scan preset | - |
| Folder Name | Destination folder for scans | ~/Documents |
| File Name Prefix | Prefix for generated filenames | "Scan-" |
| Sequence Number | Auto-increment number in filename | Enabled |
| Sequence Start | Starting number for sequence | 1 |
| Unique Date Tag | Add date/time to filename | Disabled |
| Edit Each Filename | Prompt for filename on each scan | Disabled |
| On Existing Files | Behavior when file exists | Increase sequence |
| Format | Output file format | PDF |
| Quality | JPEG/Compressed PDF quality | 85% |
| Split on Page | Split multi-page into separate files | Disabled |

**Workflow Options:**
| Setting | Description | Default |
|---------|-------------|---------|
| Show Config Before Scan | Show settings dialog before scanning | Disabled |
| Scan on Document Placement | Auto-scan when document detected | Disabled |
| Ask for More Pages | Prompt to continue after each page | Disabled |
| Timer | Delay before scanning starts | Disabled |
| Show Progress Indicator | Display scan progress | Enabled |
| Open With App | Open scan in specified app | Disabled |

### Basic Settings Tab

#### ImageCaptureCore API Settings

These settings directly configure the scanner hardware via Apple's ImageCaptureCore framework:

| Setting | ICC Property | Description | Default |
|---------|--------------|-------------|---------|
| Source | `ICScannerFunctionalUnitType` | Flatbed, ADF Front, ADF Duplex | Auto-detected |
| Resolution | `resolution` | Scan DPI (75-2400) | 300 |
| Color Mode | `pixelDataType` | Color, Grayscale, B&W | Color |
| Bit Depth | `bitDepth` | 8-bit or 16-bit color depth | 8-bit |
| Custom Scan Area | `scanArea` | X, Y, Width, Height coordinates | Full page |
| Measurement Unit | - | Inches, Centimeters, Pixels | Inches |
| Odd Page Orientation | `oddPageOrientation` | EXIF rotation for odd pages | Normal |
| Even Page Orientation | `evenPageOrientation` | EXIF rotation for even pages (duplex) | Normal |
| Duplex Scanning | `duplexScanningEnabled` | Scan both sides | Via source selection |

**Other Basic Settings:**
| Setting | Description | Default |
|---------|-------------|---------|
| Paper Size | Auto, Letter, Legal, A4, A5, Custom | Auto |
| Document Type | Photo or Document (affects processing) | Document |
| Media Detection | None, Auto crop, De-skew, Both | Auto crop and de-skew |
| Manual Rotation | 0°, 90°, 180°, 270° | 0° |
| Auto Rotate | Rotate based on content orientation | Enabled |
| Rotate Even Pages | Rotate every 2nd page 180° (duplex) | Disabled |
| De-skew | Straighten skewed pages | Enabled |
| Reverse Page Order | Reverse feeder page order | Disabled |

**Blank Page Detection:**
| Setting | Description | Default |
|---------|-------------|---------|
| Handling | Keep, Delete, or Ask | Delete |
| Sensitivity | Detection threshold (0-100%) | 50% |

### Advanced Settings Tab

#### ImageCaptureCore API Settings

| Setting | ICC Property | Description | Default |
|---------|--------------|-------------|---------|
| B&W Threshold | `thresholdForBlackAndWhiteScanning` | Threshold for B&W conversion (0-255) | 128 |

**Image Processing:**
| Setting | Description | Default |
|---------|-------------|---------|
| De-screen | Remove moiré patterns from printed materials | Disabled |
| Sharpen | Apply sharpening filter | Disabled |
| Invert Colors | Invert image colors (negative) | Disabled |

**Image Adjustments:**
| Setting | Range | Default |
|---------|-------|---------|
| Brightness | -100% to +100% | 0% |
| Contrast | -100% to +100% | +10% |
| Gamma | 0.5 to 3.0 | 2.2 |
| Hue | -100% to +100% (color only) | 0% |
| Saturation | -100% to +100% (color only) | 0% |
| Lightness | -100% to +100% (color only) | 0% |

**Photo Enhancement (Photo document type only):**
| Setting | Description | Default |
|---------|-------------|---------|
| Restore Faded Colors | Enhance faded photo colors | Disabled |
| Remove Red-Eye | Detect and remove red-eye | Disabled |

**Multi-page Options (ADF only):**
| Setting | Description | Default |
|---------|-------------|---------|
| Split Book Pages | Split 2-up scans into separate pages | Disabled |

## Built-in Presets

| Preset | Resolution | Format | Color | Source |
|--------|------------|--------|-------|--------|
| Color PDF | 300 DPI | PDF | Color | ADF |
| Gray PDF | 300 DPI | PDF | Grayscale | ADF |
| B/W PDF | 300 DPI | PDF | B&W | ADF |
| Color Copy | 300 DPI | JPEG | Color | Flatbed |
| Gray Copy | 300 DPI | JPEG | Grayscale | Flatbed |
| B/W Copy | 300 DPI | JPEG | B&W | Flatbed |
| Photos | 600 DPI | JPEG 95% | Color | Flatbed |
| Archive (600 DPI) | 600 DPI | TIFF | Color | ADF |

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
├── ScanFlow/
│   ├── ScanFlowApp.swift          # App entry point
│   ├── Models/
│   │   ├── ScanPreset.swift       # Preset configuration model
│   │   ├── ScannedFile.swift      # Scanned file metadata
│   │   ├── QueuedScan.swift       # Scan queue item
│   │   └── ScanMetadata.swift     # Scan result metadata
│   ├── ViewModels/
│   │   ├── AppState.swift         # App state management
│   │   ├── ScannerManager.swift   # ICC scanner control
│   │   ├── ImageProcessor.swift   # Image processing
│   │   └── PDFExporter.swift      # PDF generation
│   └── Views/
│       ├── macOS/                 # macOS-specific views
│       │   ├── MainWindow.swift
│       │   ├── ScannerSelectionView.swift
│       │   └── ...
│       └── Shared/                # Cross-platform views
│           ├── ScanView.swift
│           ├── Components/
│           │   ├── ControlPanelView.swift  # Settings inspector
│           │   └── ...
│           └── ...
└── ScanFlow.xcodeproj
```

## ImageCaptureCore Integration

ScanFlow uses Apple's ImageCaptureCore framework for scanner communication. Key classes used:

- `ICDeviceBrowser` - Scanner discovery
- `ICScannerDevice` - Scanner control
- `ICScannerFunctionalUnit` - Scan settings
- `ICScannerFunctionalUnitFlatbed` - Flatbed control
- `ICScannerFunctionalUnitDocumentFeeder` - ADF control

### Supported Scanner Properties

| Property | ICC Class | Description |
|----------|-----------|-------------|
| Resolution | `ICScannerFunctionalUnit` | Scan DPI |
| Bit Depth | `ICScannerFunctionalUnit` | Color depth |
| Pixel Type | `ICScannerFunctionalUnit` | RGB, Gray, B&W |
| Scan Area | `ICScannerFunctionalUnit` | Physical scan region |
| Document Type | `ICScannerFunctionalUnit` | Default, Positive, Negative |
| Duplex Enabled | `ICScannerFunctionalUnitDocumentFeeder` | Two-sided scanning |
| Page Orientation | `ICScannerFunctionalUnitDocumentFeeder` | EXIF rotation |

## License

Copyright 2024. All rights reserved.
