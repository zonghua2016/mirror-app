# Lock Screen Mirror

Native iOS app (SwiftUI + AVFoundation + Vision) for quick mirror preview with lock screen and system entry points.

![capture](https://p0.ssl.qhimg.com/t110b9a93010769bef6351f614f.png)

## What is implemented
- Front camera mirror preview with smooth drag and pinch.
- Dynamic mask shapes (circle, stadium, blob) with spring animations.
- Hold-to-preview interaction: press and hold bottom-right camera button to show mirror bubble, release to hide.
- Vision face detection with smoothed auto-centering.
- UltraThinMaterial toolbar and simulated screen flash.
- Lock Screen Widget deep link (`lockscreenmirror://open?source=widget`).
- iOS 18 Locked Camera Capture extension (launches secure capture UI from lock screen camera control).
- Control Widget (iOS 18+) for lock-screen camera slot (`CameraCaptureIntent`).
- Live Activity + Dynamic Island visual state sync (shape + visible state).
- App Shortcut intent (can be bound to Action Button via Shortcuts).
- Thermal-aware performance mode switching (30fps normal / 24fps constrained).

## Project structure
- Xcode project: `ios/LockScreenMirror.xcodeproj`
- App target: `LockScreenMirror`
- Widget extension target: `LockScreenMirrorWidgetsExtension`
- Locked capture extension target: `LockScreenMirrorCaptureExtension`

## Requirements
- Xcode 17+
- iOS 17+ (Control Center Widget requires iOS 18+)
- Apple Developer signing (for real-device install)

## Important
- This is a native project. **Do not run `pod install`**.
- No React Native/Metro runtime is required.

## Run in Xcode (real device)
1. Open `ios/LockScreenMirror.xcodeproj`.
2. Select target `LockScreenMirror` and set your Team in **Signing & Capabilities**.
3. Ensure unique bundle identifiers:
   - App: `com.mirrorapp.lockscreenmirror`
   - Widget: `com.mirrorapp.lockscreenmirror.widgets`
4. Connect iPhone, select your device as Run destination.
5. Build and Run (`Cmd + R`).
6. On first launch, grant camera permission.

## Verify features on device
1. **In-app mirror**
   - Check front camera preview appears immediately.
   - Test drag, pinch, shape switching, and flash overlay.
   - Press and hold the bottom-right camera button, verify mirror bubble appears near Dynamic Island (or screen center on non-Dynamic-Island devices), and disappears on release.
2. **Lock Screen Widget**
   - Add widget `Lock Screen Mirror` on lock screen.
   - Tap widget and confirm app opens to mirror page.
3. **Lock Screen Camera Control (iOS 18+)**
   - Long-press lock screen, tap `Customize` -> `Lock Screen`.
   - Replace bottom-right camera slot with `Mirror Capture` control from this app.
   - Lock device and press/hold that bottom-right control.
   - Verify secure capture UI opens and mirror appears immediately under Dynamic Island (or center fallback), without opening the main app.
4. **Unlocked + Notification Center Path (iOS 18+)**
   - Keep device unlocked, swipe down to show Notification Center (lock-screen style surface).
   - Long-press bottom-right camera control.
   - Verify capture extension opens.
   - In extension, press and drag the bottom-right camera button to the left to reveal a circular mirror under Dynamic Island (fallback upper-center on non-Dynamic-Island phones), then release to hide.
5. **Dynamic Island + Live Activity (iOS 16.1+)**
   - In app, hold the camera button to show mirror bubble.
   - Confirm Live Activity state updates (shape and visibility) on lock screen / Dynamic Island.
6. **Action Button (iPhone 15 Pro+)**
   - Create/use shortcut `Open Mirror` from this app.
   - Assign that shortcut to Action Button in Settings.
   - Press Action Button and confirm app opens mirror page.

## Known platform limits
- Third-party apps cannot intercept or override Apple Camera private lock-screen rendering pipeline.
- Live Activity / Dynamic Island cannot host a full 30fps camera stream from app process; real preview is delivered via the locked camera capture scene.
- The lock-screen entry is implemented with iOS 18 public APIs: `LockedCameraCaptureExtension` + `CameraCaptureIntent`.
- System decides whether to launch the main app or capture extension based on current context (lock screen/home screen); this behavior cannot be overridden by app code.

## Troubleshooting (No response on long press)
1. Make sure you selected **Mirror Capture** in the lock screen bottom-right control slot (not system Camera).
2. Reinstall after clean build:
   - `Product -> Clean Build Folder`
   - Delete app from device
   - Run again from Xcode
3. Keep entitlements files minimal (no manually added locked-camera entitlement key).
4. If your team profile doesn’t support a capability, remove that capability and re-run with regenerated provisioning profiles.
5. iPhone 12 has no Dynamic Island. Expected behavior is circular mirror in upper-center fallback position.
