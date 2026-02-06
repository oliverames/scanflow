# ScanFlow

A professional document scanning application for macOS and iOS built with SwiftUI and ImageCaptureCore, featuring multi-page ADF scanning, intelligent document processing, AI-assisted file naming, and a modern Liquid Glass design.

## Features

### Scanner Support
- **ImageCaptureCore Integration** - Access to 500+ scanner drivers built into macOS
- **Multi-source scanning** - Flatbed, ADF (single-sided), ADF Duplex
- **Network scanner discovery** - Bonjour, WiFi Direct, USB
- **Multi-page ADF scanning** - Automatically scans all pages and combines into single PDF
- **Auto-source detection** - Dynamically detects available scanner sources (flatbed/ADF)
- **Defaults to flatbed** - When available, flatbed is automatically selected
- **Liquid Glass UI** - Modern native macOS 26+ design with translucent glass effects

### Image Processing
- Auto-deskew with Vision-based perspective correction
- Auto-rotate using text orientation detection
- Blank page detection with configurable sensitivity
- Color restoration for faded photos
- Red-eye removal with face detection
- De-screening for printed materials (moiré removal)
- Image sharpening

### AI & Automation
- **AI-assisted file naming** - On-device FoundationModels generate intelligent filenames (macOS 26+)
- **Document action suggestions** - Automatically detect and create Calendar events and Contacts from scanned documents
- **Intelligent document separation** - Split multi-page scans by blank pages, barcodes, or content analysis
- **Searchable PDF output** - On-device OCR makes PDFs searchable

### Output Formats
- **PDF** - Uncompressed, full quality
- **Compressed PDF** - JPEG-compressed pages for smaller file size
- **JPEG** - With configurable quality (50-100%)
- **TIFF** - Lossless archival format
- **PNG** - Lossless with transparency support

### Workflow
- Queue-based batch scanning
- Professional scan presets (9 built-in)
- Drag & drop export
- Quick Look preview
- Keyboard shortcuts
- **Background connection mode** - Keep scanner connected when app is closed
- **Persistent menu bar** - Control scanning from menu bar even when main window is closed
- **Start at login** - Auto-enabled when background connection is on
- **Remote scanning** - Trigger scans from iOS and receive PDFs over local network

## Requirements

- macOS 14.0+ (macOS 26.0+ for AI features and Liquid Glass design)
- iOS 17.0+ (for remote scanning companion app)
- Xcode 16.0+
- Swift 5.9+

### Optional Features by OS Version

| Feature | Minimum Version |
|---------|-----------------|
| Core scanning | macOS 14.0 |
| Remote scanning | macOS 14.0 + iOS 17.0 |
| AI file naming | macOS 26.0 |
| Liquid Glass UI | macOS 26.0 |
| Document actions | macOS 14.0 |

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

### Background Connection

When closing the app after scanning, ScanFlow prompts you to keep the scanner connected in the background. If you choose "Keep Connected":

1. The main window closes but ScanFlow continues running
2. The app moves to the menu bar (Dock icon hides)
3. Scanner stays connected and ready for the next scan
4. Click the menu bar icon to open the scanning interface
5. Start at login is automatically enabled

You can also enable "Always show menu bar icon" in Settings to have persistent menu bar access without requiring background connection mode.

**Menu Bar Features:**
- Scanner connection status indicator
- Quick access to start scanning
- Show/hide main window
- Quit application

To disable background mode, go to Settings > Scanner and toggle off "Keep connected in background".

### Document Actions (Calendar & Contacts)

ScanFlow can automatically detect actionable information in scanned documents and offer to create Calendar events or Contacts:

**Calendar Events:**
- Detects dates, times, and event-related text
- Creates calendar events with extracted information
- Supports various date formats (March 15, 2024, 03/15/2024, 2024-03-15)

**Contacts:**
- Detects names, email addresses, and phone numbers
- Creates new contacts or updates existing ones
- Supports various phone formats (+1-555-123-4567, (555) 123-4567)

After scanning a document with detectable information, ScanFlow displays suggested actions in the preview. Click a suggestion to create the event or contact.

**Privacy:** All document analysis happens on-device. No data is sent to external servers.

### Remote Scanning (iOS + Mac)

ScanFlow can run a lightweight scan server on macOS and accept scan requests from iOS over your local network.

1. Launch ScanFlow on macOS (the server starts automatically)
2. Open ScanFlow on iOS and go to the Scan tab
3. Use the Remote Scanner panel to connect to your Mac
4. Choose whether to split documents on the Mac (Document Separation settings are respected unless you force a single PDF)
5. Tap **Scan on Mac** to trigger the scan and receive PDFs on iOS

The iOS app saves received PDFs into its Documents folder. Ensure both devices are on the same network and local network permissions are granted.

### AI File Naming (macOS 26+)

On macOS 26 and later, ScanFlow can use on-device AI (Apple Intelligence via FoundationModels) to generate intelligent filenames based on document content.

