//
//  HotkeyService.swift
//  dria
//

import AppKit
import Carbon

// MARK: - Hotkey Binding Model

struct HotkeyBinding: Codable, Equatable, Hashable {
    let keyCode: UInt32
    let label: String  // Human-readable key name
    let modifier: UInt32

    static let commandOptionModifier = UInt32(cmdKey | optionKey)
    static let optionShiftModifier = UInt32(optionKey | shiftKey)

    init(keyCode: UInt32, label: String, modifier: UInt32 = commandOptionModifier) {
        self.keyCode = keyCode
        self.label = label
        self.modifier = modifier
    }

    enum CodingKeys: String, CodingKey {
        case keyCode, label, modifier
    }

    // Pre-AN4 saves omitted `modifier`. Keep ⌘⌥ so capture/send/chat don't reset.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.keyCode = try c.decode(UInt32.self, forKey: .keyCode)
        self.label = try c.decode(String.self, forKey: .label)
        self.modifier = try c.decodeIfPresent(UInt32.self, forKey: .modifier) ?? Self.commandOptionModifier
    }

    static let key1 = HotkeyBinding(keyCode: UInt32(kVK_ANSI_1), label: "1")
    static let key2 = HotkeyBinding(keyCode: UInt32(kVK_ANSI_2), label: "2")
    static let key3 = HotkeyBinding(keyCode: UInt32(kVK_ANSI_3), label: "3")
    static let key4 = HotkeyBinding(keyCode: UInt32(kVK_ANSI_4), label: "4")
    static let key5 = HotkeyBinding(keyCode: UInt32(kVK_ANSI_5), label: "5")
    static let key6 = HotkeyBinding(keyCode: UInt32(kVK_ANSI_6), label: "6")
    static let key7 = HotkeyBinding(keyCode: UInt32(kVK_ANSI_7), label: "7")
    static let key8 = HotkeyBinding(keyCode: UInt32(kVK_ANSI_8), label: "8")
    static let key9 = HotkeyBinding(keyCode: UInt32(kVK_ANSI_9), label: "9")
    static let key0 = HotkeyBinding(keyCode: UInt32(kVK_ANSI_0), label: "0")
    static let space = HotkeyBinding(keyCode: UInt32(kVK_Space), label: "Space")
    static let keyQ = HotkeyBinding(keyCode: UInt32(kVK_ANSI_Q), label: "Q")
    static let keyW = HotkeyBinding(keyCode: UInt32(kVK_ANSI_W), label: "W")
    static let keyE = HotkeyBinding(keyCode: UInt32(kVK_ANSI_E), label: "E")
    static let keyR = HotkeyBinding(keyCode: UInt32(kVK_ANSI_R), label: "R")
    static let keyS = HotkeyBinding(keyCode: UInt32(kVK_ANSI_S), label: "S")
    static let keyD = HotkeyBinding(keyCode: UInt32(kVK_ANSI_D), label: "D")
    static let keyN = HotkeyBinding(keyCode: UInt32(kVK_ANSI_N), label: "N")
    static let keyC = HotkeyBinding(keyCode: UInt32(kVK_ANSI_C), label: "C")
    static let keyO = HotkeyBinding(keyCode: UInt32(kVK_ANSI_O), label: "O")
    static let keyT = HotkeyBinding(keyCode: UInt32(kVK_ANSI_T), label: "T")
    static let keyH = HotkeyBinding(keyCode: UInt32(kVK_ANSI_H), label: "H")
    static let keyP = HotkeyBinding(keyCode: UInt32(kVK_ANSI_P), label: "P")

    static let leftArrow = HotkeyBinding(keyCode: UInt32(kVK_LeftArrow), label: "←")
    static let rightArrow = HotkeyBinding(keyCode: UInt32(kVK_RightArrow), label: "→")

    // Keys clustered by the right ⌥ key — reachable one-handed. Labels show the
    // shifted glyph since the toggle defaults use ⌥⇧.
    static let keyComma = HotkeyBinding(keyCode: UInt32(kVK_ANSI_Comma), label: "<")
    static let keyPeriod = HotkeyBinding(keyCode: UInt32(kVK_ANSI_Period), label: ">")
    static let keySlash = HotkeyBinding(keyCode: UInt32(kVK_ANSI_Slash), label: "?")

    /// NotesView NVHideMod: option+shift+N. Not keys 1–9 — LDB CGS
    /// `hotkey1_enabled`…`hotkey9_enabled` / `hotkeys_blocked`
    /// (`~/Warp/unlockdown/docs/ARCHITECTURE.md`, `docs/DETECTIONS.md`).
    // Defaults clustered by the right ⌥ key: ⌥⇧< marquee, ⌥⇧> card, ⌥⇧? copy.
    static let hideOverlayDefault = HotkeyBinding(
        keyCode: UInt32(kVK_ANSI_Comma),
        label: "<",
        modifier: optionShiftModifier
    )
    static let copyAnswerDefault = HotkeyBinding(
        keyCode: UInt32(kVK_ANSI_Slash),
        label: "?",
        modifier: optionShiftModifier
    )
    static let toggleOverlayDefault = HotkeyBinding(
        keyCode: UInt32(kVK_ANSI_Period),
        label: ">",
        modifier: optionShiftModifier
    )

    static let keyChoice: [HotkeyBinding] = [
        .key0, .key1, .key2, .key3, .key4, .key5, .key6, .key7, .key8, .key9,
        .space, .leftArrow, .rightArrow,
        .keyQ, .keyW, .keyE, .keyR, .keyS, .keyD,
        .keyN, .keyC, .keyO, .keyT, .keyH, .keyP,
        .keyComma, .keyPeriod, .keySlash,
    ]

    static let allOptions: [HotkeyBinding] = keyChoice

    struct ModifierChoice: Hashable {
        let flag: UInt32
        let label: String
    }

    static let modifierChoice: [ModifierChoice] = [
        ModifierChoice(flag: commandOptionModifier, label: "⌘⌥"),
        ModifierChoice(flag: optionShiftModifier, label: "⌥⇧"),
        ModifierChoice(flag: UInt32(cmdKey | shiftKey), label: "⌘⇧"),
        ModifierChoice(flag: UInt32(controlKey | optionKey), label: "⌃⌥"),
        ModifierChoice(flag: UInt32(cmdKey | optionKey | shiftKey), label: "⌘⌥⇧"),
    ]

    var modifierLabel: String {
        var s = ""
        if modifier & UInt32(controlKey) != 0 { s += "⌃" }
        if modifier & UInt32(optionKey) != 0 { s += "⌥" }
        if modifier & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifier & UInt32(cmdKey) != 0 { s += "⌘" }
        return s
    }

    var displayName: String { "\(modifierLabel)\(label)" }

    func with(keyCode: UInt32, label: String) -> HotkeyBinding {
        HotkeyBinding(keyCode: keyCode, label: label, modifier: modifier)
    }

    func with(modifier: UInt32) -> HotkeyBinding {
        HotkeyBinding(keyCode: keyCode, label: label, modifier: modifier)
    }
}

