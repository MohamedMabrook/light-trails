#!/bin/bash
# Light Trails installer for macOS (Apple Silicon).
#   Latest:      curl -fsSL https://raw.githubusercontent.com/MohamedMabrook/light-trails/main/install-mac.sh | bash
#   A version:   curl -fsSL .../install-mac.sh | bash -s -- 2.2-mac
#   List:        curl -fsSL .../install-mac.sh | bash -s -- list
#   Remove:      curl -fsSL .../install-mac.sh | bash -s -- uninstall
set -euo pipefail

BASE="https://raw.githubusercontent.com/MohamedMabrook/light-trails/main"
DEST="${LT_DEST:-/Library/OFX/Plugins}"   # LT_DEST: test override
BUNDLE="$DEST/LightTrails.ofx.bundle"
BACKUP="$HOME/Library/Application Support/LightTrails/backup"
WANT="${1:-latest}"

say()  { printf '%s\n' "$*"; }
fail() { printf 'Install failed: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "this installer is for macOS."
[ "$(uname -m)" = arm64 ]  || fail "Light Trails for Mac needs an Apple Silicon Mac (M1 or newer)."

installed="nothing"
if [ -f "$BUNDLE/Contents/VERSION.txt" ]; then installed="$(cat "$BUNDLE/Contents/VERSION.txt")"
elif [ -d "$BUNDLE" ]; then installed="unknown version"; fi
say ""
say "Light Trails installer for Mac"
say "Installed now: $installed"

LIST="$(curl -fsSL "$BASE/versions-mac.txt")" || fail "could not reach GitHub."
LIST="$(printf '%s\n' "$LIST" | grep -v '^#' | grep '|')"

if [ "$WANT" = list ]; then
  printf '%s\n' "$LIST" | while IFS='|' read -r v f t r; do
    tag=""; [ "$r" = yes ] && tag="  <- recommended"
    say "  $v  $t$tag"
  done
  exit 0
fi

wait_for_resolve() {
  while pgrep -xq Resolve; do
    say "DaVinci Resolve is running. Save your work, quit it, then press Enter."
    read -r _ < /dev/tty
  done
}

backup_existing() {
  if [ -d "$BUNDLE" ]; then
    local d="$BACKUP/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$d"
    cp -R "$BUNDLE" "$d/"
    say "Backed up the current version to $d"
  fi
}

if [ "$WANT" = uninstall ]; then
  wait_for_resolve
  backup_existing
  say "Removing Light Trails (macOS will ask for your password)..."
  sudo rm -rf "$BUNDLE"
  say "Removed."
  exit 0
fi

if [ "$WANT" = latest ]; then
  LINE="$(printf '%s\n' "$LIST" | awk -F'|' '$4=="yes"{print; exit}')"
else
  LINE="$(printf '%s\n' "$LIST" | awk -F'|' -v w="$WANT" '$1==w{print; exit}')"
fi
[ -n "$LINE" ] || fail "no version '$WANT'. Run with 'list' to see them."
IFS='|' read -r VER FILE TITLE REC <<< "$LINE"

say "Installing Light Trails $VER: $TITLE"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL -o "$TMP/pkg.zip" "$BASE/$FILE" || fail "download failed."
unzip -q "$TMP/pkg.zip" -d "$TMP/pkg" || fail "could not unzip the package."
SRC="$(find "$TMP/pkg" -type d -name LightTrails.ofx.bundle -print -quit)"
[ -n "$SRC" ] && [ -f "$SRC/Contents/MacOS/LightTrails.ofx" ] || fail "package has no plugin."

wait_for_resolve
backup_existing
say "Copying into $DEST (macOS will ask for your password)..."
sudo mkdir -p "$DEST"
sudo rm -rf "$BUNDLE"
sudo cp -R "$SRC" "$BUNDLE"
printf '%s\n' "$VER" | sudo tee "$BUNDLE/Contents/VERSION.txt" > /dev/null
sudo xattr -dr com.apple.quarantine "$BUNDLE" 2>/dev/null || true
say ""
say "Installed to $BUNDLE"
say "Open Resolve: Color page > Effects > OpenFX > Light Trails."
say "Log: ~/Library/Logs/LightTrails.log"
