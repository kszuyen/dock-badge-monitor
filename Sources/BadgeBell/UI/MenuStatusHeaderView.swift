import AppKit

/// A fixed-size summary leaves the rest of the menu to native AppKit controls.
@MainActor
final class MenuStatusHeaderView: NSView {
    static let width: CGFloat = 316
    static let height: CGFloat = 84
    private let iconView = NSImageView()
    private let brand = NSTextField(labelWithString: "BadgeBell")
    private let summary = NSTextField(labelWithString: "U: Checking")
    private let detail = NSTextField(wrappingLabelWithString: "Starting monitoring…")

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))
        brand.font = .systemFont(ofSize: 13, weight: .semibold)
        summary.font = .systemFont(ofSize: 12)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 2
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.cyberlink.u")
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "bell", accessibilityDescription: nil)
        let text = NSStackView(views: [brand, summary, detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3
        for view in [iconView, text] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            text.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            text.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 10),
            text.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
            detail.widthAnchor.constraint(equalTo: text.widthAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        for view in [brand, summary, detail, iconView] { view.setAccessibilityElement(false) }
        update(title: "U: Checking", detail: "Starting monitoring…")
    }

    required init?(coder: NSCoder) { nil }

    func update(title: String, detail description: String) {
        if summary.stringValue != title { summary.stringValue = title }
        if detail.stringValue != description { detail.stringValue = description }
        let label = "BadgeBell. \(title). \(description)"
        if accessibilityLabel() != label { setAccessibilityLabel(label) }
    }
}
