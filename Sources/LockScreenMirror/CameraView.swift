import SwiftUI
import AVFoundation
import UIKit

/// A custom SwiftUI view that wraps AVFoundation's AVCaptureVideoPreviewLayer
/// to provide a high-performance camera feed with minimal latency
struct CameraView: UIViewRepresentable {
    @StateObject private var cameraManager = CameraManager()

    func makeUIView(context: Context) -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait

        // Enable low-latency mode for lock screen experience
        if let connection = previewLayer.connection {
            connection.isVideoMinFrameDurationSupported = true
            connection.videoMinFrameDuration = CMTimeMake(value: 1, timescale: 60) // 60fps
        }

        return previewLayer
    }

    func updateUIView(_ uiView: AVCaptureVideoPreviewLayer, context: Context) {
        // Update orientation when needed
        uiView.connection?.videoOrientation = .portrait
    }

    // This view is not interactive, so we don't need to handle touches
    // The interactive elements are handled by the overlay
}

/// Manages the AVFoundation camera session and configuration
@MainActor
class CameraManager: NSObject, ObservableObject {
    var session: AVCaptureSession
    var videoDevice: AVCaptureDevice!
    var videoInput: AVCaptureDeviceInput!

    private let lockScreenCamera: AVCaptureDevice? = {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        ).devices
        return devices.first
    }()

    override init() {
        // Initialize session with high performance settings
        session = AVCaptureSession()
        session.sessionPreset = .photo

        super.init()

        setupCamera()
    }

    private func setupCamera() {
        guard let device = lockScreenCamera else {
            fatalError("Front camera not available")
        }

        videoDevice = device

        do {
            // Create device input with optimized settings for low latency
            videoInput = try AVCaptureDeviceInput(device: device)

            // Configure device for optimal performance
            configureDevice()

            // Add input to session
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }

            // Add output for preview (no need to capture frames for this app)
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            // Start session on a background queue to avoid blocking main thread
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }

        } catch {
            print("Error setting up camera: \(error)")
        }
    }

    private func configureDevice() {
        // Set up device for optimal performance on lock screen
        do {
            try videoDevice.lockForConfiguration()

            // Use highest possible frame rate for smooth motion
            if videoDevice.isFrameRateRangeSupported(videoDevice.activeFrameRateRange) {
                videoDevice.activeFrameRateRange = CMFrameRateRange(minFrameRate: 60, maxFrameRate: 60)
            }

            // Enable low-light mode for better image quality
            if videoDevice.isLowLightBoostSupported {
                videoDevice.isLowLightBoostEnabled = true
            }

            // Reduce exposure compensation to prevent washout
            videoDevice.exposureMode = .continuousAutoExposure
            videoDevice.exposureTargetBias = -0.5

            // Enable autofocus
            videoDevice.focusMode = .continuousAutoFocus

            // Reduce white balance adjustments for consistency
            videoDevice.whiteBalanceMode = .continuousAutoWhiteBalance

            videoDevice.unlockForConfiguration()
        } catch {
            print("Error configuring device: \(error)")
        }
    }

    deinit {
        session.stopRunning()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // This method is called for each frame
        // We don't need to process the frames in this app, but we need to handle them to prevent buffer overflow
        // The session will automatically drop frames if we don't process them quickly enough
        // This is acceptable for our use case as we're only displaying the feed
    }
}

// MARK: - Extension to handle camera permissions
extension CameraManager {
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
}