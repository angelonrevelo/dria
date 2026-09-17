# Overlay rules (macOS)

> **Status: superseded.** The `OverlayPanel` these rules govern was removed from the runtime in favor of the cursor-following `AnswerCard` (see [../ROADMAP.md](../ROADMAP.md)). This document is retained as the design record for `OverlayPanel.swift`, which is no longer instantiated. The AnswerCard is a normal, capturable, labeled floating window and does not implement these unlockdown-derived constraints.

LockDown Browser / unlockdown research is **constraint**, not a feature. `OverlayPanel` must satisfy these rules. AAC punch-through is out of scope.

NotesView (`/tmp/ldbcheat`) is reference-only. Port behavior into `OverlayPanel`; do not keep NotesView.app.

## Pin

| Rule | Value | Why |
|---|---|---|
| Window level | `NSWindow.Level.floating` | NotesView `NVPanelLevel`. **Not** `.statusBar`, `.screenSaver`, or `NSStatusWindowLevel`. `.statusBar` sits in the menu-bar band; AAC kiosk hides the menu bar (`~/Warp/unlockdown/docs/ASSESSMENT_FINDINGS.md` F1). |
| Space | `canJoinAllSpaces` | NotesView `NVPanelCollection`. Overlay follows the exam Space. |
| Fullscreen | `fullScreenAuxiliary` | Stay above a fullscreen browser without becoming the fullscreen app. |
| Click-through | `ignoresMouseEvents` | Overlay does not steal clicks from the exam. |

The inline input `NSPanel` in `driaApp.swift` (`panel.level = .statusBar`) is a different window. Do not treat it as `OverlayPanel`.

## Forbidden (design-blocked)

| Do not | Why | Source |
|---|---|---|
| Punch through Apple Assessment Mode / `assessmentagent` | AAC fail-closed: `ASSESSMENT_MODE_FAILED` / `ASSESSMENT_MODE_INTERRUPTED` → exit. Not a product goal. | `~/Warp/unlockdown/docs/ARCHITECTURE.md` AAC primary; `DETECTIONS.md` |
| `sharingType = .none` / `WDA_EXCLUDEFROMCAPTURE` (`0x11`) | Windows LDB `GetWindowDisplayAffinity` flags affinity `0x11` (`WDA_EXCLUDEFROMCAPTURE \| WDA_MONITOR`) and kills / parks that window (`FUN_1402234f0`). Same class on macOS as “hide from capture.” No new ghost / exclude-from-capture control. | `~/Warp/unlockdown/docs/DECONSTRUCTION.md` display-protection; `FINDINGS_REGISTER.md` F-06 |
| Rename the binary to dodge process lists | List-based process policy (SSD process-name arrays). Residual risk is out-of-band notes (phone / paper), not a renamed binary. Process name stays `dria`. | `~/Warp/unlockdown/docs/DETECTIONS.md` process blocklists |
| Keep NotesView.app as a second product | Prototype; absorb, then stop. | [ABSORB.md](ABSORB.md) AN-notesview-keep |
| Windows overlay kill-evasion (layered HWND) | LDB parks layered overlay windows off-screen. Separate slice. | `~/Warp/unlockdown/docs/DECONSTRUCTION.md` `WS_EX` layered bit |

## Hotkey (constraint on the hotkey lane)

CGS symbolic hotkeys 1–9 may be disabled by LDB so overlay hide uses Carbon with option+shift, not Mission Control keys.

LDB imports `CGSSetSymbolicHotKeyEnabled` / `CGSIsSymbolicHotKeyEnabled` and stores `hotkey1_enabled`…`hotkey9_enabled` plus `hotkeys_blocked` (`~/Warp/unlockdown/docs/ARCHITECTURE.md` WindowServer / CGS; `DETECTIONS.md`). Mission Control / Spaces chords go through that CGS table. Carbon `RegisterEventHotKey` with option+shift (NotesView `NVHideMod` = ⌥⇧N) does not.

Default hide = option+shift+N. Copy answer = option+shift+C via existing `copyMode`. Per-binding modifiers — do not hardcode `cmdKey \| optionKey` for every key.

## Process identity

Process name stays `dria` (`PRODUCT_NAME` / `dria.app`). Do not spoof.

## Gate

```bash
bash scripts/overlay-constraint.sh
```

RED until `dria/OverlayPanel.swift` exists and satisfies the pin / forbidden / space / click-through checks. Overlay lane turns it green.

## Sources (read-only)

| Path | What it constrains |
|---|---|
| `~/Warp/unlockdown/docs/ARCHITECTURE.md` | AAC primary; `CGSSetSymbolicHotKeyEnabled`; `hotkeys_blocked`; `CGWindowListCopyWindowInfo` enumerates owners |
| `~/Warp/unlockdown/docs/DETECTIONS.md` | `hotkey1_enabled`…`hotkey9_enabled`; process blocklists; residual “out-of-band notes” |
| `~/Warp/unlockdown/docs/DECONSTRUCTION.md` | `GetWindowDisplayAffinity` `0x11` = `WDA_EXCLUDEFROMCAPTURE`; layered HWND kill |
| `~/Warp/unlockdown/docs/ASSESSMENT_FINDINGS.md` | Kiosk hides menu bar; integrity is client-side |
| `~/Warp/unlockdown/docs/FINDINGS_REGISTER.md` | F-06 capture-affinity; F-AT process / window |
| `/tmp/ldbcheat` `nv_hotkey.h` | `NVPanelLevel` / `NVPanelCollection` / `NVHideMod` (reference only) |
