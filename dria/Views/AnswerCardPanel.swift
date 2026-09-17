//
//  AnswerCardPanel.swift
//  dria
//
//  The window plumbing (key-capable borderless panel, un-constrained frame,
//  same-pass content-height resize, re-entrancy guard, dismiss monitors) is
//  ported from Liddy's MenuPanel (~/Code/liddy, MIT © bygelo), which already
//  solved these on macOS.
//

import AppKit
import SwiftUI

struct AnswerCardContent {
    enum Phase { case loading, answer, error }

    var phase: Phase
    var typeLabel: String
    var stem: String
    var shortAnswer: String = ""
    var explanation: String = ""
    var source: [String] = []
    var passage: String = ""
}

/// Observable model the SwiftUI card reads from.
@Observable
@MainActor
final class AnswerCardModel {
    var content = AnswerCardContent(phase: .loading, typeLabel: "", stem: "")
    var isRevealed = false
    var isPinned = false
}

/// An `NSHostingView` that reports when it has finished a layout pass.
///
/// Liddy's jitter fix: resizing the window from `objectWillChange` measures the
/// *old* height (it fires before the value changes), leaving one frame where the
/// content is drawn at the new size inside a window still at the old size — the
/// jump you see when the card fills in. Laying out is the only moment the new
/// height is knowable, so the window follows from here in the same pass.
/// Concrete (non-generic) on purpose: a generic `NSHostingView` subclass makes
/// the Swift optimizer crash on its implicit deinit under Release `-O`
/// (EarlyPerfInliner). We only ever host `AnyView`, so this costs nothing.
final class MeasuringHostingView: NSHostingView<AnyView> {
    var onLayout: (() -> Void)?

    required init(rootView: AnyView) { super.init(rootView: rootView) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        onLayout?()
    }
}

/// Borderless panels refuse key status by default, which leaves every button in
/// the card dead; and AppKit relocates a window that runs off-screen, which for a
/// cursor-anchored card near an edge means it jumps. Both are overridden.
final class CursorCardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

@MainActor
final class AnswerCardController {
    private let appState: AppState
    private let model = AnswerCardModel()
    private var panel: CursorCardPanel?
    private var hosting: MeasuringHostingView?
    private var followTimer: Timer?
    private var dismissTimer: Timer?
    private var clickMonitor: Any?
    private var escapeMonitor: Any?
    /// Guards against setFrame → layout() → setFrame recursion (Liddy).
    private var isResizing = false
    /// True once the user clicked to pin — the card is being read, so it never auto-dismisses.
    private var isHeldByUser = false

    private let cursorOffset = NSPoint(x: 18, y: 18)
    private let minHeight: CGFloat = 80
    private let maxHeight: CGFloat = 460

    /// Overlay opacity, floored at 0.05 so the card can never become fully invisible.
    private var cardAlpha: CGFloat {
        let v = appState.answerCardOpacity
        return v.isFinite ? CGFloat(min(max(v, 0.05), 1.0)) : 1.0
    }

    init(appState: AppState) {
        self.appState = appState
    }

    func show(_ content: AnswerCardContent) {
        // Closed (or dismissed) before the answer landed — stay closed.
        if panel == nil && content.phase != .loading { return }
        let isNewQuestion = content.phase == .loading
        model.content = content
        if isNewQuestion {
            model.isRevealed = !appState.answerCardRevealFirst
            model.isPinned = !appState.answerCardFollowCursor
            isHeldByUser = false
        }

        let panel = self.panel ?? makePanel()
        self.panel = panel
        followContentHeight()
        if isNewQuestion { moveToCursor(panel) }
        // Window-level opacity: dims the whole overlay (background, text, shadow)
        // as one, unlike a SwiftUI .opacity() that show() would otherwise override.
        let alpha = cardAlpha
        panel.alphaValue = isNewQuestion ? 0 : alpha
        panel.orderFrontRegardless()
        if isNewQuestion {
            NSAnimationContext.runAnimationGroup { $0.duration = 0.09; panel.animator().alphaValue = alpha }
        }

        installDismissMonitor()
        if appState.answerCardFollowCursor && !model.isPinned { startFollowing() }
        scheduleDismiss(for: content.phase)
    }

    /// Apply opacity/width to an already-open card, live from the settings sliders.
    func applyLiveStyle() {
        guard let panel else { return }
        panel.alphaValue = cardAlpha
        followContentHeight() // picks up the new width
        if followTimer != nil { moveToCursor(panel) }
    }

    func hide() {
        stopFollowing()
        removeDismissMonitor()
        dismissTimer?.invalidate()
        dismissTimer = nil
        panel?.orderOut(nil)
        panel = nil
        hosting = nil
    }

    // MARK: - Panel

    private func makePanel() -> CursorCardPanel {
        let panel = CursorCardPanel(
            contentRect: NSRect(x: 0, y: 0, width: appState.answerCardWidth, height: 160),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        // Follow the user across spaces and sit above a full-screen app.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let view = AnyView(
            AnswerCardView(
                model: model,
                onClose: { [weak self] in self?.hide() },
                onPin: { [weak self] in self?.pin() },
                onReveal: { [weak self] in self?.reveal() }
            )
            .environment(appState)
        )

        let host = MeasuringHostingView(rootView: view)
        // Height driven by the SwiftUI content alone — the only measurement that
        // cannot feed back into the frame that produced it.
        host.sizingOptions = [.intrinsicContentSize]
        host.onLayout = { [weak self] in self?.followContentHeight() }
        panel.contentView = host
        self.hosting = host
        return panel
    }

