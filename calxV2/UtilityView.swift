import UIKit

final class UtilityView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.06, alpha: 1.0)

        let title = UILabel()
        title.text = "Utility"
        title.textColor = .white
        title.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        title.textAlignment = .center

        let hint = UILabel()
        hint.text = "Long press to return to camera"
        hint.textColor = UIColor(white: 1.0, alpha: 0.6)
        hint.font = UIFont.systemFont(ofSize: 12)
        hint.textAlignment = .center

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10
        grid.distribution = .fillEqually

        let labels = [
            ["Network", "Storage", "Sensors"],
            ["Logs", "Status", "Info"],
            ["Tools", "Metrics", "About"]
        ]

        for row in labels {
            let h = UIStackView()
            h.axis = .horizontal
            h.spacing = 10
            h.distribution = .fillEqually
            for name in row {
                let b = UIButton(type: .system)
                b.setTitle(name, for: .normal)
                b.setTitleColor(.white, for: .normal)
                b.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                b.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
                b.layer.cornerRadius = 14
                h.addArrangedSubview(b)
            }
            grid.addArrangedSubview(h)
        }

        let v = UIStackView(arrangedSubviews: [title, grid, hint])
        v.axis = .vertical
        v.spacing = 16

        addSubview(v)
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            v.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            v.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            v.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            grid.heightAnchor.constraint(equalToConstant: 220),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
