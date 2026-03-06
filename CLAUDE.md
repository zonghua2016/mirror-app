# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lock Screen Mirror is a native iOS app (SwiftUI + AVFoundation + Vision) that provides quick mirror preview functionality from lock screen and system entry points. The app uses iOS 18's Locked Camera Capture API to enable instant camera access without unlocking the device.

**Important**: This is a pure native iOS project. Do NOT run `pod install` or assume any React Native/Metro dependencies.

## Build and Run

### Opening the Project
```bash
open ios/LockScreenMirror.xcodeproj
```

### Building
- **Real device only**: This app requires camera hardware and cannot run on simulator
- In Xcode: Select `LockScreenMirror` target → Choose your device → `Cmd + R`
- **Signing**: Must set your Team in Signing & Capabilities for all three targets

### Bundle Identifiers
- App: `com.tongzonghua.lockscreenmirror.dev` (configurable in `ios/scripts/regenerate_xcodeproj.rb`)
- Widget: `com.tongzonghua.lockscreenmirror.dev.widgets`
- Capture Extension: `com.tongzonghua.lockscreenmirror.dev.capture`

### Regenerating the Xcode Project
If you add/remove files or need to reconfigure build settings:
```bash
cd ios
ruby scripts/regenerate_xcodeproj.rb
```
This script recreates the entire `.xcodeproj` from scratch using the `xcodeproj` gem.

## Architecture

### Target Structure
The app has three build targets that share code:

1. **LockScreenMirror** (Main App)
   - Entry points: `AppDelegate.swift`, `SceneDelegate.swift`, `AppCoordinator.swift`
   - Main view: `MirrorScreenView.swift`
   - Camera pipeline: `CameraSessionController.swift`, `CameraPreviewView.swift`, `FaceTrackingManager.swift`
   - UI: `MirrorOverlay.swift`, `MirrorViewModel.swift`

2. **LockScreenMirrorWidgetsExtension**
   - Lock Screen Widget (`MirrorLockScreenWidget`)
   - Control Center Widget for iOS 18+ (`MirrorCaptureControlWidget`)
   - Live Activity / Dynamic Island (`MirrorLiveActivityWidget`)
   - Entry: `ios/LockScreenMirrorWidgets/MirrorWidgets.swift`

3. **LockScreenMirrorCaptureExtension** (iOS 18+)
   - Provides secure camera capture UI directly from lock screen
   - Entry: `ios/LockScreenMirrorCaptureExtension/LockScreenMirrorCaptureExtension.swift`
   - Shares camera pipeline files with main app via Xcode project configuration

### Shared Code (`ios/Shared/`)
- `MirrorShapeStyle.swift`: Shape enum (circle, stadium, blob)
- `MirrorSharedConfig.swift`: UserDefaults persistence layer
- `MirrorLiveActivityModels.swift`: ActivityKit models for Live Activity
- `StartMirrorCaptureIntent.swift`: AppIntent for Control Center widget

### Core Data Flow

**Camera Pipeline**:
```
CameraSessionController (AVCaptureSession)
  → CameraPreviewView (UIViewRepresentable wrapping AVCaptureVideoPreviewLayer)
    → FaceTrackingManager (Vision framework face detection)
      → MirrorOverlay (shape masks + animations)
```

**State Management**:
- `MirrorViewModel`: Main UI state, settings persistence, animation triggers
- `AppCoordinator`: Deep link routing, launch source tracking
- `MirrorLiveActivityManager`: Syncs mirror state to Live Activity/Dynamic Island

### Deep Linking
- Scheme: `lockscreenmirror://open`
- Query params:
  - `source`: `widget`, `control`, `lockedcapture`, `shortcut`, `actionbutton`
  - `quick`: `1`/`true` to auto-reveal mirror bubble
- Example: `lockscreenmirror://open?source=widget&quick=1`

### Camera Performance Modes
- **Normal**: 30fps, 1280x720 resolution
- **Constrained**: 24fps, 640x480 resolution (thermal-aware switching)

## Key Frameworks and APIs

- **AVFoundation**: Camera capture and session management
- **Vision**: Real-time face detection and tracking
- **SwiftUI**: UI framework with `UIViewRepresentable` bridge for camera preview
- **ActivityKit**: Live Activity and Dynamic Island integration (iOS 16.1+)
- **AppIntents**: Shortcuts, Action Button support (iOS 17+)
- **WidgetKit**: Lock Screen and Control Center widgets
- **LockedCameraCapture**: iOS 18 API for lock screen camera extensions

