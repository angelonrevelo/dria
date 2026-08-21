# Lane overlay

Ships: a floating dria panel over any normal browser/fullscreen space — pin, click-through, edge sliver, gear that flashes settings on the panel, clipboard short-answer banner.

Surface: launch dria → overlay panel visible at the screen edge; ⚙ opens settings on the panel; copy a question (existing clipboard watch) shows the short answer on the banner.

Items: AN1, AN2, AN5.

Owns: `dria/OverlayPanel.swift` (new), `dria/driaApp.swift`, `dria/Views/Settings/CustomizationTab.swift`

Replace `inputPanel.level = .statusBar` (`driaApp.swift` ~178) with `OverlayPanel` at `.floating`. Keep the existing inline-ask field behavior inside the new panel or as a child — do not drop ⌘⌥3.

Pin / click-through toggles in CustomizationTab. No new “hide from screenshots” control.

Xcode: `dria/` is a synchronized root group — adding `OverlayPanel.swift` under `dria/` is enough (do not fight `project.pbxproj`).

`done_when`: `bash scripts/overlay-constraint.sh` (constraint lane must have landed that script, or rebase onto `lane/constraint` first if you are blocked).

Prototype reference only: `/tmp/ldbcheat/main.m` `CheatPanel` / `applyPin` / `applyClickThrough` / `flashSetting` / `buildClipBanner`.
