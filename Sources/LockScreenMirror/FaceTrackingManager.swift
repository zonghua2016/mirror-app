import SwiftUI
import Vision
import AVFoundation

/// Manages face tracking using Apple's Vision framework
/// Implements Center Stage-like behavior with smooth tracking
@MainActor
class FaceTrackingManager: NSObject, ObservableObject {
    // MARK: - Properties

    private var request: VNDetectFaceRectanglesRequest
    private var lastFaceCenter: CGPoint = .zero
    private var smoothedFaceCenter: CGPoint = .zero
    private let smoothingFactor: CGFloat = 0.2

    private let session: AVCaptureSession
    private let videoPreviewLayer: AVCaptureVideoPreviewLayer

    // State for tracking
    @Published var detectedFace: CGRect? = nil
    @Published var faceTrackingActive: Bool = false

    // MARK: - Initialization

    init(session: AVCaptureSession, videoPreviewLayer: AVCaptureVideoPreviewLayer) {
        self.session = session
        self.videoPreviewLayer = videoPreviewLayer

        // Initialize Vision request for face detection
        request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handleVisionRequest(request, error: error)
            }
        }

        // Configure request for optimal performance
        request.reportCharacteristics = true
        request.reportLandmarks = true
        request.maximumObservations = 1 // Only track one face

        super.init()

        // Start face tracking
        startTracking()
    }

    // MARK: - Public Methods

    func startTracking() {
        faceTrackingActive = true
    }

    func stopTracking() {
        faceTrackingActive = false
    }

    // MARK: - Private Methods

    private func handleVisionRequest(_ request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation],
              !observations.isEmpty else {
            // No face detected, reset tracking
            detectedFace = nil
            return
        }

        // Use the first (and only) face observation
        let faceObservation = observations[0]

        // Convert Vision coordinates to preview layer coordinates
        let faceRect = convertVisionRectToPreviewLayerRect(faceObservation.boundingBox)

        // Update detected face
        detectedFace = faceRect

        // Calculate face center
        let faceCenter = CGPoint(
            x: faceRect.midX,
            y: faceRect.midY
        )

        // Apply smoothing to avoid jittery movements
        smoothedFaceCenter.x = smoothedFaceCenter.x * (1 - smoothingFactor) + faceCenter.x * smoothingFactor
        smoothedFaceCenter.y = smoothedFaceCenter.y * (1 - smoothingFactor) + faceCenter.y * smoothingFactor

        // Calculate camera offset for Center Stage effect
        let offsetX = (videoPreviewLayer.bounds.midX - smoothedFaceCenter.x) / videoPreviewLayer.bounds.width
        let offsetY = (videoPreviewLayer.bounds.midY - smoothedFaceCenter.y) / videoPreviewLayer.bounds.height

        // Apply the offset to the video preview layer's transform
        // This creates the "stickiness" effect
        let scale = min(1.5, max(1.0, 1.0 + abs(offsetX) * 0.5 + abs(offsetY) * 0.5))

        // Create a transform that centers the face
        let transform = CGAffineTransform(
            translationX: offsetX * videoPreviewLayer.bounds.width * 0.5,
            y: offsetY * videoPreviewLayer.bounds.height * 0.5
        ).scaledBy(x: scale, y: scale)

        videoPreviewLayer.transform = transform
    }

    /// Convert a bounding box from Vision coordinates to preview layer coordinates
    private func convertVisionRectToPreviewLayerRect(_ visionRect: CGRect) -> CGRect {
        // Vision coordinates are normalized (0-1), we need to convert to pixel coordinates
        let previewSize = videoPreviewLayer.bounds.size

        // Vision coordinates: (0,0) is top-left, (1,1) is bottom-right
        // Convert to preview layer coordinates
        let x = visionRect.origin.x * previewSize.width
        let y = visionRect.origin.y * previewSize.height
        let width = visionRect.size.width * previewSize.width
        let height = visionRect.size.height * previewSize.height

        // Vision coordinates are upside down compared to UIKit
        let flippedY = previewSize.height - (y + height)

        return CGRect(x: x, y: flippedY, width: width, height: height)
    }

    // MARK: - Vision Processing

    func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        guard faceTrackingActive else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Error performing Vision request: \(error)")
        }
    }

    deinit {
        stopTracking()
    }
}