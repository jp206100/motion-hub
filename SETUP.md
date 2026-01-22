# Motion Hub - Development Setup Guide

Complete step-by-step guide to get Motion Hub building and running on your Mac.

## Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Python 3.11 or later
- Homebrew (for optional dependencies)

## Part 1: Python Environment Setup ✅ COMPLETE

The Python environment has already been set up! To verify:

```bash
cd preprocessing
source venv/bin/activate
python extract.py --help
```

You should see the help output for the extraction script.

## Part 2: Xcode Project Setup

Since Xcode project files are complex, here are THREE methods to get started. Choose the one that works best for you:

### Method A: Create Project in Xcode GUI (Recommended)

This is the standard, most reliable approach:

1. **Open Xcode** on your Mac

2. **Create New Project**:
   - File > New > Project...
   - Select "macOS" tab
   - Choose "App" template
   - Click "Next"

3. **Configure Project**:
   ```
   Product Name: MotionHub
   Team: (leave as None or select your team)
   Organization Identifier: com.motionhub
   Bundle Identifier: com.motionhub.MotionHub
   Interface: SwiftUI
   Language: Swift
   ☐ Use Core Data (unchecked)
   ☐ Include Tests (unchecked)
   ```
   - Click "Next"

4. **Save Location**:
   - Navigate to your `motion-hub` directory
   - **IMPORTANT**: Click "New Folder" and name it "MotionHubProject" or similar
   - Click "Create"

5. **Add Our Source Files**:
   - In Xcode's Project Navigator (left sidebar), RIGHT-CLICK on the "MotionHub" folder (blue icon)
   - Select "Add Files to 'MotionHub'..."
   - Navigate to `motion-hub/MotionHub/MotionHub/`
   - Select ALL folders: `App`, `Models`, `Views`, `Services`, `Rendering`, `Resources`
   - **IMPORTANT**: Make sure these options are checked:
     - ☑ "Create groups"
     - ☐ "Copy items if needed" (UNCHECKED - we want references, not copies)
     - ☑ "Add to targets: MotionHub"
   - Click "Add"

6. **Remove Auto-Generated Files**:
   - Xcode created its own `ContentView.swift` and `MotionHubApp.swift`
   - Right-click each and select "Delete" > "Move to Trash"
   - We're using our own versions

7. **Configure Info.plist**:
   - In Project Navigator, select the blue "MotionHub" project icon (top)
   - Select "MotionHub" under TARGETS
   - Go to "Info" tab
   - Find "Custom macOS Application Target Properties"
   - If you see a generated Info.plist, delete those keys
   - Click "+" to add a custom property:
     - Key: `Privacy - Microphone Usage Description`
     - Value: `Motion Hub needs access to audio input to analyze sound and create reactive visuals.`

8. **Add Entitlements**:
   - Still in target settings, go to "Signing & Capabilities"
   - Click "+ Capability"
   - Add "Audio Input"
   - This creates MotionHub.entitlements automatically

9. **Configure Build Settings**:
   - In target settings, go to "Build Settings"
   - Search for "macOS Deployment Target"
   - Set to "14.0"
   - Search for "Info.plist File"
   - Set to: `MotionHub/MotionHub/Info.plist`

10. **Add Metal Files**:
    - Make sure all `.metal` files are in the "Compile Sources" build phase
    - Select project > Build Phases > Compile Sources
    - If `.metal` files are missing, click "+" and add them from `Rendering/Shaders/`

11. **Build the Project**:
    ```
    Press ⌘B or Product > Build
    ```

12. **Fix Any Build Errors**:
    - Missing imports: Add framework in "General" > "Frameworks and Libraries"
    - File not found: Make sure all files are added to the target

### Method B: Using Package.swift (Experimental)

Swift Package Manager is simpler but may have limitations with Metal shaders:

1. The repository includes a `Package.swift` file (create if missing):

```bash
cd motion-hub
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MotionHub",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MotionHub", targets: ["MotionHub"])
    ],
    targets: [
        .executableTarget(
            name: "MotionHub",
            path: "MotionHub/MotionHub"
        )
    ]
)
EOF
```

2. Open in Xcode:
   ```bash
   open Package.swift
   ```

3. Xcode will load it as a Swift Package
4. Build with ⌘B

**Note**: This method may require additional configuration for Metal shaders and Info.plist.

### Method C: Command Line (Advanced)

If you're comfortable with command-line tools:

1. Install xcodegen (optional):
   ```bash
   brew install xcodegen
   ```

2. Create `project.yml` configuration
3. Run `xcodegen generate`

## Part 3: Additional System Setup

### Install BlackHole (for audio routing)

