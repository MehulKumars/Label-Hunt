#!/usr/bin/env bash
# Security and hygiene audit of an exported APK (plan-m2 section 14): signature, permissions, debuggable flag,
# backup flag, and files that must never ship. Uses the Android SDK build-tools found on this machine.
#   bash tools/audit_apk.sh build/jarful-0.2.0-alpha-arm64.apk
set -euo pipefail
APK="${1:?usage: bash tools/audit_apk.sh <apk>}"
BT=$(ls -d "${ANDROID_HOME:-$LOCALAPPDATA/Android/Sdk}"/build-tools/* 2>/dev/null | sort -V | tail -1)
AAPT2="$BT/aapt2"; [ -x "$AAPT2.exe" ] && AAPT2="$AAPT2.exe"
APKSIGNER="$BT/apksigner"; [ -f "$APKSIGNER.bat" ] && APKSIGNER="$APKSIGNER.bat"
fail=0
echo "== $APK ($(stat -c %s "$APK") bytes)"
echo "-- signature"; "$APKSIGNER" verify --print-certs "$APK" | head -3
echo "-- permissions (only VIBRATE expected)"
pkg=$("$AAPT2" dump packagename "$APK" | tr -d "\r")
echo "package $pkg"
perms=$("$AAPT2" dump permissions "$APK" | grep -o "name='[^']*'" | sed "s/name='//; s/'//" | sort -u)
echo "$perms"
for p in $perms; do case "$p" in android.permission.VIBRATE|"$pkg".*) ;; *) echo "UNEXPECTED permission $p"; fail=1;; esac; done
echo "-- manifest flags"
flags=$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK" | grep -E "debuggable|allowBackup" || true)
echo "$flags"
echo "$flags" | grep -q 'debuggable.*=true\|debuggable.*0xffffffff' && { echo "FAIL: debuggable"; fail=1; }
echo "-- files that must not ship"
bad=$(unzip -l "$APK" | awk '{print $4}' | grep -E '(^|/)(\.claude|tools|tests|docs|reports|shots|data/bank|data/rooms|src/gen)/|\.(keystore|jks)$' || true)
if [ -n "$bad" ]; then echo "$bad"; fail=1; else echo "none"; fi
[ $fail -eq 0 ] && echo "AUDIT OK" || { echo "AUDIT FAILED"; exit 1; }
