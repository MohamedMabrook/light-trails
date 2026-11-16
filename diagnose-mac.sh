#!/bin/bash
# Light Trails: collects everything needed to see why the Mac plugin did not load.
# Usage: curl -fsSL https://raw.githubusercontent.com/MohamedMabrook/light-trails/main/diagnose-mac.sh | bash
# The report is printed and copied to the clipboard (paste it into the chat). Nothing is changed.
B="/Library/OFX/Plugins/LightTrails.ofx.bundle"
BIN="$B/Contents/MacOS/LightTrails.ofx"
RL="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve"
{
echo "== system"
sw_vers 2>/dev/null; uname -m; sysctl -n machdep.cpu.brand_string 2>/dev/null
ls -d /Applications/DaVinci\ Resolve*/ 2>/dev/null
defaults read "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Info" CFBundleShortVersionString 2>/dev/null | sed 's/^/Resolve version: /'
echo "== plugin files"
ls -laR "$B" 2>&1 | head -30
echo "== quarantine / extended attributes"
xattr -lr "$B" 2>&1 | head -10
echo "== file type"
file "$BIN" 2>&1
echo "== code signature"
codesign -dvv "$BIN" 2>&1 | head -12
codesign --verify --strict --verbose=2 "$B" 2>&1
echo "== Resolve entitlements (library validation)"
codesign -d --entitlements - "/Applications/DaVinci Resolve/DaVinci Resolve.app" 2>&1 | grep -i -E "library|runtime|allow" | head -8
codesign -dv "/Applications/DaVinci Resolve/DaVinci Resolve.app" 2>&1 | grep -i -E "flags|TeamIdentifier" | head -3
echo "== Light Trails log"
tail -n 20 "$HOME/Library/Logs/LightTrails.log" 2>&1
echo "== Resolve log lines about the plugin"
for L in "$RL"/logs/davinci_resolve.log "$RL"/logs/davinci_resolve.log.1 "$RL"/logs/*.txt; do
  [ -f "$L" ] && grep -i -h -B3 -A8 "lighttrails\|light trails" "$L" 2>/dev/null
done | tail -n 60
echo "-- OFX lines in Resolve's log:"
grep -i -h "ofx" "$RL"/logs/davinci_resolve.log 2>/dev/null | grep -i -E "fail|error|crash|load" | tail -n 15
ls -t "$RL"/logs/ "/Library/Application Support/Blackmagic Design/DaVinci Resolve/logs/" 2>/dev/null | head -8
echo "== Resolve OFX cache entry"
grep -i -A8 "lighttrails" "$RL"/*.xml 2>/dev/null | head -20
echo "== load test (loads the plugin outside Resolve and renders one tiny frame on the GPU)"
T="$(mktemp -d)"
if curl -fsSL -o "$T/lt-loadtest" "https://raw.githubusercontent.com/MohamedMabrook/light-trails/main/tools/mac/lt-loadtest"; then
  chmod +x "$T/lt-loadtest"
  mkdir -p "$T/plugins" && cp -R "$B" "$T/plugins/"
  : > "$HOME/Library/Logs/LightTrails.log.test" 2>/dev/null || true
  ( cd "$T" && LT_ONLY_ENV_PATH=1 OFX_PLUGIN_PATH="$T/plugins" ./lt-loadtest "$T/none" 64 64 1 0 "$T/out.f32" > "$T/run.txt" 2>&1; echo "lt-loadtest exit code: $? (0 ok, 134 abort, 139 crash)" )
  grep -v -e "host: served" -e "host: missing" "$T/run.txt" | tail -n 15
  echo "-- plugin log after the load test:"
  tail -n 8 "$HOME/Library/Logs/LightTrails.log" 2>&1
else
  echo "could not download the load test"
fi
rm -rf "$T"
echo "== recent Resolve crash reports"
ls -t "$HOME/Library/Logs/DiagnosticReports/" 2>/dev/null | grep -i resolve | head -3
} 2>&1 | tee /tmp/lighttrails-report.txt
pbcopy < /tmp/lighttrails-report.txt 2>/dev/null && echo "" && echo "Report copied to the clipboard. Paste it into the chat."