1. Download BlackHole 2ch from https://github.com/ExistentialAudio/BlackHole
2. Install the .pkg file
3. Open "Audio MIDI Setup" (in /Applications/Utilities/)
4. Create a Multi-Output Device:
   - Click "+" bottom left > "Create Multi-Output Device"
   - Check your audio interface AND BlackHole 2ch
5. Set your DAW (Ableton Live, etc.) to output to this Multi-Output Device
6. In Motion Hub, select "BlackHole 2ch" as audio input

### Install FFmpeg (for video processing)

```bash
brew install ffmpeg
```

## Part 4: First Run

1. **Build the app** (⌘B)

2. **Run the app** (⌘R)

3. **Test Audio**:
   - In Motion Hub, click the audio device dropdown
   - Select "BlackHole 2ch" if available
   - Play audio in your DAW
   - You should see audio levels in the footer

4. **Test MIDI**:
   - Connect Push 2 via USB
   - In Motion Hub, click the MIDI device dropdown
   - Select your Push 2
   - Move encoders assigned to CC 71-78
   - Controls should respond

5. **Load Inspiration Media**:
   - Click "Browse Files"
   - Select images, videos, or GIFs
   - Wait for preprocessing (Python script runs in background)
   - Visuals should appear in preview panel

## Troubleshooting

### "Cannot find 'MTLDevice' in scope"
- Add Metal framework: Target > General > Frameworks and Libraries > + > Metal.framework

### "Cannot find 'AVAudioEngine' in scope"
- Add AVFoundation framework

### Python script not found
- Check that `preprocessing/extract.py` has execute permissions:
  ```bash
  chmod +x preprocessing/extract.py
  ```

### Audio not working
- Grant microphone permission: System Settings > Privacy & Security > Microphone > Allow for MotionHub
- Verify BlackHole is installed and selected
- Check that audio is playing in your DAW

### Build errors with Metal shaders
- Ensure all `.metal` files are in "Compile Sources" build phase
- Check that `ShaderTypes.h` is in "Headers" build phase or "Compile Sources"

### "No such module 'Combine'"
- Combine is part of Swift standard library
- Make sure deployment target is macOS 14.0+
- Try cleaning build folder: Product > Clean Build Folder (⇧⌘K)

## Project Structure

After setup, your workspace should look like:

```
motion-hub/
├── MotionHub.xcodeproj/          # Xcode project (created by you)
│   └── project.pbxproj
├── MotionHub/                     # Source code
│   ├── MotionHub/                 # Main app bundle
│   │   ├── App/                   # App entry point
│   │   ├── Models/                # Data models
│   │   ├── Views/                 # SwiftUI views
│   │   ├── Services/              # Audio, MIDI, packs
│   │   ├── Rendering/             # Metal engine + shaders
│   │   ├── Resources/             # Colors, fonts
│   │   └── Info.plist             # App configuration
│   └── MotionHub.entitlements     # App permissions
├── preprocessing/                 # Python AI pipeline
│   ├── venv/                      # Virtual environment ✅
│   ├── extract.py                 # Extraction script ✅
│   └── requirements.txt           # Python deps ✅
├── README.md                      # Project overview
└── SETUP.md                       # This file
```

## Next Steps

Once you have the app building:

1. **Explore the code**:
   - `App/MotionHubApp.swift` - Entry point
   - `Views/ContentView.swift` - Main layout
   - `Rendering/VisualEngine.swift` - Metal rendering
   - `Services/AudioAnalyzer.swift` - Audio FFT analysis

2. **Create your first pack**:
   - Browse for images/videos
   - Wait for AI preprocessing
   - Adjust knobs to customize visuals
   - Save pack with a name

3. **Connect hardware**:
   - Plug in Push 2
   - Select it in MIDI devices
   - Configure encoders to CC 71-78
   - Control visuals via hardware

4. **Performance mode**:
   - Click "Performance Mode" button
   - Fullscreen visuals on selected display
   - Press Escape to exit

## Getting Help

If you encounter issues:

1. Check Xcode build errors carefully
2. Verify all frameworks are linked
3. Ensure all source files are added to target
4. Check permissions in System Settings
5. Review console logs for Python errors

## Success Checklist

- ☐ Python environment activated
- ☐ Xcode project created
- ☐ All source files added to project
- ☐ Project builds successfully (⌘B)
- ☐ App runs without crashing (⌘R)
- ☐ Audio devices listed
- ☐ MIDI devices detected (if connected)
- ☐ Can browse and select media files
- ☐ Preprocessing completes
- ☐ Visuals render in preview panel

Once all checked, you're ready to perform! 🎉
