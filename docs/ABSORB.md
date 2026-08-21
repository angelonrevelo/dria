# Absorb NotesView overlay into dria

**Direction:** dria absorbs NotesView. NotesView is a prototype; dria is the product.

NotesView (`/tmp/ldbcheat` → `/Applications/NotesView.app`) proved a floating panel that pins over browsers, click-throughs, hides on ⌥⇧N, and flashes settings on the panel. Clipboard watch already exists in dria (`ClipboardService`, `QuestionDetector`, `copyMode`). Do not port a second clipboard stack.

LockDown Browser / unlockdown research (`~/Warp/unlockdown`) is **constraint**, not a feature: what window levels and affinities get the overlay killed, which hotkeys AAC/CGS steal, and what we must not build.

## Items

| ID | Ships | Grounding |
|---|---|---|
| AN1 | Extract `OverlayPanel` from the inline `NSPanel` in `driaApp.swift`. Pin = `NSWindow.Level.floating` (not `.statusBar`). `canJoinAllSpaces` + `fullScreenAuxiliary`. Edge sliver like NotesView (`rightX - 320`). | `dria/driaApp.swift:171` currently `panel.level = .statusBar`. NotesView: `/tmp/ldbcheat/nv_hotkey.h` `NVPanelLevel` / `NVPanelCollection`. |
| AN2 | Gear on the panel flashes an in-panel settings card. Clipboard short-answer banner on the same panel (`copyMode` short/full already in `AppState`). | NotesView `flashSetting` in `/tmp/ldbcheat/main.m`. dria `AppState.copyMode`, `onMarqueeUpdate`. |
| AN3 | Overlay constraint script encodes LDB findings. Overlay must pass it. | unlockdown `docs/ARCHITECTURE.md` AAC + CGS; `docs/DETECTIONS.md` hotkeys_blocked; `docs/DECONSTRUCTION.md` `GetWindowDisplayAffinity` `0x11`. |
| AN4 | Hotkeys: hide overlay, copy answer, toggle overlay. **Per-binding modifiers** — `HotkeyService` today hardcodes `cmdKey \| optionKey` for every key. Hide default is ⌥⇧N (NotesView). | `dria/Services/HotkeyService.swift:158`. NotesView `NVHideMod`. |
| AN5 | Customization tab: Pin on top, Click-through. Do not add a new “ghost / exclude from capture” control. | `dria/Views/Settings/CustomizationTab.swift`. |
| AN6 | `docs/OVERLAY.md` — LDB-informed overlay rules, cited from unlockdown. | See sources below. |

## Design-blocked (not parcelled)

| ID | Why |
|---|---|
| AN-aac | Punching through Apple Assessment Mode / `assessmentagent`. AAC fail-closed (`ASSESSMENT_MODE_FAILED` / `_INTERRUPTED`). Not a product goal. |
| AN-capture-hide | `sharingType = .none` / `WDA_EXCLUDEFROMCAPTURE` (`0x11`). Windows LDB **kills** that affinity (`DECONSTRUCTION.md` display-protection). Same class on macOS as “hiding from capture.” |
| AN-process-spoof | Renaming the binary to dodge LDB process lists (`DETECTIONS.md` blocklists). |
| AN-notesview-keep | Shipping NotesView as a second app. Absorb, then stop. |
| AN-win-overlay | Windows Tauri overlay vs LDB layered-window kill. Separate slice. |

## LDB / unlockdown sources (read-only)

- `~/Warp/unlockdown/docs/ARCHITECTURE.md` — AAC primary; CGS `CGSSetSymbolicHotKeyEnabled` / `hotkeys_blocked`; `CGWindowListCopyWindowInfo` enumerates owners.
- `~/Warp/unlockdown/docs/DETECTIONS.md` — `hotkey1_enabled`…`hotkey9_enabled`; process blocklists; residual risk “out-of-band notes.”
- `~/Warp/unlockdown/docs/DECONSTRUCTION.md` — Windows overlay / `WDA_EXCLUDEFROMCAPTURE` / layered HWND kill.
- `~/Warp/unlockdown/docs/ASSESSMENT_FINDINGS.md` — kiosk hides menu bar; integrity is client-side.
- `~/Warp/unlockdown/docs/FINDINGS_REGISTER.md` — F-AT / process / window.
- Prototype: `/tmp/ldbcheat/main.m`, `nv_hotkey.h`, `nv_question.h`.

## Acceptance

**Constraint script (RED until overlay exists):**

```bash
bash scripts/overlay-constraint.sh
```

Must PASS all of:

1. `dria/OverlayPanel.swift` exists.
2. Overlay level is floating — **not** `.statusBar`, `.screenSaver`, or `NSStatusWindowLevel`.
3. No `sharingType` / exclude-from-capture / `WDA_EXCLUDEFROMCAPTURE` in overlay code.
4. `fullScreenAuxiliary` (or `canJoinAllSpaces`) present.
5. `ignoresMouseEvents` present (click-through).
6. Script comments cite unlockdown paths above.

**Hotkey:**

```bash
rg -n "hideOverlay" dria/Services/HotkeyService.swift dria/Views/Settings/GeneralSettingsTab.swift
rg -n "cmdKey \| optionKey" dria/Services/HotkeyService.swift
```

Second command must **not** be the only modifier path — per-binding mods required. Default hide = option+shift+N.

**Tip gate** after merge:

```bash
bash scripts/overlay-constraint.sh
rg -n "hideOverlay" dria/Services/HotkeyService.swift
xcodebuild -project dria.xcodeproj -scheme dria -configuration Debug -destination 'platform=macOS' build
```

## NotesView mapping (do not copy files)

| NotesView | dria destination |
|---|---|
| `NVPanelLevel` / pin | `OverlayPanel` level `.floating` |
| `NVPanelCollection` | `canJoinAllSpaces` + `fullScreenAuxiliary` |
| `ignoresMouseEvents` | click-through |
| Gear + `flashSetting` | in-panel settings card |
| Clipboard watch | already `ClipboardService` — banner only |
| ⌥⇧N hide | `HotkeyConfig.hideOverlay` |
| ⌥⇧C copy answer | `HotkeyConfig.copyAnswer` → existing `copyMode` |
