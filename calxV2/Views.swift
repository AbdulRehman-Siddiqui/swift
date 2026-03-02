import UIKit

final class RecBadgeView: UIView {
    private let dot = UIView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemRed.cgColor
        layer.cornerRadius = 12

        dot.backgroundColor = .systemRed
        dot.layer.cornerRadius = 4

        label.text = "REC"
        label.textColor = .systemRed
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)

        let h = UIStackView(arrangedSubviews: [dot, label])
        h.axis = .horizontal
        h.spacing = 6
        h.alignment = .center

        addSubview(h)
        h.translatesAutoresizingMaskIntoConstraints = false
        dot.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            h.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            h.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            h.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            h.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class ControlsView: UIView {
    var onToggleRecording: (() -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?
    var onFpsChanged: ((Int32) -> Void)?

    private let recButton = UIButton(type: .system)
    private let zoomSlider = UISlider()
    private let fpsControl = UISegmentedControl(items: ["24", "30", "60"])

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.55)
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        let fpsLabel = UILabel()
        fpsLabel.text = "FPS:"
        fpsLabel.textColor = .white
        fpsLabel.font = UIFont.systemFont(ofSize: 14)

        fpsControl.selectedSegmentIndex = 1
        fpsControl.addTarget(self, action: #selector(onFps), for: .valueChanged)

        recButton.setTitle("REC", for: .normal)
        recButton.tintColor = .systemRed
        recButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        recButton.addTarget(self, action: #selector(onRec), for: .touchUpInside)

        zoomSlider.minimumValue = 1.0
        zoomSlider.maximumValue = 15.0
        zoomSlider.value = 1.0
        zoomSlider.addTarget(self, action: #selector(onZoom), for: .valueChanged)

        let zoomLabel = UILabel()
        zoomLabel.text = "Zoom"
        zoomLabel.textColor = .white
        zoomLabel.font = UIFont.systemFont(ofSize: 14)

        let top = UIStackView(arrangedSubviews: [fpsLabel, fpsControl, UIView(), recButton])
        top.axis = .horizontal
        top.spacing = 8
        top.alignment = .center

        let bottom = UIStackView(arrangedSubviews: [zoomLabel, zoomSlider])
        bottom.axis = .horizontal
        bottom.spacing = 10
        bottom.alignment = .center

        let v = UIStackView(arrangedSubviews: [top, bottom])
        v.axis = .vertical
        v.spacing = 10

        addSubview(v)
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            v.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            v.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            v.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setRecording(_ rec: Bool) {
        if rec {
            recButton.setTitle("STOP", for: .normal)
            recButton.tintColor = .white
            recButton.backgroundColor = .systemRed
            recButton.layer.cornerRadius = 10
            recButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        } else {
            recButton.setTitle("REC", for: .normal)
            recButton.tintColor = .systemRed
            recButton.backgroundColor = .clear
            recButton.contentEdgeInsets = .zero
        }
    }

    @objc private func onRec() { onToggleRecording?() }
    @objc private func onZoom() { onZoomChanged?(CGFloat(zoomSlider.value)) }

    @objc private func onFps() {
        let fps: Int32 = (fpsControl.selectedSegmentIndex == 0) ? 24 : (fpsControl.selectedSegmentIndex == 2 ? 60 : 30)
        onFpsChanged?(fps)
    }
}

final class PrivacyOverlay {
    static let shared = PrivacyOverlay()
    private var overlayWindow: UIWindow?
    private init() {}

    func show() {
        DispatchQueue.main.async {
            guard self.overlayWindow == nil else { return }
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            let w = UIWindow(windowScene: scene)
            w.windowLevel = .alert + 1
            w.backgroundColor = .black
            w.isHidden = false
            self.overlayWindow = w
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
        }
    }
}
