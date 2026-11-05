#!/usr/bin/env bash
# Audit of the Google Play App Bundle before it is uploaded: package, version, target SDK (Play needs 36 for new apps
# and updates since 31 Aug 2026), not debuggable, the "Play" preset built without the playtest feature (so no mock
# shop, ads or test menu), then the universal APK through tools/audit_apk.sh and the 16 KB page alignment of its
# native libraries. Needs bundletool (GameDev/Tools/bundletool-all-*.jar, or $BUNDLETOOL) and JDK 17.
#   bash tools/audit_aab.sh build/labelhunt-0.6.0.aab
set -euo pipefail
AAB="${1:?usage: bash tools/audit_aab.sh <aab>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
JAR="${BUNDLETOOL:-$(ls "$HERE"/../../Tools/bundletool-all-*.jar 2>/dev/null | sort -V | tail -1)}"
[ -f "$JAR" ] || { echo "bundletool not found (set BUNDLETOOL)"; exit 1; }
BT=$(ls -d "${ANDROID_HOME:-$LOCALAPPDATA/Android/Sdk}"/build-tools/* 2>/dev/null | sort -V | tail -1)
ZIPALIGN="$BT/zipalign"; [ -x "$ZIPALIGN.exe" ] && ZIPALIGN="$ZIPALIGN.exe"
DEBUG_KS="${DEBUG_KEYSTORE:-$APPDATA/Godot/keystores/debug.keystore}"
fail=0
echo "== $AAB ($(stat -c %s "$AAB") bytes)"
man=$(java -jar "$JAR" dump manifest --bundle="$AAB" | tr -d '\r')
pkg=$(echo "$man" | grep -o 'package="[^"]*"' | head -1)
target=$(echo "$man" | grep -o 'android:targetSdkVersion="[0-9]*"' | grep -o '[0-9]*')
min=$(echo "$man" | grep -o 'android:minSdkVersion="[0-9]*"' | grep -o '[0-9]*')
echo "-- $pkg $(echo "$man" | grep -o 'android:versionCode="[0-9]*"') $(echo "$man" | grep -o 'android:versionName="[^"]*"')"
echo "-- upload signature (Play checks it against the upload key)"
keytool -printcert -jarfile "$AAB" 2>/dev/null | grep -E "Owner|SHA256:" | head -2 | sed 's/^[[:space:]]*/   /'
keytool -printcert -jarfile "$AAB" 2>/dev/null | grep -q "Owner: CN=Godot" && { echo "FAIL: signed with the Godot debug key"; fail=1; }
echo "-- sdk: min $min, target $target"
[ "${target:-0}" -ge 36 ] || { echo "FAIL: targetSdkVersion below 36"; fail=1; }
echo "$man" | grep -q 'android:debuggable="true"' && { echo "FAIL: debuggable"; fail=1; }
echo "-- preset: the Play build must not carry the playtest feature"
play=$(awk '/^name="Play"$/{p=1} p && /^custom_features=/{print; exit}' "$HERE/../export_presets.cfg")
echo "$play"
[ "$play" = 'custom_features=""' ] || { echo "FAIL: Play preset has custom features"; fail=1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
java -jar "$JAR" build-apks --bundle="$AAB" --output="$tmp/u.apks" --mode=universal --ks="$DEBUG_KS" \
	--ks-pass=pass:android --ks-key-alias=androiddebugkey --key-pass=pass:android >/dev/null
unzip -q -o "$tmp/u.apks" universal.apk -d "$tmp"
echo "-- universal APK"
bash "$HERE/audit_apk.sh" "$tmp/universal.apk" | sed 's/^/   /' || fail=1
echo "-- 16 KB page alignment"
if "$ZIPALIGN" -c -P 16 -v 4 "$tmp/universal.apk" > "$tmp/za.txt" 2>&1; then
	echo "native libraries aligned for 16 KB pages ($(grep -c '\.so' "$tmp/za.txt") checked)"
else
	grep -E '\.so|BAD|fail' "$tmp/za.txt" | head -10; echo "FAIL: 16 KB alignment"; fail=1
fi
[ $fail -eq 0 ] && echo "AAB AUDIT OK" || { echo "AAB AUDIT FAILED"; exit 1; }