struct HotkeyConfig: Codable {
    var capture: HotkeyBinding     // Default: ⌘⌥1
    var sendToAI: HotkeyBinding    // Default: ⌘⌥2
    var inlineChat: HotkeyBinding  // Default: ⌘⌥3
    var cycleMode: HotkeyBinding   // Default: ⌘⌥0
    var abort: HotkeyBinding       // Default: ⌘⌥←
    var hoverCapture: HotkeyBinding // Default: ⌘⌥4 — capture around cursor + send
    var askExcelCell: HotkeyBinding // Default: ⌘⌥E — read Excel selection, write answer below
    var hideOverlay: HotkeyBinding  // Default: ⌥⇧N — NotesView hide
    var copyAnswer: HotkeyBinding   // Default: ⌥⇧C — copy via AppState.copyMode
    var toggleOverlay: HotkeyBinding // Default: ⌥⇧O

    static let defaults = HotkeyConfig(
        capture: .key1,
        sendToAI: .key2,
        inlineChat: .key3,
        cycleMode: .key0,
        abort: .leftArrow,
        hoverCapture: .key4,
        askExcelCell: .keyE,
        hideOverlay: .hideOverlayDefault,
        copyAnswer: .copyAnswerDefault,
        toggleOverlay: .toggleOverlayDefault
    )

    enum CodingKeys: String, CodingKey {
        case capture, sendToAI, inlineChat, cycleMode, abort, hoverCapture, askExcelCell
        case hideOverlay, copyAnswer, toggleOverlay
    }

    init(capture: HotkeyBinding, sendToAI: HotkeyBinding, inlineChat: HotkeyBinding,
         cycleMode: HotkeyBinding, abort: HotkeyBinding, hoverCapture: HotkeyBinding,
         askExcelCell: HotkeyBinding, hideOverlay: HotkeyBinding, copyAnswer: HotkeyBinding,
         toggleOverlay: HotkeyBinding) {
        self.capture = capture
        self.sendToAI = sendToAI
        self.inlineChat = inlineChat
        self.cycleMode = cycleMode
        self.abort = abort
        self.hoverCapture = hoverCapture
        self.askExcelCell = askExcelCell
        self.hideOverlay = hideOverlay
        self.copyAnswer = copyAnswer
        self.toggleOverlay = toggleOverlay
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.capture       = try c.decodeIfPresent(HotkeyBinding.self, forKey: .capture)       ?? Self.defaults.capture
        self.sendToAI      = try c.decodeIfPresent(HotkeyBinding.self, forKey: .sendToAI)      ?? Self.defaults.sendToAI
        self.inlineChat    = try c.decodeIfPresent(HotkeyBinding.self, forKey: .inlineChat)    ?? Self.defaults.inlineChat
        self.cycleMode     = try c.decodeIfPresent(HotkeyBinding.self, forKey: .cycleMode)     ?? Self.defaults.cycleMode
        self.abort         = try c.decodeIfPresent(HotkeyBinding.self, forKey: .abort)         ?? Self.defaults.abort
        self.hoverCapture  = try c.decodeIfPresent(HotkeyBinding.self, forKey: .hoverCapture)  ?? Self.defaults.hoverCapture
        self.askExcelCell  = try c.decodeIfPresent(HotkeyBinding.self, forKey: .askExcelCell)  ?? Self.defaults.askExcelCell
        self.hideOverlay   = try c.decodeIfPresent(HotkeyBinding.self, forKey: .hideOverlay)   ?? Self.defaults.hideOverlay
        self.copyAnswer    = try c.decodeIfPresent(HotkeyBinding.self, forKey: .copyAnswer)    ?? Self.defaults.copyAnswer
        self.toggleOverlay = try c.decodeIfPresent(HotkeyBinding.self, forKey: .toggleOverlay) ?? Self.defaults.toggleOverlay
    }

