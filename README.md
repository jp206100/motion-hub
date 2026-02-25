# Motion Hub

**Real-time, audio-reactive visuals for live music performance.**

Motion Hub is a standalone macOS application that transforms inspiration media into procedural, audio-reactive visuals. Upload images, videos, or GIFs — an AI preprocessing pipeline extracts colors, textures, and motion patterns — then a Metal-accelerated engine renders visuals that respond to your music in real time.

Built for musicians performing with Ableton Live and Push 2.
<iframe width="560" height="315" src="https://www.youtube.com/embed/LS4A73RZh1g?si=ERjNSjRvqYyZbiHU" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
---

## Features

### Visual Engine
- **8 procedural pattern types** — Organic Flow, Cellular Division, Glitch, Kaleidoscope, Perlin Noise, Simplex Noise, Interference Patterns, Particle Clouds
- **Multi-pass Metal rendering** — Base layer, texture composite, glitch pass, and post-processing (color grading)
- **Audio-reactive modulation** — Real-time FFT analysis splits audio into bass, mid, high, and custom frequency bands with asymmetric attack/decay smoothing
- **30 FPS @ 1080p** on Apple Silicon with a 33ms frame budget

### AI Preprocessing
- **Color palette extraction** via K-means clustering
- **6 abstract deconstruction techniques** — Edge detection, texture generation, gradient analysis, motion pattern extraction, ghosted overlays, and color field decomposition
- **Inspiration-driven rendering** — Extracted artifacts directly influence the procedural visual output
- Supports JPG, PNG, HEIC, MP4, MOV, and animated GIFs

