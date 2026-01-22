# Motion Hub

A standalone macOS application for generating real-time, audio-reactive visuals for live music performance.

## Overview

Motion Hub preprocesses user-uploaded inspiration media (images, videos, GIFs) using AI to extract visual artifacts, then uses those artifacts to drive a procedural graphics engine that responds to audio input.

## Features

- **Real-time Audio Analysis**: FFT-based frequency analysis with customizable band selection
- **MIDI Control**: Push 2 integration for live parameter control
- **AI-Powered Preprocessing**: Automatic extraction of colors, textures, and motion patterns from media
- **Metal-Accelerated Graphics**: Optimized for Apple Silicon (M1/M2/M3)
- **Pack System**: Save and load complete visual configurations
- **Performance Mode**: Fullscreen output for live performances

## System Requirements

- macOS 14.0 or later
- Apple Silicon (M1/M2/M3) - optimized for M2 MacBook Air
- 8GB RAM minimum
- BlackHole or similar audio loopback software (for audio routing from DAW)

## Development Setup

### Prerequisites

- Xcode 15 or later
- Python 3.11 or later
- FFmpeg (install via Homebrew: `brew install ffmpeg`)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/motion-hub.git
cd motion-hub
```

2. Install Python dependencies:
```bash
cd preprocessing
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd ..
```

3. Open the Xcode project:
```bash
open MotionHub/MotionHub.xcodeproj
```

4. Build and run (⌘R)

## Audio Setup

Motion Hub receives audio from your DAW via a loopback device:

1. Install [BlackHole 2ch](https://github.com/ExistentialAudio/BlackHole)
2. Open Audio MIDI Setup (in /Applications/Utilities/)
3. Create a Multi-Output Device:
   - Add your audio interface (e.g., Focusrite Scarlett)
   - Add BlackHole 2ch
4. Set your DAW (Ableton Live, etc.) to output to the Multi-Output Device
5. In Motion Hub, select BlackHole 2ch as the audio input

## MIDI Setup

Motion Hub supports Ableton Push 2 with fixed CC mappings:

| CC | Parameter | Range |
|----|-----------|-------|
| 71 | Intensity | 0-127 (0-100%) |
| 72 | Glitch Amount | 0-127 (0-100%) |
| 73 | Speed | 0-31=1X, 32-63=2X, 64-95=3X, 96-127=4X |
| 74 | Color Shift | 0-127 (0-100%) |
| 75 | Freq Min | 0-127 (20-20000 Hz, logarithmic) |
| 76 | Freq Max | 0-127 (20-20000 Hz, logarithmic) |
| 77 | Monochrome | 0-63=Off, 64-127=On |
| 78 | Reset | Any value triggers |

Configure your Push 2 encoders to send these CC numbers.

## Usage

### First Launch

1. Launch Motion Hub
2. Click "Browse Files" to select inspiration media (images, videos, GIFs)
3. Wait for AI preprocessing to complete
4. Adjust parameters using knobs or MIDI controller
5. Click "Save Pack" to preserve your configuration

### Live Performance

1. Load your prepared pack
2. Connect Push 2 via USB
3. Select audio input (BlackHole 2ch)
4. Adjust parameters as needed
5. Click "Performance Mode" for fullscreen output
6. Use Push 2 or GUI controls to manipulate visuals
7. Press Escape or ⌘Space to exit Performance Mode

## Project Structure

```
MotionHub/
├── MotionHub/                      # Main app source
│   ├── App/                        # App entry point
│   ├── Views/                      # SwiftUI views
│   │   ├── Components/             # Reusable UI components
│   │   └── Modals/                 # Save/Load pack modals
│   ├── Models/                     # Data models
│   ├── Services/                   # Audio, MIDI, Pack management
│   ├── Rendering/                  # Metal engine & shaders
│   │   └── Shaders/                # Metal shader files
│   └── Resources/                  # Colors, fonts, assets
├── preprocessing/                  # Python AI pipeline
│   ├── extract.py                  # Main extraction script
│   ├── requirements.txt            # Python dependencies
│   └── utils/                      # Utility modules
└── README.md                       # This file
```

## Technical Details

### Architecture

- **UI Framework**: SwiftUI
- **Graphics Engine**: Metal (optimized for Apple Silicon)
- **Audio Analysis**: AVFoundation + Accelerate (FFT)
- **MIDI**: CoreMIDI
- **AI Preprocessing**: Python (OpenCV, scikit-learn, Pillow)

### Performance Budget (30 FPS @ 1080p)

| Stage | Target | Max |
|-------|--------|-----|
| Audio analysis | 1ms | 2ms |
| State updates | <1ms | 1ms |
| Shader passes | 20ms | 28ms |
| Present | 2ms | 3ms |
| **Total** | **24ms** | **33ms** |

### Memory Budget (8GB Total)

| Component | Budget |
|-----------|--------|
| macOS + Background | ~3GB |
| Motion Hub App | ~500MB |
| Metal Textures | ~1GB |
| Audio Buffers | ~50MB |
| Headroom | ~3.5GB |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Escape | Exit performance mode |
| ⌘Space | Toggle performance mode |
| ⌘S | Save current pack |
| ⌘O | Open pack loader |
| ⌘R | Reset visuals |
| ⌘M | Toggle monochrome |

## Troubleshooting

### No Audio Levels Showing

- Ensure BlackHole 2ch is selected in the audio input menu
- Verify your DAW is outputting to the Multi-Output Device
- Check that audio is actually playing in your DAW

### MIDI Not Responding

- Connect Push 2 via USB
- Check that it appears in the MIDI device list
- Verify CC numbers match your Push 2 configuration

### Low FPS in Performance Mode

- Reduce target FPS in settings (try 15 or 20 FPS)
- Close other applications to free up resources
- Ensure you're using the internal display or a compatible external monitor

## Future Enhancements (Not in v1.0)

- Mid-performance pack swapping
- Artifact preview panel
- MIDI learn for custom CC assignments
- Multiple frequency band controls
- Video recording of output
- Preset system
- Network sync for multi-display setups

## License

Copyright © 2026 Motion Hub. All rights reserved.

## Contributing

This is a personal project. Feel free to fork and experiment!

## Acknowledgments

- Design inspired by Serum 2 and iZotope plugins
- Built for live performance with Ableton Live + Push 2
- Optimized for Apple Silicon Macs
