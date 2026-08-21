#!/bin/sh
# Idempotent: cut absorb worktrees, link desktop/node_modules, drop the prompt.
set -e
ROOT="/Users/angelonrevelo/Antigravity/dria"
cd "$ROOT"

for L in constraint overlay hotkey; do
  BR="lane/$L"
  WT="/Users/angelonrevelo/Antigravity/dria-lane-$L"
  git show-ref --verify --quiet "refs/heads/$BR" || git branch "$BR"
  if git worktree list --porcelain | grep -q "^worktree $WT$"; then
    echo "worktree exists: $WT"
  else
    git worktree add "$WT" "$BR"
  fi
  if [ -d "$ROOT/desktop/node_modules" ]; then
    mkdir -p "$WT/desktop"
    ln -sfn "$ROOT/desktop/node_modules" "$WT/desktop/node_modules"
  fi
  cp "$ROOT/.parcel/prompt.md" "$WT/.parcel-prompt.md"
  echo "ready: $WT"
done

echo "open Warp → Command Palette → Launch Configuration → parcel-absorb"
