//
//  PopoverPanel.swift
//  dria
//
//  The menu-bar dropdown as a flat, borderless panel instead of an NSPopover.
//  NSPopover always draws a callout arrow pointing at its anchor and there is no
//  API to turn it off; the platform convention for a menu-bar app is a plain
//  rounded rectangle hanging under the status item. Ported from Liddy's
//  MenuPanel (~/Code/liddy, MIT © bygelo).
//

import AppKit
import SwiftUI

/// Borderless panels refuse key status by default, which leaves every control in
/// the dropdown dead. Take the frame as given so AppKit does not shove a panel
/// hanging off the menu bar back up behind it.
final class PopoverPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

@MainActor
final class PopoverPanelController: NSObject {
    private let panel: PopoverPanelWindow
    private var dismissMonitor: Any?
    private var escapeMonitor: Any?
    /// When the panel last closed, so a click on the status item that dismissed it
    /// does not immediately reopen it.
    private var closedAt = Date.distantPast

    private static let cornerRadius: CGFloat = 11
    private static let screenInset: CGFloat = 8
    private let size = NSSize(width: 420, height: 560)

    var isShown: Bool { panel.isVisible }

    init(rootView: some View) {
        panel = PopoverPanelWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // The rounded, blurred background the popover used to provide for free.
        let backdrop = NSVisualEffectView()
        backdrop.material = .popover
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = Self.cornerRadius
        backdrop.layer?.cornerCurve = .continuous
        backdrop.layer?.masksToBounds = true
        backdrop.translatesAutoresizingMaskIntoConstraints = false

        let host = NSHostingView(rootView: rootView)
        host.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor),
            host.topAnchor.constraint(equalTo: backdrop.topAnchor),
            host.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor),
        ])

        panel.contentView = backdrop
        super.init()

        // Dismiss when another application takes the foreground. Watching our own
        // resign-key would also fire when a Picker inside the panel opens its menu.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(otherApplicationDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
    }

    @objc private func otherApplicationDidActivate(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard app?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        close()
    }

    // MARK: - Showing

    func toggle(relativeTo button: NSStatusBarButton?) {
        if panel.isVisible {
            close()
        } else if Date().timeIntervalSince(closedAt) > 0.2 {
            show(relativeTo: button)
        }
    }

    func show(relativeTo button: NSStatusBarButton?) {
        guard let topLeft = topLeft(for: button) else { return }
        panel.setFrame(
            NSRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height),
            display: true)
        // Deliberately not NSApp.activate: activating an accessory app over a
        // full-screen app makes macOS leave that space. A nonactivating panel that
        // can become key takes keyboard focus for its own controls without it.
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        // Activate the app so SwiftUI's SettingsLink (the gear) can open the
        // Settings scene — it only opens when this app is frontmost.
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { $0.duration = 0.09; panel.animator().alphaValue = 1 }
        installDismissMonitor(button: button)
    }

    func close() {
        guard panel.isVisible else { return }
        removeDismissMonitor()
        closedAt = Date()
        panel.orderOut(nil)
    }

    // MARK: - Placement

    /// The panel's top-left corner: centred under the status item, hanging from the
    /// bottom edge of the menu bar. Falls back to the top-right of the active screen
    /// when the icon is hidden by a menu-bar manager.
    private func topLeft(for button: NSStatusBarButton?) -> NSPoint? {
        if let anchor = anchorRect(for: button), let screen = screen(containing: anchor) {
            let ideal = anchor.midX - size.width / 2
            let lower = screen.frame.minX + Self.screenInset
            let upper = screen.frame.maxX - size.width - Self.screenInset
            let x = upper > lower ? min(max(ideal, lower), upper) : lower
            return NSPoint(x: x, y: screen.visibleFrame.maxY)
        }
        guard let screen = activeScreen() else { return nil }
        return NSPoint(
            x: screen.visibleFrame.maxX - size.width - Self.screenInset,
            y: screen.visibleFrame.maxY)
    }

    /// The status item's on-screen rect, or nil when it is not a real, visible slot
    /// in the menu bar (a menu-bar manager can hide it off-screen while it keeps
    /// reporting a frame).
    private func anchorRect(for button: NSStatusBarButton?) -> NSRect? {
        guard let button, let window = button.window else { return nil }
        let rect = window.convertToScreen(button.bounds)
        guard rect.width > 1, rect.height > 1 else { return nil }
        guard let screen = screen(containing: rect) else { return nil }
        guard rect.maxY > screen.frame.maxY - 40 else { return nil }
        return rect
    }

    private func screen(containing rect: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(rect) }
    }

    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    // MARK: - Dismissal

    private func installDismissMonitor(button: NSStatusBarButton?) {
        removeDismissMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.close()
            return nil
        }
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.panel.isVisible else { return }
                // A click on the status item is the button's job to toggle; closing
                // here too would double-fire.
                let mouse = NSEvent.mouseLocation
                if let anchor = self.anchorRect(for: button),
                   anchor.insetBy(dx: -2, dy: -2).contains(mouse) { return }
                self.close()
            }
        }
    }

    private func removeDismissMonitor() {
        if let dismissMonitor { NSEvent.removeMonitor(dismissMonitor) }
        dismissMonitor = nil
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }
}
