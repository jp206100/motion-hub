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

The Xcode project is included in the repository. Open it and build:

```bash
open MotionHub.xcodeproj
# Press ⌘B to build, ⌘R to build and run
```

If you need to adjust signing, select the **MotionHub** target in Xcode and set your team under **Signing & Capabilities** (or leave it as "Sign to Run Locally").

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
├── MotionHub.xcodeproj/          # Xcode project
│   └── project.pbxproj
├── MotionHub/
│   └── MotionHub/
│       ├── App/                  # App entry point + font registration
│       ├── Models/               # AppState, InspirationPack data models
│       ├── Views/                # SwiftUI views
│       ├── Services/             # AudioAnalyzer, MIDIHandler, OSCHandler,
│       │                         # PackManager, PreprocessingManager, DebugLogger
│       ├── Rendering/            # Metal engine + shaders
│       ├── Resources/            # Colors, fonts, assets
│       ├── Info.plist            # App configuration
│       └── MotionHub.entitlements # App permissions
├── preprocessing/                # Python AI pipeline
│   ├── extract.py                # Extraction script
│   ├── requirements.txt          # Python deps
│   └── utils/
├── Scripts/                      # Build and setup scripts
├── Tools/                        # OSC test utilities
├── README.md                     # Project overview
└── SETUP.md                      # This file
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
