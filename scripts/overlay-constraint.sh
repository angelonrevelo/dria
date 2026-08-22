#!/usr/bin/env bash
# Overlay constraint — LockDown Browser findings encoded as a gate.
# Overlay lane turns this green. This file is allowed to be RED until
# dria/OverlayPanel.swift exists.
#
# Cited (read-only research, not a cheat-client feature):
#
#   ~/Warp/unlockdown/docs/ARCHITECTURE.md
#     AAC primary (ASSESSMENT_MODE_FAILED / ASSESSMENT_MODE_INTERRUPTED fail-closed).
#     CGSSetSymbolicHotKeyEnabled / CGSIsSymbolicHotKeyEnabled
#     disable Mission Control / Spaces (hotkey1_enabled…hotkey9_enabled, hotkeys_blocked).
#     CGWindowListCopyWindowInfo enumerates window owners.
#
#   ~/Warp/unlockdown/docs/DETECTIONS.md
#     hotkey1_enabled … hotkey9_enabled; process blocklists;
#     residual risk “out-of-band notes.” Process name stays dria.
#
#   ~/Warp/unlockdown/docs/DECONSTRUCTION.md
#     GetWindowDisplayAffinity 0x11 = WDA_EXCLUDEFROMCAPTURE | WDA_MONITOR
#     (FUN_1402234f0). Layered HWND overlay is killed / parked off-screen.
#     Do not set sharingType.none / exclude-from-capture on the macOS overlay.
#
#   ~/Warp/unlockdown/docs/ASSESSMENT_FINDINGS.md
#     AAC kiosk hides the menu bar. .statusBar lives in that band — pin
#     OverlayPanel at NSWindow.Level.floating instead.
#
#   ~/Warp/unlockdown/docs/FINDINGS_REGISTER.md
#     F-06 capture-affinity + hardcoded window identity.
#
# Must PASS (docs/ABSORB.md):
#   1. dria/OverlayPanel.swift exists
#   2. overlay level is floating — not .statusBar / .screenSaver / NSStatusWindowLevel
#   3. no sharingType / exclude-from-capture / WDA_EXCLUDEFROMCAPTURE in overlay code
#   4. floating level present
#   5. fullScreenAuxiliary or canJoinAllSpaces
#   6. ignoresMouseEvents (click-through)
#
# AAC punch-through is out of scope. CGS symbolic hotkeys 1–9 may be
# disabled by LDB; overlay hide uses Carbon with option+shift, not Mission
# Control keys. That is a hotkey-lane rule, not asserted here.

set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
panel="$root/dria/OverlayPanel.swift"
fail=0

pass() { printf 'PASS  %s\n' "$*"; }
fail_check() { printf 'FAIL  %s\n' "$*"; fail=$((fail + 1)); }

# Comment-stripped OverlayPanel source (so a "not .statusBar" comment
# does not trip the forbidden-level scan, and a comment-only "floating"
# does not satisfy the required-level scan).
code=""
load_code() {
  if command -v python3 >/dev/null 2>&1; then
    code="$(python3 - "$panel" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
src = re.sub(r"//[^\n]*", "", src)
print(src)
PY
)"
  else
    code="$(sed -E 's|//.*||' "$panel")"
  fi
}

# 1. OverlayPanel.swift exists
if [[ ! -f "$panel" ]]; then
  fail_check "dria/OverlayPanel.swift exists"
else
  pass "dria/OverlayPanel.swift exists"
  load_code
fi

if [[ -z "$code" ]]; then
  fail_check "overlay level is floating — not .statusBar / .screenSaver / NSStatusWindowLevel (no OverlayPanel.swift)"
  fail_check "no sharingType / exclude-from-capture / WDA_EXCLUDEFROMCAPTURE in overlay code (no OverlayPanel.swift)"
  fail_check "floating level present (no OverlayPanel.swift)"
  fail_check "fullScreenAuxiliary or canJoinAllSpaces (no OverlayPanel.swift)"
  fail_check "ignoresMouseEvents (no OverlayPanel.swift)"
  printf '\noverlay-constraint: RED (%d check failed)\n' "$fail"
  exit 1
fi

# 2. Forbidden window levels — AAC kiosk hides the menu-bar band
#    (ASSESSMENT_FINDINGS.md F1). .statusBar / .screenSaver /
#    NSStatusWindowLevel are the same class as "too high / system-owned."
if printf '%s' "$code" | grep -Eq '\.statusBar|\.screenSaver|NSStatusWindowLevel|NSScreenSaverWindowLevel|NSWindow\.Level\.statusBar|NSWindow\.Level\.screenSaver'; then
  fail_check "overlay level is floating — not .statusBar / .screenSaver / NSStatusWindowLevel"
else
  pass "overlay level is floating — not .statusBar / .screenSaver / NSStatusWindowLevel"
fi

# 3. No exclude-from-capture. Windows LDB GetWindowDisplayAffinity 0x11
#    (WDA_EXCLUDEFROMCAPTURE) is the kill signal (DECONSTRUCTION.md).
if printf '%s' "$code" | grep -Ei 'sharingType|exclude.?from.?capture|WDA_EXCLUDEFROMCAPTURE|NSWindowSharingNone' >/dev/null; then
  fail_check "no sharingType / exclude-from-capture / WDA_EXCLUDEFROMCAPTURE in overlay code"
else
  pass "no sharingType / exclude-from-capture / WDA_EXCLUDEFROMCAPTURE in overlay code"
fi

# 4. Pin = NSWindow.Level.floating (NotesView NVPanelLevel)
if printf '%s' "$code" | grep -Eq 'NSWindow\.Level\.floating|NSFloatingWindowLevel|level[[:space:]]*=[[:space:]]*\.floating|\.floating[[:space:]]*\)'; then
  pass "floating level present"
else
  fail_check "floating level present"
fi

# 5. Join Spaces + fullscreen auxiliary (NotesView NVPanelCollection)
if printf '%s' "$code" | grep -Eq 'fullScreenAuxiliary|canJoinAllSpaces'; then
  pass "fullScreenAuxiliary or canJoinAllSpaces"
else
  fail_check "fullScreenAuxiliary or canJoinAllSpaces"
fi

# 6. Click-through
if printf '%s' "$code" | grep -Fq 'ignoresMouseEvents'; then
  pass "ignoresMouseEvents"
else
  fail_check "ignoresMouseEvents"
fi

if [[ "$fail" -ne 0 ]]; then
  printf '\noverlay-constraint: RED (%d check failed)\n' "$fail"
  exit 1
fi

printf '\noverlay-constraint: PASS\n'
exit 0
