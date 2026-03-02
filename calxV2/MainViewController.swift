import UIKit
import AVFoundation

final class MainViewController: UIViewController {

    enum UiMode { case oled, camera, utility }
    private var mode: UiMode = .oled { didSet { applyMode() } }

    private let previewHost = UIView()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private let oledOverlay = UIView()
    private let recBadge = RecBadgeView()
    private let utilityView = UtilityView()
    private let controls = ControlsView()

    private let privacy = PrivacyOverlay.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupUI()
        setupGestures()
        setupLifecycleObservers()
        applyMode()

        CameraEngine.shared.requestPermissions { [weak self] ok in
            guard let self else { return }
            if !ok { print("[calxV2] permissions denied"); return }

            CameraEngine.shared.configureIfNeeded { ok, msg in
                print("[calxV2] configure -> \(ok) \(msg ?? "nil")")
                if ok {
                    CameraEngine.shared.startSession()
                    DispatchQueue.main.async { self.attachPreviewIfNeeded() }
                    // Start recording automatically when the app opens
                    self.mode = .camera
                    self.toggleRecording()
                }
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewHost.bounds
    }

    private func setupUI() {
        previewHost.backgroundColor = .black
        view.addSubview(previewHost)
        previewHost.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewHost.topAnchor.constraint(equalTo: view.topAnchor),
            previewHost.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        oledOverlay.backgroundColor = .black
        view.addSubview(oledOverlay)
        oledOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            oledOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            oledOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            oledOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            oledOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        oledOverlay.addSubview(recBadge)
        recBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            recBadge.topAnchor.constraint(equalTo: oledOverlay.safeAreaLayoutGuide.topAnchor, constant: 10),
            recBadge.trailingAnchor.constraint(equalTo: oledOverlay.trailingAnchor, constant: -12),
        ])
        recBadge.isHidden = true

        view.addSubview(utilityView)
        utilityView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            utilityView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            utilityView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            utilityView.topAnchor.constraint(equalTo: view.topAnchor),
            utilityView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        view.addSubview(controls)
        controls.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])

        controls.onToggleRecording = { [weak self] in self?.toggleRecording() }
        controls.onZoomChanged = { z in CameraEngine.shared.setZoom(z) }
        controls.onFpsChanged = { fps in CameraEngine.shared.setPreferredFps(fps) }
    }

    private func attachPreviewIfNeeded() {
        guard previewLayer == nil else { return }
        let layer = CameraEngine.shared.makePreviewLayer()
        layer.frame = previewHost.bounds
        previewHost.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    private func setupGestures() {
        let single = UITapGestureRecognizer(target: self, action: #selector(onSingleTap))
        single.numberOfTapsRequired = 1

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap))
        doubleTap.numberOfTapsRequired = 2

        let triple = UITapGestureRecognizer(target: self, action: #selector(onTripleTap))
        triple.numberOfTapsRequired = 3

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))

        single.require(toFail: doubleTap)
        single.require(toFail: triple)
        doubleTap.require(toFail: triple)

        view.addGestureRecognizer(single)
        view.addGestureRecognizer(doubleTap)
        view.addGestureRecognizer(triple)
        view.addGestureRecognizer(longPress)
    }

    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(onWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    private func applyMode() {
        switch mode {
        case .oled:
            previewHost.alpha = 0.0
            oledOverlay.isHidden = false
            utilityView.isHidden = true
            controls.isHidden = true
            recBadge.isHidden = !CameraEngine.shared.isRecording
        case .camera:
            previewHost.alpha = 1.0
            oledOverlay.isHidden = true
            utilityView.isHidden = true
            controls.isHidden = false
            // Update controls to reflect current recording state
            controls.setRecording(CameraEngine.shared.isRecording)
        case .utility:
            previewHost.alpha = 0.0
            oledOverlay.isHidden = true
            utilityView.isHidden = false
            controls.isHidden = true
        }
    }

    private func stopRecordingIfNeeded() {
        if CameraEngine.shared.isRecording {
            CameraEngine.shared.stopRecording()
            controls.setRecording(false)
        }
    }

    private func toggleRecording() {
        guard mode == .camera else { return }
        if CameraEngine.shared.isRecording {
            CameraEngine.shared.stopRecording()
            controls.setRecording(false)
        } else {
            CameraEngine.shared.startRecording { [weak self] ok, msg in
                print("[calxV2] rec start -> \(ok) \(msg ?? "nil")")
                self?.controls.setRecording(ok)
            }
        }
    }

    @objc private func onSingleTap() {
        switch mode {
        case .oled:
            // Single tap starts recording but keeps pitch black (OLED mode)
            toggleRecording()
        case .camera:
            toggleRecording()
        case .utility:
            break
        }
    }

    @objc private func onDoubleTap() {
        switch mode {
        case .oled:
            // Double tap shows preview
            mode = .camera
        case .camera:
            // Stop recording and return to OLED
            stopRecordingIfNeeded()
            mode = .oled
        case .utility:
            break
        }
    }

    @objc private func onTripleTap() {
        switch mode {
        case .oled, .camera:
            // Triple tap switches to utility while continuing recording
            mode = .utility
        case .utility:
            // Return to camera mode from utility
            mode = .camera
        }
    }

    @objc private func onLongPress(_ gr: UILongPressGestureRecognizer) {
        switch mode {
        case .oled:
            // Tap and hold to show preview (switch to camera mode)
            if gr.state == .began { mode = .camera }
        case .camera:
            // Tap and hold to switch back to OLED while continuing recording
            if gr.state == .began {
                stopRecordingIfNeeded()
                mode = .oled
            }
        case .utility:
            // In utility mode, long press returns to camera
            if gr.state == .began { mode = .camera }
        }
    }

    @objc private func onWillResignActive() { privacy.show() }
    @objc private func onDidBecomeActive() { privacy.hide(); CameraEngine.shared.startSession(); applyMode() }
    @objc private func onDidEnterBackground() { stopRecordingIfNeeded(); CameraEngine.shared.stopSession() }
}