    /// Match the window height to the content just laid out, keeping the top edge
    /// anchored so growth pushes the bottom down rather than moving the card.
    private func followContentHeight() {
        guard let panel, let hosting, !isResizing else { return }
        isResizing = true
        defer { isResizing = false }

        hosting.layoutSubtreeIfNeeded()
        let measured = hosting.intrinsicContentSize.height > 0
            ? hosting.intrinsicContentSize.height
            : hosting.fittingSize.height
        guard measured > 0 else { return }

        let width = appState.answerCardWidth
        let height = min(max(measured, minHeight), maxHeight)
        var frame = panel.frame
        guard frame.size != NSSize(width: width, height: height) else { return }
        frame.origin.y += frame.height - height // keep top edge anchored
        frame.size = NSSize(width: width, height: height)

        // Set, never animate — window and content change in the same pass (Liddy).
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrame(frame, display: true)
        CATransaction.commit()
    }

    /// Place the card below-right of the cursor, flipped to stay on screen.
    private func moveToCursor(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let size = panel.frame.size
        guard let visible = activeScreen()?.visibleFrame else { return }

        var x = mouse.x + cursorOffset.x
        var y = mouse.y - cursorOffset.y - size.height
        if x + size.width > visible.maxX { x = mouse.x - cursorOffset.x - size.width }
        if y < visible.minY { y = mouse.y + cursorOffset.y }
        x = min(max(x, visible.minX), visible.maxX - size.width)
        y = min(max(y, visible.minY), visible.maxY - size.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// The screen under the pointer, else main. Optional: a Mac can have no screen.
    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    // MARK: - Follow cursor

    /// The card tracks the cursor until the first click anywhere, which pins it in
    /// place so its buttons can be used.
    private func startFollowing() {
        guard followTimer == nil else { return }
        followTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel else { return }
                self.moveToCursor(panel)
            }
        }
    }

    private func stopFollowing() {
        followTimer?.invalidate()
        followTimer = nil
    }

    private func pin() {
        model.isPinned = true
        isHeldByUser = true
        stopFollowing()
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    private func reveal() {
        model.isRevealed = true
        // Layout follows from MeasuringHostingView.onLayout; no manual resize needed.
    }

    private func scheduleDismiss(for phase: AnswerCardContent.Phase) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        let seconds = appState.answerCardDismissSeconds
        guard phase != .loading, seconds > 0, !isHeldByUser else { return }
        dismissTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    // MARK: - Dismissal

    /// A borderless panel gets no transient behaviour for free. Escape closes it
    /// (local — the panel holds key); a click outside pins it if it was following.
    private func installDismissMonitor() {
        removeDismissMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.hide()
            return nil
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.followTimer != nil { self.pin() }
            }
        }
    }

    private func removeDismissMonitor() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }
}

// MARK: - View

private struct AnswerCardView: View {
    @Environment(AppState.self) private var appState
    let model: AnswerCardModel
    let onClose: () -> Void
    let onPin: () -> Void
    let onReveal: () -> Void

    private var colorScheme: ColorScheme? {
        switch appState.answerCardTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        let content = model.content
        VStack(alignment: .leading, spacing: 8) {
            header(content)

            if !content.stem.isEmpty {
                Text(content.stem)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            switch content.phase {
            case .loading:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Answering…").font(.callout).foregroundStyle(.secondary)
                }
            case .error:
                Text(content.shortAnswer)
                    .font(.callout)
                    .foregroundStyle(.red)
            case .answer:
                if model.isRevealed {
                    answerBody(content)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pick your answer first, then reveal.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Reveal answer", action: onReveal)
                            .controlSize(.small)
                        if !model.isPinned {
                            Text("Click anywhere to pin the card.")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: appState.answerCardWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
        )
        .preferredColorScheme(colorScheme)
        .onChange(of: appState.answerCardEnabled) { _, isEnabled in
            if !isEnabled { onClose() }
        }
    }

    private func header(_ content: AnswerCardContent) -> some View {
        HStack(spacing: 6) {
            Label("dria", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
            Text(content.typeLabel)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Color.accentColor.opacity(0.18))
                .clipShape(Capsule())
            Spacer()
            if !model.isPinned {
                Button(action: onPin) { Image(systemName: "pin") }
                    .buttonStyle(.borderless)
                    .help("Stop following the cursor")
            }
            Button(action: onClose) { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .help("Close")
        }
    }

    @ViewBuilder
    private func answerBody(_ content: AnswerCardContent) -> some View {
        Text(content.shortAnswer)
            .font(.body.weight(.semibold))
            .textSelection(.enabled)

        if appState.answerCardShowExplanation, !content.explanation.isEmpty {
            ScrollView {
                Text(content.explanation)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 180)
        }

        if !content.source.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Label(content.source.joined(separator: ", "), systemImage: "doc.text")
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                if !content.passage.isEmpty {
                    Text("“\(content.passage)”")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }
}
