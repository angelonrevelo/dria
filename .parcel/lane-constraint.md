# Lane constraint

Ships: LDB-informed overlay rules as a document + a RED script the overlay lane must turn green.

Surface: `docs/OVERLAY.md` and `bash scripts/overlay-constraint.sh` (must exist; will fail until OverlayPanel exists — that is correct).

Items: AN3, AN6.

Owns: `docs/OVERLAY.md`, `scripts/overlay-constraint.sh`

Read: `docs/ABSORB.md`, `~/Warp/unlockdown/docs/ARCHITECTURE.md`, `DETECTIONS.md`, `DECONSTRUCTION.md` (WDA 0x11), `ASSESSMENT_FINDINGS.md`.

Script MUST assert, and comment-cite unlockdown paths:

1. `dria/OverlayPanel.swift` exists
2. no `.statusBar` / `.screenSaver` / `NSStatusWindowLevel` on the overlay
3. no exclude-from-capture / `sharingType` none / `WDA_EXCLUDEFROMCAPTURE`
4. floating level
5. `fullScreenAuxiliary` or `canJoinAllSpaces`
6. `ignoresMouseEvents`

`done_when`: `test -f docs/OVERLAY.md && test -f scripts/overlay-constraint.sh && rg -n 'WDA_EXCLUDEFROMCAPTURE|CGSSetSymbolicHotKey|floating' scripts/overlay-constraint.sh docs/OVERLAY.md`

OVERLAY.md must say: AAC punch-through is out of scope; CGS symbolic hotkeys 1–9 may be disabled by LDB so overlay hide uses Carbon with option+shift, not Mission Control keys; process name stays `dria`.
