import AVFoundation
import Foundation

enum CameraPerformanceMode {
    case normal
    case constrained
}

final class CameraSessionController: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()

    @Published private(set) var isRunning = false
    @Published private(set) var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    private let sessionQueue = DispatchQueue(label: "mirror.camera.session", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private var currentPerformanceMode: CameraPerformanceMode = .normal
    private var isConfigured = false

    @MainActor
    func requestPermissionIfNeeded() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorizationStatus = status

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            authorizationStatus = granted ? .authorized : .denied
            return granted
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func configureSession() {
        sessionQueue.async { [weak self] in
            self?.configureSessionOnQueue()
        }
    }

    func startRunning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            self.setRunning(true)
        }
    }

    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            self.setRunning(false)
        }
    }

    func setPerformanceMode(_ mode: CameraPerformanceMode) {
        sessionQueue.async { [weak self] in
            self?.applyPerformanceModeOnQueue(mode)
        }
    }

    func setZoomLevel(_ zoomLevel: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let input = self?.session.inputs.first as? AVCaptureDeviceInput else {
                return
            }

            let device = input.device

            do {
                try device.lockForConfiguration()
                // 将 zoomLevel 映射到设备的实际焦距范围
                let normalizedZoom = max(1.0, min(zoomLevel, device.activeFormat.videoMaxZoomFactor))
                device.ramp(toVideoZoomFactor: normalizedZoom, withRate: 5.0)
                device.unlockForConfiguration()
            } catch {
                // 忽略错误
            }
        }
    }

    private func configureSessionOnQueue() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        applySessionPresetOnQueue(currentPerformanceMode)

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            session.commitConfiguration()
            return
        }

        do {
            try frontCamera.lockForConfiguration()
            if frontCamera.isSmoothAutoFocusSupported {
                frontCamera.isSmoothAutoFocusEnabled = true
            }
            applyFrameRateOnQueue(for: frontCamera, mode: currentPerformanceMode)
            frontCamera.unlockForConfiguration()

            let input = try AVCaptureDeviceInput(device: frontCamera)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true

            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                return
            }
            session.addOutput(output)

            if let connection = output.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
        } catch {
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()
        isConfigured = true
    }

    private func applyPerformanceModeOnQueue(_ mode: CameraPerformanceMode) {
        currentPerformanceMode = mode
        applySessionPresetOnQueue(mode)

        guard
            let input = session.inputs.first as? AVCaptureDeviceInput
        else {
            return
        }

        do {
            try input.device.lockForConfiguration()
            applyFrameRateOnQueue(for: input.device, mode: mode)
            input.device.unlockForConfiguration()
        } catch {
            return
        }
    }

    private func applySessionPresetOnQueue(_ mode: CameraPerformanceMode) {
        let preset: AVCaptureSession.Preset = (mode == .normal) ? .hd1280x720 : .vga640x480
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        }
    }

    private func applyFrameRateOnQueue(for device: AVCaptureDevice, mode: CameraPerformanceMode) {
        let fps: Int32 = (mode == .normal) ? 30 : 24
        let supportsTargetFPS = device.activeFormat.videoSupportedFrameRateRanges.contains { range in
            range.minFrameRate <= Double(fps) && Double(fps) <= range.maxFrameRate
        }

        guard supportsTargetFPS else { return }

        let frameDuration = CMTime(value: 1, timescale: fps)
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
    }

    private func setRunning(_ running: Bool) {
        Task { @MainActor in
            self.isRunning = running
        }
    }
}
