import AVFoundation
import Foundation
import Vision

final class FaceTrackingManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    typealias FaceUpdateHandler = @MainActor @Sendable (_ normalizedOffset: CGPoint, _ detected: Bool) -> Void

    let processingQueue = DispatchQueue(label: "mirror.face.tracking", qos: .userInitiated)

    private let requestHandler = VNSequenceRequestHandler()
    private var frameIndex: Int = 0
    private let detectionStride = 2
    private var smoothedPoint = CGPoint.zero
    private let smoothingAlpha: CGFloat = 0.16

    private let callbackLock = NSLock()
    private var onFaceUpdate: FaceUpdateHandler?

    func setUpdateHandler(_ handler: FaceUpdateHandler?) {
        callbackLock.lock()
        onFaceUpdate = handler
        callbackLock.unlock()
    }

    private func currentHandler() -> FaceUpdateHandler? {
        callbackLock.lock()
        let handler = onFaceUpdate
        callbackLock.unlock()
        return handler
    }

    private func smooth(_ target: CGPoint) -> CGPoint {
        smoothedPoint.x += smoothingAlpha * (target.x - smoothedPoint.x)
        smoothedPoint.y += smoothingAlpha * (target.y - smoothedPoint.y)
        return smoothedPoint
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameIndex += 1
        if frameIndex % detectionStride != 0 { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest()

        do {
            try requestHandler.perform([request], on: pixelBuffer, orientation: .leftMirrored)
            let faces = request.results ?? []

            guard let largestFace = faces.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
                if let handler = currentHandler() {
                    Task { @MainActor in handler(.zero, false) }
                }
                return
            }

            let box = largestFace.boundingBox
            let centerX = box.midX
            let centerY = box.midY

            var x = (0.5 - centerX) * 2
            var y = (0.5 - centerY) * 2

            x = max(-0.38, min(0.38, x))
            y = max(-0.42, min(0.42, y))

            let point = smooth(CGPoint(x: x, y: y))

            if let handler = currentHandler() {
                Task { @MainActor in handler(point, true) }
            }
        } catch {
            if let handler = currentHandler() {
                Task { @MainActor in handler(.zero, false) }
            }
        }
    }
}
