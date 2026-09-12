import Foundation
import AVFoundation
import CoreImage
import AppKit

public enum CameraPermissionState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

public protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer)
}

public final class CameraManager: NSObject, @unchecked Sendable {
    public static let shared = CameraManager()

    public weak var delegate: CameraManagerDelegate?

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let cameraQueue = DispatchQueue(label: "com.faceid.cameraQueue", qos: .userInteractive)

    private var activeDevice: AVCaptureDevice?
    private var isRunning = false
    private let lock = NSRecursiveLock() // Use recursive lock to prevent re-entrant deadlocks

    private var frameListeners: [UUID: (CMSampleBuffer) -> Void] = [:]

    public private(set) var permissionState: CameraPermissionState = .notDetermined

    public override init() {
        super.init()
        updatePermissionState()
    }

    public func updatePermissionState() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
        case .notDetermined:
            permissionState = .notDetermined
        case .denied:
            permissionState = .denied
        case .restricted:
            permissionState = .restricted
        @unknown default:
            permissionState = .denied
        }
    }

    public func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.updatePermissionState()
                completion(granted)
            }
        }
    }

    public func openSystemCameraSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    public func availableCameras() -> [AVCaptureDevice] {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.builtInWideAngleCamera, .external]
        } else {
            deviceTypes = [.builtInWideAngleCamera, .externalUnknown]
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices
    }

    public func addListener(_ handler: @escaping (CMSampleBuffer) -> Void) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let id = UUID()
        frameListeners[id] = handler
        return id
    }

    public func removeListener(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        frameListeners.removeValue(forKey: id)
    }

    public func setupSession(preferredDevice: AVCaptureDevice? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        updatePermissionState()
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            print("[CameraManager] Camera access not authorized yet.")
            return false
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480

        // Remove existing inputs and outputs
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }

        // Select camera with fallbacks
        let device = preferredDevice ??
                     AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) ??
                     AVCaptureDevice.default(for: .video) ??
                     availableCameras().first

        guard let validDevice = device else {
            captureSession.commitConfiguration()
            permissionState = .unavailable
            print("[CameraManager] No camera device found.")
            return false
        }

        self.activeDevice = validDevice

        do {
            let input = try AVCaptureDeviceInput(device: validDevice)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)

            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }

            captureSession.commitConfiguration()
            print("[CameraManager] Session configured with device: \(validDevice.localizedName)")
            return true
        } catch {
            captureSession.commitConfiguration()
            print("[CameraManager] Error creating device input: \(error)")
            return false
        }
    }

    public func startCapture() {
        cameraQueue.async { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }

            if self.captureSession.inputs.isEmpty {
                _ = self.setupSession()
            }

            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                self.isRunning = true
                print("[CameraManager] Capture session started running.")
            }
        }
    }

    public func stopCapture() {
        cameraQueue.async { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }

            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                self.isRunning = false
                print("[CameraManager] Capture session stopped.")
            }
        }
    }

    public var isCapturing: Bool {
        return captureSession.isRunning
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        delegate?.cameraManager(self, didOutput: sampleBuffer)

        lock.lock()
        let listeners = Array(frameListeners.values)
        lock.unlock()

        for handler in listeners {
            handler(sampleBuffer)
        }
    }
}
