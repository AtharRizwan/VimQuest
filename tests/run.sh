#!/usr/bin/env bash
# Runs the VimQuest test suite in an isolated Neovim: temp save folder, no user config, fake audio players
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Saves, sandboxes and caches go to a throwaway folder, so a real player's progress is never touched
export XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache"
mkdir -p "$XDG_DATA_HOME/nvim"
# Easy mode keeps the maze guard and timers still so every run is deterministic
echo '{"unlocked":14,"stars":{},"runes":{},"easy":true}' >"$XDG_DATA_HOME/nvim/vimquest.json"

# Audio players that fail instantly, like a machine with no sound card
export VQ_PLAYER_LOG="$tmp/player.log"
mkdir -p "$tmp/bin"
for p in afplay paplay aplay; do
  printf '#!/bin/sh\necho "$@" >>"%s"\nexit 1\n' "$VQ_PLAYER_LOG" >"$tmp/bin/$p"
  chmod +x "$tmp/bin/$p"
done
export PATH="$tmp/bin:$PATH"

# The music test needs the sound files; build them once if this checkout has none yet
if [ ! -f "$root/lua/vimquest/sfx/theme.wav" ]; then
  echo "Building sound files..."
  python3 "$root/lua/vimquest/sfx/generate.py" >/dev/null
fi

cd "$tmp"
export VQ_REPORT="$tmp/report.txt"
set +e
nvim --headless --clean -u "$root/tests/minimal_init.lua" -c "luafile $root/tests/game_spec.lua" >"$tmp/nvim.log" 2>&1
code=$?
set -e
cat "$VQ_REPORT" 2>/dev/null || true
if [ "$code" -ne 0 ]; then
  echo "Tests failed (exit $code). Neovim output:"
  tail -c 3000 "$tmp/nvim.log"
fi
exit "$code"