**How it works:**
1. After scanning, OCR extracts text from the document
2. The on-device AI model analyzes the content
3. A descriptive filename is generated (e.g., "2024-03-15 Invoice - Acme Corp")

**Settings (Settings > AI Renaming):**

| Setting | Description | Default |
|---------|-------------|---------|
| Enable AI Renaming | Turn AI naming on/off | Off |
| Date Prefix | Add date to filename | From Document |
| Date Source | Document content, scan date, or none | Document Content |
| Include Document Type | Add type (Invoice, Receipt, etc.) | On |
| Include Key Entities | Add names, amounts, etc. | On |
| Max Length | Maximum filename length | 60 characters |
| Advanced Mode | Use custom prompt | Off |
| Custom Prompt | Your own AI instructions | - |
| Fallback Behavior | What to do if AI fails | Prompt for manual entry |

**Naming Format:**
- Uses Title Case
- Date format: YYYY-MM-DD
- Uses en dashes (–) as separators
- Removes special characters unsuitable for filenames

**Privacy:** All AI processing happens on-device using Apple Intelligence. No document content is sent to external servers.

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
| Searchable PDF | 300 DPI | PDF + OCR | Color | ADF |
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
│   ├── ScanFlowApp.swift              # App entry point
│   ├── AppLifecycleDelegate.swift     # Background mode, menu bar, lifecycle
│   ├── Models/
│   │   ├── ScanPreset.swift           # Preset configuration model
│   │   ├── ScannedFile.swift          # Scanned file metadata
│   │   ├── QueuedScan.swift           # Scan queue item
│   │   └── ScanMetadata.swift         # Scan result metadata
│   ├── ViewModels/
│   │   ├── AppState.swift             # App state management (@Observable)
│   │   ├── ScannerManager.swift       # ICC scanner control
│   │   ├── ImageProcessor.swift       # Image processing pipeline
│   │   ├── PDFExporter.swift          # PDF generation
│   │   └── SettingsStore.swift        # Persistent settings (@AppStorage)
│   ├── Services/
│   │   ├── AIFileNamer.swift          # AI-assisted file naming
│   │   ├── DocumentActionService.swift # Calendar/Contacts integration
│   │   ├── RemoteScanServer.swift     # macOS scan server
│   │   ├── RemoteScanClient.swift     # iOS scan client
│   │   └── FolderActionsSupport.swift # Folder monitoring
│   └── Views/
│       ├── macOS/
│       │   ├── MainWindow.swift
│       │   ├── ScannerSelectionView.swift  # Liquid Glass UI
│       │   └── SettingsView.swift
│       ├── iOS/
│       │   ├── RemoteScanPanel.swift
│       │   └── ...
│       └── Shared/
│           ├── ScanView.swift
│           ├── LibraryView.swift
│           ├── QueueView.swift
│           ├── PresetView.swift
│           └── Components/
│               ├── ControlPanelView.swift
│               ├── PreviewView.swift
│               └── AIRenamingSettingsView.swift
├── Tests/
│   ├── SettingsStoreTests.swift
│   ├── ModelsTests.swift
│   ├── RemoteScanTests.swift
│   ├── AIFileNamerTests.swift
│   └── DocumentActionServiceTests.swift
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

## Testing

ScanFlow includes comprehensive automated tests using Swift Testing framework.

### Running Tests

```bash
# Using Xcode
# Cmd+U to run all tests

# Using xcodebuild
xcodebuild test -scheme ScanFlow -destination 'platform=macOS'
```

### Test Coverage

| Test Suite | Description |
|------------|-------------|
| SettingsStoreTests | Settings persistence and defaults |
| ModelsTests | Data models (QueuedScan, ScannedFile, ScanMetadata, ScanStatus) |
| RemoteScanTests | Remote scanning models and codec |
| AIFileNamerTests | AI naming settings and error handling |
| DocumentActionServiceTests | Calendar/Contacts detection |

### Mock Scanner

For testing without hardware, enable "Use mock scanner" in Settings > Scanner. The mock scanner simulates scanning operations and returns test images.

## Privacy & Security

ScanFlow is designed with privacy in mind:

- **On-device processing** - All image processing, OCR, and AI features run locally
- **No network calls** - Document content never leaves your device (except when using Remote Scanning between your own devices)
- **App Sandbox** - Runs in macOS sandbox with minimal permissions
- **Scoped file access** - Only accesses files you explicitly choose

### Required Permissions

| Permission | Purpose |
|------------|---------|
| Camera/Scanner | Access connected scanners via ImageCaptureCore |
| Local Network | Remote scanning between macOS and iOS |
| Calendar | Create events from scanned documents (optional) |
| Contacts | Create contacts from scanned documents (optional) |
| Downloads folder | Save scans to Downloads (optional) |

## License

Copyright 2024-2025 Oliver Ames. All rights reserved.
