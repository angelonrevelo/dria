# One click after this file has been run once

Worktrees + prompts are provisioned. Open Warp → Command Palette → **Launch Configuration** → `parcel-absorb`.

If worktrees are missing, from `~/Antigravity/dria`:

```bash
bash .parcel/go.sh
```

`go.sh` is idempotent. Merge order: constraint → overlay → hotkey. Teardown: `/cleanup`.