### Live Control
- **Ableton Push 2** — Direct MIDI CC mapping (CC 71–79) for hands-on parameter control
- **OSC** — Network control on port 9000 (`/motionhub/*` address space) via [M4L MotionHub Controller](https://github.com/jp206100/M4L-MotionHub-Controller) or any OSC-compatible app
- **GUI knobs** — On-screen rotary controls for all parameters
- **Keyboard shortcuts** — Quick access to common actions

### Pack System
- Save and load complete visual configurations (media, artifacts, and parameter settings)
- Stored in `~/Library/Application Support/MotionHub/packs/`

### Performance Mode
- Fullscreen output for live shows
- Minimal UI — all control via MIDI, OSC, or keyboard

---

## System Requirements

| Requirement | Minimum |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Chip | Apple Silicon (M1 / M2 / M3) |
| RAM | 8 GB |
| Audio routing | BlackHole or similar loopback driver (optional) |

### Development Prerequisites

- Xcode 15+
- Python 3.11+
- FFmpeg (`brew install ffmpeg`)

---

## Getting Started

### Installation

1. Go to [Releases](https://github.com/jp206100/motion-hub/releases) and download the latest `.dmg` file
2. Open the DMG and drag **Motion Hub** into your Applications folder
3. Launch Motion Hub — on first run, macOS may ask you to confirm since it's from an identified developer
4. Grant microphone access when prompted (required for audio-reactive visuals)

To build from source instead, see [SETUP.md](SETUP.md).

### Audio Setup (BlackHole)

1. Install [BlackHole 2ch](https://github.com/ExistentialAudio/BlackHole)
2. Open **Audio MIDI Setup** (`/Applications/Utilities/`)
3. Create a **Multi-Output Device** containing your audio interface + BlackHole 2ch
4. Set your DAW output to the Multi-Output Device
5. In Motion Hub, select **BlackHole 2ch** as the audio input

### MIDI Setup (Push 2)

Connect Push 2 via USB and configure the encoders to send the following CC numbers:

| CC | Parameter | Range |
|----|-----------|-------|
| 71 | Intensity | 0–127 (0–100%) |
| 72 | Glitch Amount | 0–127 (0–100%) |
| 73 | Speed | 0–31 = 1x, 32–63 = 2x, 64–95 = 3x, 96–127 = 4x |
| 74 | Color Shift | 0–127 (0–100%) |
| 75 | Freq Min | 0–127 (20–20,000 Hz, logarithmic) |
| 76 | Freq Max | 0–127 (20–20,000 Hz, logarithmic) |
| 77 | Monochrome | 0–63 = Off, 64–127 = On |
| 78 | Reset | Any value triggers reset |

### OSC Setup (Max for Live)

Motion Hub listens on **UDP port 9000** for OSC messages.

A dedicated **Max for Live device** is available for controlling Motion Hub directly from Ableton Live:

> **[M4L MotionHub Controller](https://github.com/jp206100/M4L-MotionHub-Controller)** — Download the Max for Live devices (.amxd) and learn more about setup and usage.

Address format: `/motionhub/<parameter>` (e.g., `/motionhub/intensity`, `/motionhub/glitch`)

---

## Usage

### First Launch

1. Launch Motion Hub
2. Click **Browse Files** to select inspiration media (images, videos, GIFs)
3. Wait for AI preprocessing to extract visual artifacts
4. Adjust parameters with the on-screen knobs or a MIDI controller
5. Click **Save Pack** (⌘S) to save your configuration

### Live Performance

1. Load a prepared pack (⌘O)
2. Connect Push 2 via USB
3. Select **BlackHole 2ch** as audio input
4. Enter **Performance Mode** (⌘⇧F) for fullscreen output
5. Control visuals with Push 2, OSC, or keyboard
6. Press **Escape** to exit

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘S | Save current pack |
| ⌘O | Open pack loader |
| ⌘⇧F | Toggle fullscreen / performance mode |
| ⌘R | Reset visuals |
| ⌘M | Toggle monochrome |
| Escape | Exit performance mode |

---

## Project Structure

```
motion-hub/
├── MotionHub.xcodeproj/                # Xcode project
├── MotionHub/
│   └── MotionHub/
│       ├── App/                        # App entry point + font registration
│       ├── Models/                     # AppState, InspirationPack data models
│       ├── Views/                      # SwiftUI views
│       │   ├── ContentView.swift       # Main 3-panel layout
│       │   ├── InspirationPanel.swift  # Media browser (left, 10 slots)
│       │   ├── PreviewPanel.swift      # Metal preview + stats (center)
│       │   ├── ControlsPanel.swift     # Parameter knobs (right)
│       │   ├── FullscreenView.swift    # Performance mode
│       │   ├── Components/             # KnobView, ControlButton, MediaThumbView
│       │   └── Modals/                 # Save/Load pack dialogs
│       ├── Services/                   # AudioAnalyzer, MIDIHandler, OSCHandler,
│       │                               # PackManager, PreprocessingManager, DebugLogger
│       ├── Rendering/
│       │   ├── VisualEngine.swift      # Core Metal rendering engine
│       │   ├── TextureLoader.swift     # GPU texture loading
│       │   ├── ShaderTypes.h           # Shared shader uniforms
│       │   └── Shaders/               # Metal shader files
│       │       ├── BaseLayer.metal     # 8 procedural pattern types
│       │       ├── Common.metal        # Noise, voronoi, shared functions
│       │       ├── Glitch.metal        # Digital distortion effects
│       │       ├── PostProcess.metal   # Color grading
│       │       └── TextureComposite.metal  # Texture blending + audio modulation
│       └── Resources/                  # Colors, fonts, assets
├── preprocessing/                      # Python AI pipeline
│   ├── extract.py                      # Main extraction script
│   ├── requirements.txt                # NumPy, OpenCV, scikit-learn, Pillow
│   └── utils/                          # Processing utilities
├── Scripts/                            # Build and setup scripts
├── Tools/                              # OSC test utilities
├── SETUP.md                            # Detailed development setup guide
└── README.md
```

---

## Architecture

### Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Graphics | Metal 3 / MetalKit |
| Audio analysis | AVFoundation + Accelerate (FFT) |
| MIDI | CoreMIDI |
| Networking | OSC over UDP |
| AI preprocessing | Python — OpenCV, scikit-learn, Pillow, FFmpeg |

### Rendering Pipeline

Motion Hub uses a **multi-pass Metal rendering pipeline**:

1. **Base Layer** — Procedural pattern generation (one of 8 types)
2. **Texture Composite** — Blends extracted textures with audio-modulated parameters
3. **Glitch Pass** — Applies digital distortion effects
4. **Post-Process** — Color grading and final output

### Audio Analysis

- 2048-sample FFT via the Accelerate framework
- Hann windowing for spectral smoothing
- Asymmetric smoothing: fast attack (0.15), slow decay (0.92)
- Frequency split into bass / mid / high + custom band

### State Management

- Central `AppState` (ObservableObject) with `@Published` properties
- Services (Audio, MIDI, OSC) update state in real time
- SwiftUI views react to state changes automatically

### Performance Budgets

**Frame budget (30 FPS @ 1080p):**

| Stage | Target | Max |
|---|---|---|
| Audio analysis | 1 ms | 2 ms |
| State updates | < 1 ms | 1 ms |
| Shader passes | 20 ms | 28 ms |
| Present | 2 ms | 3 ms |
| **Total** | **24 ms** | **33 ms** |

**Memory budget (8 GB system):**

| Component | Budget |
|---|---|
| macOS + background apps | ~3 GB |
| Motion Hub app | ~500 MB |
| Metal textures | ~1 GB |
| Audio buffers | ~50 MB |
| Headroom | ~3.5 GB |

---

## Troubleshooting

### No audio levels showing
- Verify BlackHole 2ch is selected as audio input in Motion Hub
- Confirm your DAW is outputting to the Multi-Output Device
- Check that audio is actually playing

### MIDI not responding
- Ensure Push 2 is connected via USB and appears in the MIDI device list
- Verify CC numbers match the mapping table above

### Low FPS in performance mode
- Close other GPU-intensive applications
- Reduce target FPS in settings
- Use the internal display or a compatible external monitor

---

## Security

Motion Hub is sandboxed and requests only the permissions it needs:

- **Audio input** — for real-time FFT analysis
- **User-selected file access** — for loading inspiration media
- **Local network server** — OSC listener bound to `127.0.0.1` (localhost only)

The app does not phone home, collect telemetry, or open any external network connections. Debug logs redact user home directory paths before export.

---

## Future Enhancements

- Mid-performance pack swapping
- Artifact preview panel
- MIDI learn for custom CC assignments
- Multiple frequency band controls
- Video recording of output
- Preset system
- Network sync for multi-display setups

---

## License

Copyright 2026 Motion Hub. All rights reserved.

## Contributing

This is a personal project. Feel free to fork and experiment!

## Acknowledgments

- Visual design inspired by Serum 2 and iZotope plugins
- Built for live performance with Ableton Live + Push 2
- Optimized for Apple Silicon Macs
