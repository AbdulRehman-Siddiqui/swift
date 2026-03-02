import Foundation
import AVFoundation

final class CameraEngine: NSObject {
    static let shared = CameraEngine()

    private let queue = DispatchQueue(label: "calxV2.camera.queue")
    private let session = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private let movieOutput = AVCaptureMovieFileOutput()

    private(set) var isConfigured = false
    private(set) var isRecording = false

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var cam = false, mic = false
        group.enter()
        AVCaptureDevice.requestAccess(for: .video) { ok in cam = ok; group.leave() }
        group.enter()
        AVCaptureDevice.requestAccess(for: .audio) { ok in mic = ok; group.leave() }
        group.notify(queue: .main) { completion(cam && mic) }
    }

    func configureIfNeeded(completion: @escaping (Bool, String?) -> Void) {
        queue.async {
            if self.isConfigured { completion(true, nil); return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            do {
                guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    self.session.commitConfiguration()
                    completion(false, "Back camera not found")
                    return
                }
                let vin = try AVCaptureDeviceInput(device: cam)
                if self.session.canAddInput(vin) { self.session.addInput(vin); self.videoInput = vin }

                if let micDev = AVCaptureDevice.default(for: .audio) {
                    let ain = try AVCaptureDeviceInput(device: micDev)
                    if self.session.canAddInput(ain) { self.session.addInput(ain); self.audioInput = ain }
                }

                if self.session.canAddOutput(self.movieOutput) { self.session.addOutput(self.movieOutput) }

                self.session.commitConfiguration()
                self.isConfigured = true
                completion(true, nil)
            } catch {
                self.session.commitConfiguration()
                completion(false, "Configure failed: \(error)")
            }
        }
    }

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let l = AVCaptureVideoPreviewLayer(session: session)
        l.videoGravity = .resizeAspectFill
        return l
    }

    func startSession() { queue.async { if !self.session.isRunning { self.session.startRunning() } } }
    func stopSession() { queue.async { if self.session.isRunning { self.session.stopRunning() } } }

    func startRecording(completion: @escaping (Bool, String?) -> Void) {
        queue.async {
            guard !self.movieOutput.isRecording else { completion(false, "Already recording"); return }
            if !self.session.isRunning { self.session.startRunning() }

            let url = self.nextRecordingURL()
            RecordingDelegate.shared.onFinish = { outURL, err in
                DispatchQueue.main.async {
                    if let err = err { completion(false, err) }
                    else { completion(true, outURL?.path ?? "Saved") }
                }
            }

            do {
                let audio = AVAudioSession.sharedInstance()
                try audio.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker])
                try audio.setActive(true)
            } catch { }

            self.movieOutput.startRecording(to: url, recordingDelegate: RecordingDelegate.shared)
            self.isRecording = true
        }
    }

    func stopRecording() { queue.async { if self.movieOutput.isRecording { self.movieOutput.stopRecording() } } }

    fileprivate func markStopped() { queue.async { self.isRecording = false } }

    func setZoom(_ zoom: CGFloat) {
        queue.async {
            guard let device = self.videoInput?.device else { return }
            let maxZ = device.activeFormat.videoMaxZoomFactor
            let z = max(1.0, min(zoom, maxZ))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = z
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func setPreferredFps(_ fps: Int32) {
        queue.async {
            guard let device = self.videoInput?.device else { return }
            var bestFormat: AVCaptureDevice.Format?
            var bestDiff: Int32 = .max
            var bestRange: AVFrameRateRange?

            for format in device.formats {
                for r in format.videoSupportedFrameRateRanges {
                    let minF = Int32(r.minFrameRate.rounded())
                    let maxF = Int32(r.maxFrameRate.rounded())
                    let supported = (fps >= minF && fps <= maxF)
                    let diff: Int32
                    if supported { diff = 0 }
                    else if fps < minF { diff = minF - fps }
                    else { diff = fps - maxF }
                    if diff < bestDiff { bestDiff = diff; bestFormat = format; bestRange = r }
                }
            }
            guard let f = bestFormat else { return }
            do {
                try device.lockForConfiguration()
                device.activeFormat = f
                if let r = bestRange {
                    let minF = Double(r.minFrameRate)
                    let maxF = Double(r.maxFrameRate)
                    let chosen = max(minF, min(Double(fps), maxF))
                    let dur = CMTime(value: 1, timescale: CMTimeScale(chosen.rounded()))
                    device.activeVideoMinFrameDuration = dur
                    device.activeVideoMaxFrameDuration = dur
                }
                device.unlockForConfiguration()
            } catch { }
        }
    }

    private func nextRecordingURL() -> URL {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let name = "recording_\(df.string(from: Date())).mp4"
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(name)
    }
}

final class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    static let shared = RecordingDelegate()
    var onFinish: ((URL?, String?) -> Void)?

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        defer { CameraEngine.shared.markStopped(); onFinish = nil }
        if let error = error { onFinish?(nil, error.localizedDescription) }
        else { onFinish?(outputFileURL, nil) }
    }
}