    static func load() -> HotkeyConfig {
        guard let data = UserDefaults.standard.data(forKey: "hotkeyConfig"),
              let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) else {
            return .defaults
        }
        return config
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "hotkeyConfig")
        }
    }
}

extension Notification.Name {
    static let hideOverlay = Notification.Name("dria.hideOverlay")
    static let copyAnswer = Notification.Name("dria.copyAnswer")
    static let toggleOverlay = Notification.Name("dria.toggleOverlay")
}

// MARK: - Hotkey Service

private var hotkeyServiceInstance: HotkeyService?

private func hotkeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let err = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard err == noErr else { return OSStatus(eventNotHandledErr) }

    Task { @MainActor in
        switch hotKeyID.id {
        case 1: hotkeyServiceInstance?.onScreenshot?()
        case 2: hotkeyServiceInstance?.onSendToAI?()
        case 3: hotkeyServiceInstance?.onOpenPopover?()
        case 4: hotkeyServiceInstance?.onToggleMode?()
        case 5: hotkeyServiceInstance?.onAbort?()
        case 6: hotkeyServiceInstance?.onHoverCapture?()
        case 7: hotkeyServiceInstance?.onAskExcelCell?()
        case 8:
            NotificationCenter.default.post(name: .hideOverlay, object: nil)
            hotkeyServiceInstance?.onHideOverlay?()
        case 9:
            NotificationCenter.default.post(name: .copyAnswer, object: nil)
            hotkeyServiceInstance?.onCopyAnswer?()
        case 10:
            NotificationCenter.default.post(name: .toggleOverlay, object: nil)
            hotkeyServiceInstance?.onToggleOverlay?()
        default: break
        }
    }
    return noErr
}

@MainActor
final class HotkeyService {
    var onScreenshot: (() -> Void)?
    var onSendToAI: (() -> Void)?
    var onOpenPopover: (() -> Void)?
    var onToggleMode: (() -> Void)?
    var onAbort: (() -> Void)?
    var onHoverCapture: (() -> Void)?
    var onAskExcelCell: (() -> Void)?
    var onHideOverlay: (() -> Void)?
    var onCopyAnswer: (() -> Void)?
    var onToggleOverlay: (() -> Void)?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    func register() {
        // Unregister existing first
        unregister()
        hotkeyServiceInstance = self

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            return hotkeyHandler(nextHandler: nil, event: event, userData: nil)
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)

        let sig = OSType(0x44524941) // "DRIA"
        let config = HotkeyConfig.load()

        func reg(_ binding: HotkeyBinding, _ id: UInt32) {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(binding.keyCode, binding.modifier,
                                EventHotKeyID(signature: sig, id: id),
                                GetApplicationEventTarget(), 0, &ref)
            hotKeyRefs.append(ref)
        }

        reg(config.capture, 1)         // Capture
        reg(config.sendToAI, 2)        // Send to AI
        reg(config.inlineChat, 3)      // Inline chat
        reg(config.cycleMode, 4)       // Cycle mode
        reg(config.abort, 5)           // Abort
        reg(config.hoverCapture, 6)    // Hover capture + send
        reg(config.askExcelCell, 7)    // Ask Excel cell
        reg(config.hideOverlay, 8)     // Hide overlay — posts dria.hideOverlay
        reg(config.copyAnswer, 9)      // Copy answer — AppState.copyMode
        reg(config.toggleOverlay, 10)  // Toggle overlay — posts dria.toggleOverlay
    }

    func unregister() {
        for ref in hotKeyRefs { if let ref { UnregisterEventHotKey(ref) } }
        hotKeyRefs.removeAll()
        if let handler = eventHandlerRef { RemoveEventHandler(handler); eventHandlerRef = nil }
        hotkeyServiceInstance = nil
    }

    /// Re-register with updated config
    func reloadBindings() {
        register()
    }
}
