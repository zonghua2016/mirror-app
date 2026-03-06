import ExtensionKit
import LockedCameraCapture
import SwiftUI

@main
struct LockScreenMirrorCaptureExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            MirrorCaptureView(session: session)
        }
    }
}
