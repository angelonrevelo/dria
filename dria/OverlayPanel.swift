//
//  OverlayPanel.swift
//  dria
//
//  Floating edge-sliver panel. Pin uses .floating so the overlay can sit
//  over a normal browser / fullscreen space. Collection: canJoinAllSpaces +
//  fullScreenAuxiliary (unlockdown docs/ARCHITECTURE.md — CGS window list).
//

import AppKit

final class OverlayPanel: NSPanel, NSTextFieldDelegate {
    weak var appState: AppState?
    var onAskSubmitted: ((String) -> Void)?
    var onAskResigned: (() -> Void)?
    var onCopyBanner: (() -> Void)?

    private let hud = NSVisualEffectView()
    private let titleLabel = NSTextField(labelWithString: "dria")
    private let gearButton = NSButton()
    private let clipBanner = NSTextField(labelWithString: "")
    private let askField = NSTextField()
    private let settingCard = NSView()
    private let pinButton = NSButton(checkboxWithTitle: "Pin on top", target: nil, action: nil)
    private let clickButton = NSButton(checkboxWithTitle: "Click-through", target: nil, action: nil)
    private let flashLabel = NSTextField(labelWithString: "")
    private var flashHideWork: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?
    private var isSettingOpen = false

    private enum Metric {
        static let panelWidth: CGFloat = 320
        static let panelHeight: CGFloat = 168
        static let edgeInset: CGFloat = 320
        static let cornerRadius: CGFloat = 10
        static let flashSecond: TimeInterval = 2.4
        static let clickThroughAlpha: CGFloat = 0.55
        static let pinAlpha: CGFloat = 0.98
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(appState: AppState) {
        self.appState = appState
        let frame = OverlayPanel.edgeSliverFrame()
        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        hasShadow = true

        applyPin(appState.isPinned)
        applyClickThrough(appState.isClickThrough)
        buildContent()
        setFrame(frame, display: true)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.placeAtEdgeSliver()
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    // MARK: - Pin / click-through (NotesView applyPin / applyClickThrough)

    func applyPin(_ isPinned: Bool) {
        if isPinned {
            level = .floating
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        } else {
            level = .normal
            collectionBehavior = [.managed, .fullScreenNone]
        }
        pinButton.state = isPinned ? .on : .off
    }

    func applyClickThrough(_ isClickThrough: Bool) {
        ignoresMouseEvents = isClickThrough
        hasShadow = !isClickThrough
        alphaValue = isClickThrough ? Metric.clickThroughAlpha : Metric.pinAlpha
        clickButton.state = isClickThrough ? .on : .off
    }

    func applyOverlaySetting() {
        guard let appState else { return }
        applyPin(appState.isPinned)
        applyClickThrough(appState.isClickThrough)
    }

    // MARK: - Gear flashSetting

    func flashSetting(_ text: String? = nil) {
        if let text, !text.isEmpty {
            flashLabel.stringValue = text
            flashLabel.isHidden = false
        } else {
            flashLabel.stringValue = ""
            flashLabel.isHidden = true
        }
        openSetting()
        flashHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.closeSetting()
        }
        flashHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Metric.flashSecond, execute: work)
    }

    @objc func toggleSetting() {
        if isSettingOpen {
            closeSetting()
        } else {
            flashSetting()
        }
    }

