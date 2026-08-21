Print your working directory. It must be named `dria-lane-<LANE>` (constraint | overlay | hotkey). That is your lane. Read `.parcel/lane-<LANE>.md` in this worktree (copied from the plan). If the directory is not named that way, STOP — you are in the shared repo.

Spec (do not restate, do not fork): read `docs/ABSORB.md` and the Absorb table in `ROADMAP.md` first. Unlockdown research is cited there; also read the named files under `~/Warp/unlockdown/docs/` listed in ABSORB.md.

Standing orders: implement only this lane's items · `gate` after the item (run this lane's `done_when`) · `sync-docs` only your own ROADMAP row (AN* status) · `$convention` singular identifiers.

Forbidden: the other lanes' owned files, listed in `.parcel/absorb-plan.json` for your lane. Shared files (`ROADMAP.md`, `README.md`, `docs/ABSORB.md`) — edit ONLY your own rows/sections.

Rejected (design-blocked — do not "helpfully" build): AAC bypass, exclude-from-capture / `sharingType.none`, process-name spoof, keeping NotesView.app as a second product, Windows overlay kill-evasion.

NotesView prototype is reference-only (`/tmp/ldbcheat`). Do not copy CheatPanel into dria. Port behavior into `OverlayPanel`.

Clipboard detect/auto-answer already lives in `ClipboardService` / `QuestionDetector`. Do not port `/tmp/ldbcheat/nv_question.h`.

When done: commit in this repo's voice; update only your AN* row(s) in ROADMAP.md to done + the command you ran.
