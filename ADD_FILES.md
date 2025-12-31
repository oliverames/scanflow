# Adding New Files to Xcode Project

Two new files were created but need to be added to the Xcode project:

1. **PhotoFlow/ViewModels/ImageProcessor.swift**
2. **PhotoFlow/ViewModels/PDFExporter.swift**

## Steps to Add Files:

### Option 1: Using Xcode (Recommended)
1. Open `PhotoFlow.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), right-click on the "ViewModels" folder
3. Select "Add Files to PhotoFlow..."
4. Navigate to `PhotoFlow/ViewModels/`
5. Select both `ImageProcessor.swift` and `PDFExporter.swift`
6. Make sure "Copy items if needed" is **unchecked** (files are already in place)
7. Make sure "Create groups" is selected
8. Make sure "PhotoFlow" target is checked
9. Click "Add"
10. Build the project (⌘B)

### Option 2: Using Command Line
Run these commands from the project root:

```bash
# Open the project in Xcode
open PhotoFlow.xcodeproj

# Then follow the GUI steps above
```

## Verification

After adding the files, verify they appear in:
- Project Navigator under ViewModels folder
- Target Membership shows "PhotoFlow" checked
- Build Phases → Compile Sources includes both files

Then build the project:
```bash
xcodebuild -project PhotoFlow.xcodeproj -scheme PhotoFlow -configuration Debug build
```

The build should succeed with no errors.