    private func openSetting() {
        isSettingOpen = true
        settingCard.isHidden = false
        settingCard.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            settingCard.animator().alphaValue = 1
        }
        refreshSetting()
    }

    func closeSetting() {
        flashHideWork?.cancel()
        flashHideWork = nil
        isSettingOpen = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            settingCard.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.settingCard.isHidden = true
            self?.flashLabel.isHidden = true
        })
    }

    func refreshSetting() {
        guard let appState else { return }
        pinButton.state = appState.isPinned ? .on : .off
        clickButton.state = appState.isClickThrough ? .on : .off
    }

    // MARK: - Clipboard short-answer banner (buildClipBanner)

    func showClipBanner(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isStatus = trimmed.hasPrefix("📸") || trimmed.hasPrefix("⚠️")
            || trimmed.hasPrefix("🔄") || trimmed.hasPrefix("📚")
            || trimmed.hasPrefix("📋") || trimmed.hasPrefix("✅")
            || trimmed.hasPrefix("✋")
        guard !trimmed.isEmpty, !isStatus else { return }
        clipBanner.stringValue = trimmed
        clipBanner.toolTip = "Click to copy"
        clipBanner.textColor = .labelColor
    }

    func clearClipBanner() {
        clipBanner.stringValue = "Copy a question — short answer shows here"
        clipBanner.textColor = .secondaryLabelColor
    }

    // MARK: - Inline ask (⌘⌥3) — keep field, do not drop

    var isAskFocused: Bool {
        firstResponder === askField || firstResponder === askField.currentEditor()
    }

    func toggleAskField() {
        if isAskFocused {
            resignAsk()
        } else {
            focusAsk()
        }
    }

    func focusAsk() {
        refreshAskPlaceholder()
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(askField)
    }

    func resignAsk() {
        askField.stringValue = ""
        resignFirstResponder()
        makeFirstResponder(nil)
        orderFrontRegardless()
        onAskResigned?()
    }

    func refreshAskPlaceholder() {
        let hasImage = appState?.capturedImage != nil
        let modeName = appState?.activeMode.name ?? "dria"
        askField.placeholderString = hasImage
            ? "📸 Screenshot ready — type a question, Enter to send"
            : "Ask dria (\(modeName))... Enter=send Esc=close"
    }

    // MARK: - Edge sliver

    func placeAtEdgeSliver() {
        setFrame(OverlayPanel.edgeSliverFrame(), display: true)
    }

    static func edgeSliverFrame() -> NSRect {
        let screen = NSScreen.screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let originX = screen.maxX - Metric.edgeInset
        let originY = screen.maxY - Metric.panelHeight
        return NSRect(x: originX, y: originY, width: Metric.panelWidth, height: Metric.panelHeight)
    }

    // MARK: - Build

    private func buildContent() {
        hud.material = .hudWindow
        hud.blendingMode = .behindWindow
        hud.state = .active
        hud.wantsLayer = true
        hud.layer?.cornerRadius = Metric.cornerRadius
        hud.layer?.masksToBounds = true
        hud.translatesAutoresizingMaskIntoConstraints = false

        contentView = hud

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        gearButton.bezelStyle = .inline
        gearButton.isBordered = false
        gearButton.imagePosition = .imageOnly
        gearButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        gearButton.toolTip = "Overlay settings"
        gearButton.target = self
        gearButton.action = #selector(toggleSetting)
        gearButton.translatesAutoresizingMaskIntoConstraints = false

        clipBanner.font = .systemFont(ofSize: 12, weight: .medium)
        clipBanner.textColor = .secondaryLabelColor
        clipBanner.stringValue = "Copy a question — short answer shows here"
        clipBanner.lineBreakMode = .byTruncatingTail
        clipBanner.maximumNumberOfLines = 2
        clipBanner.translatesAutoresizingMaskIntoConstraints = false
        let bannerClick = NSClickGestureRecognizer(target: self, action: #selector(bannerClicked))
        clipBanner.addGestureRecognizer(bannerClick)

        askField.font = .systemFont(ofSize: 13)
        askField.isBezeled = true
        askField.bezelStyle = .roundedBezel
        askField.focusRingType = .none
        askField.delegate = self
        askField.target = self
        askField.action = #selector(askSubmitted)
        askField.translatesAutoresizingMaskIntoConstraints = false
        refreshAskPlaceholder()

        buildSettingCard()

        hud.addSubview(titleLabel)
        hud.addSubview(gearButton)
        hud.addSubview(clipBanner)
        hud.addSubview(askField)
        hud.addSubview(settingCard)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: hud.topAnchor, constant: 10),

            gearButton.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -8),
            gearButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            gearButton.widthAnchor.constraint(equalToConstant: 28),
            gearButton.heightAnchor.constraint(equalToConstant: 22),

            clipBanner.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 12),
            clipBanner.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -12),
            clipBanner.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),

            askField.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 10),
            askField.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -10),
            askField.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -10),
            askField.heightAnchor.constraint(equalToConstant: 24),

            settingCard.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 8),
            settingCard.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -8),
            settingCard.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            settingCard.bottomAnchor.constraint(equalTo: askField.topAnchor, constant: -6),
        ])
    }

    private func buildSettingCard() {
        settingCard.wantsLayer = true
        settingCard.layer?.cornerRadius = 8
        settingCard.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        settingCard.translatesAutoresizingMaskIntoConstraints = false
        settingCard.isHidden = true

        pinButton.target = self
        pinButton.action = #selector(pinToggled)
        pinButton.font = .systemFont(ofSize: 12)
        pinButton.translatesAutoresizingMaskIntoConstraints = false

        clickButton.target = self
        clickButton.action = #selector(clickToggled)
        clickButton.font = .systemFont(ofSize: 12)
        clickButton.translatesAutoresizingMaskIntoConstraints = false

        flashLabel.font = .systemFont(ofSize: 11, weight: .medium)
        flashLabel.textColor = .secondaryLabelColor
        flashLabel.translatesAutoresizingMaskIntoConstraints = false
        flashLabel.isHidden = true

        settingCard.addSubview(pinButton)
        settingCard.addSubview(clickButton)
        settingCard.addSubview(flashLabel)

        NSLayoutConstraint.activate([
            pinButton.leadingAnchor.constraint(equalTo: settingCard.leadingAnchor, constant: 10),
            pinButton.topAnchor.constraint(equalTo: settingCard.topAnchor, constant: 8),

            clickButton.leadingAnchor.constraint(equalTo: settingCard.leadingAnchor, constant: 10),
            clickButton.topAnchor.constraint(equalTo: pinButton.bottomAnchor, constant: 4),

            flashLabel.leadingAnchor.constraint(equalTo: settingCard.leadingAnchor, constant: 10),
            flashLabel.trailingAnchor.constraint(equalTo: settingCard.trailingAnchor, constant: -10),
            flashLabel.bottomAnchor.constraint(equalTo: settingCard.bottomAnchor, constant: -6),
        ])
    }

    // MARK: - Actions

    @objc private func pinToggled() {
        let isPinned = pinButton.state == .on
        appState?.isPinned = isPinned
        applyPin(isPinned)
        flashSetting(isPinned ? "Pin on" : "Pin off")
    }

    @objc private func clickToggled() {
        let isClickThrough = clickButton.state == .on
        appState?.isClickThrough = isClickThrough
        applyClickThrough(isClickThrough)
        flashSetting(isClickThrough ? "Click-through on" : "Click-through off")
    }

    @objc private func askSubmitted() {
        let text = askField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            resignAsk()
            return
        }
        askField.stringValue = ""
        resignAsk()
        onAskSubmitted?(text)
    }

    @objc private func bannerClicked() {
        onCopyBanner?()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            resignAsk()
            return true
        }
        return false
    }
}
