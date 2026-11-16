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
codesign --verify --verbose=2 "$BIN" 2>&1
echo "== Resolve entitlements (library validation)"
codesign -d --entitlements - "/Applications/DaVinci Resolve/DaVinci Resolve.app" 2>/dev/null | grep -i -A1 "library-validation" | head -4
echo "== Light Trails log"
tail -n 20 "$HOME/Library/Logs/LightTrails.log" 2>&1
echo "== Resolve log lines about the plugin"
grep -i -h -B2 -A6 "lighttrails\|light trails\|OFX\b.*fail\|failed to load" "$RL"/logs/*.txt 2>/dev/null | tail -n 60
echo "== Resolve OFX cache entry"
grep -i -A8 "lighttrails" "$RL"/*.xml 2>/dev/null | head -20
echo "== recent Resolve crash reports"
ls -t "$HOME/Library/Logs/DiagnosticReports/" 2>/dev/null | grep -i resolve | head -3
} 2>&1 | tee /tmp/lighttrails-report.txt
pbcopy < /tmp/lighttrails-report.txt 2>/dev/null && echo "" && echo "Report copied to the clipboard. Paste it into the chat."