## Important Implementation Details

### Camera Preview Layer
The app uses `AVCaptureVideoPreviewLayer` wrapped in `UIViewRepresentable` (see `CameraPreviewView.swift`), NOT pure SwiftUI, because:
- Direct pixel buffer rendering is needed for low latency
- Vision framework requires pixel buffer access
- Hardware-accelerated preview layer provides better performance

### Face Tracking
`FaceTrackingManager.swift` uses Vision framework's `VNDetectFaceLandmarksRequest` to:
1. Detect face bounding box in real-time
2. Apply exponential smoothing to prevent jittery movement
3. Update preview layer's `layerVideoRect` to center on face

### Shape Animations
Three mask shapes with smooth transitions:
- Circle: Standard elliptical preview
- Stadium (Capsule): Elongated vertical preview
- Blob: Rounded rectangle with larger corner radius

Shape changes trigger spring animations via SwiftUI's `.animation(.spring(...))` modifier.

### Live Activity Sync
`MirrorLiveActivityManager` syncs current state (shape + visibility) to:
- Lock Screen Live Activity banner
- Dynamic Island compact/minimal/expanded views
- Updates use `ActivityKit`'s `.update()` method

### Thermal Management
The app monitors `ProcessInfo.thermalState` and switches camera frame rate/resolution to prevent overheating during extended use.

## Common Development Tasks

### Adding a New Shape
1. Add case to `MirrorShapeStyle` enum in `ios/Shared/MirrorShapeStyle.swift`
2. Update `activityShape(for:)` in `ios/LockScreenMirrorWidgets/MirrorWidgets.swift`
3. Add shape rendering logic in `MirrorOverlay.swift`

### Modifying Camera Settings
- Frame rate: Edit `applyFrameRateOnQueue()` in `CameraSessionController.swift`
- Resolution: Modify `applySessionPresetOnQueue()` presets
- Zoom: Use `setZoomLevel()` method (respects device max zoom factor)

### Adding New Widget Type
1. Create widget struct conforming to `Widget` protocol
2. Add to `MirrorWidgetsBundle` in `ios/LockScreenMirrorWidgets/MirrorWidgets.swift`
3. Regenerate Xcode project if adding new files

### Testing Lock Screen Features
- **Lock Screen Widget**: Add widget from lock screen customize menu
- **Control Center Widget** (iOS 18): Long-press lock screen → Customize → Replace bottom-right camera slot
- **Locked Camera Capture**: Lock device, then press/hold the configured camera control
- **Live Activity**: Hold camera button in app to show mirror bubble, check lock screen for state sync

## iOS Version Requirements

- **Minimum**: iOS 17.0
- **Control Center Widget**: iOS 18.0+
- **Locked Camera Capture Extension**: iOS 18.0+
- **Live Activity/Dynamic Island**: iOS 16.1+ (optional feature)

## Known Platform Limitations

- Third-party apps cannot intercept system camera rendering on lock screen
- Live Activity cannot host full 30fps camera stream (only state display)
- Locked Camera Capture extension launches independently from main app
- System decides whether to launch main app vs. capture extension based on lock state

## File Organization

```
ios/
├── LockScreenMirror/           # Main app target
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── AppCoordinator.swift
│   ├── MirrorViewModel.swift
│   ├── MirrorScreenView.swift
│   ├── CameraSessionController.swift
│   ├── CameraPreviewView.swift
│   ├── FaceTrackingManager.swift
│   ├── MirrorOverlay.swift
│   └── MirrorIntents.swift
├── LockScreenMirrorWidgets/    # Widget extension
│   └── MirrorWidgets.swift
├── LockScreenMirrorCaptureExtension/  # iOS 18 capture extension
│   ├── LockScreenMirrorCaptureExtension.swift
│   └── MirrorCaptureView.swift
├── Shared/                     # Shared between targets
│   ├── MirrorShapeStyle.swift
│   ├── MirrorSharedConfig.swift
│   ├── MirrorLiveActivityModels.swift
│   └── StartMirrorCaptureIntent.swift
└── scripts/
    └── regenerate_xcodeproj.rb
```

## Entitlements

All targets use minimal entitlements (empty `<dict/>`). No special capabilities required beyond:
- Camera usage (handled via `Info.plist` `NSCameraUsageDescription`)
- App Groups not needed (uses standard UserDefaults)
