# Lane hotkey

Ships: hide overlay, copy answer, toggle overlay as configurable hotkeys. Default hide = ⌥⇧N. Copy answer uses existing `AppState.copyMode`.

Surface: Settings → General → shortcuts shows Hide overlay / Copy answer / Toggle overlay. Pressing ⌥⇧N hides the overlay panel (once overlay lane has wired the notification).

Items: AN4.

Owns: `dria/Services/HotkeyService.swift`, `dria/Views/Settings/GeneralSettingsTab.swift`

Today every binding is registered with hardcoded `let mods = UInt32(cmdKey | optionKey)` (`HotkeyService.swift:158`). That cannot express ⌥⇧N. Store modifiers on `HotkeyBinding` / `HotkeyConfig`. Decoder must keep old saved configs (cmd+option) for capture/send/chat.

Do not register overlay callbacks by editing `driaApp.swift` (forbidden). Post `Notification.Name` (e.g. `dria.hideOverlay`) from `HotkeyService`; overlay lane observes in `OverlayPanel`.

Do not bind Mission Control / CGS symbolic hotkeys 1–9 as the hide key (LDB `hotkeys_blocked`).

`done_when`: `rg -n hideOverlay dria/Services/HotkeyService.swift dria/Views/Settings/GeneralSettingsTab.swift && ! grep -F 'let mods = UInt32(cmdKey | optionKey)' dria/Services/HotkeyService.swift`
