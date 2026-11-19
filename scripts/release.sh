#!/bin/bash
# Build, sign, notarize and publish a release.
#
#   scripts/release.sh            everything, then a GitHub Release with the DMG
#   SKIP_PUBLISH=1 scripts/release.sh   stop after the notarized DMG (releases/GrammarBuddy-<version>.dmg)
#
# Needs: Xcode, XcodeGen, a "Developer ID Application" certificate for the team in Config/Local.xcconfig,
# a notarytool keychain profile (NOTARY_PROFILE, see `xcrun notarytool store-credentials`), create-dmg and gh.
# The version comes from project.yml (MARKETING_VERSION / CURRENT_PROJECT_VERSION); bump it there first.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export PATH="/opt/homebrew/bin:$PATH"
NOTARY_PROFILE="${NOTARY_PROFILE:-CAPYBUDDY_NOTARY}"
REPO_SLUG="${REPO_SLUG:-ATLAI-TECH/GrammarBuddy}"
XCODEGEN="${XCODEGEN:-$(command -v xcodegen || echo ../tools-dl/xcodegen/bin/xcodegen)}"
TEAM=$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' Config/Local.xcconfig | tr -d ' ')
[ -n "$TEAM" ] || { echo "No DEVELOPMENT_TEAM in Config/Local.xcconfig"; exit 1; }
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
VERSION=$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml)
TAG="v$VERSION"
OUT=build/release; REL=releases
DMG="$REL/GrammarBuddy-$VERSION.dmg"
rm -rf "$OUT"; mkdir -p "$OUT" "$REL"

echo "==> 1/6 archive $VERSION"
"$XCODEGEN" generate >/dev/null
# Signed by hand with the Developer ID certificate: project.yml keeps "Automatic" for day-to-day builds, and Xcode
# refuses a Developer ID identity together with automatic signing. No provisioning profile is needed (not sandboxed,
# no restricted entitlements). --timestamp is required for notarization.
xcodebuild -project GrammarBuddy.xcodeproj -scheme GrammarBuddy -configuration Release \
  -archivePath "$OUT/GrammarBuddy.xcarchive" -derivedDataPath build/dd-release \
  -skipMacroValidation -skipPackagePluginValidation \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$SIGN_IDENTITY" DEVELOPMENT_TEAM="$TEAM" PROVISIONING_PROFILE_SPECIFIER= \
  OTHER_CODE_SIGN_FLAGS="--timestamp" archive > "$OUT/archive.log" 2>&1 \
  || { grep -E ": error:|\*\* ARCHIVE" "$OUT/archive.log" | head -20; exit 1; }

echo "==> 2/6 take the app out of the archive and check its signature"
mkdir -p "$OUT/export"
ditto "$OUT/GrammarBuddy.xcarchive/Products/Applications/GrammarBuddy.app" "$OUT/export/GrammarBuddy.app"
APP="$OUT/export/GrammarBuddy.app"
codesign --verify --deep --strict "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "Authority=Developer ID|Timestamp|flags" | head -3

echo "==> 3/6 notarize the app"
ditto -c -k --keepParent "$APP" "$OUT/GrammarBuddy.zip"
xcrun notarytool submit "$OUT/GrammarBuddy.zip" --keychain-profile "$NOTARY_PROFILE" --wait > "$OUT/notary-app.log" 2>&1 || { tail -20 "$OUT/notary-app.log"; exit 1; }
grep -q "status: Accepted" "$OUT/notary-app.log" || { tail -20 "$OUT/notary-app.log"; exit 1; }
xcrun stapler staple "$APP" >/dev/null

echo "==> 4/6 disk image"
rm -f "$DMG"
create-dmg --volname "GrammarBuddy" --window-size 560 360 --icon-size 110 \
  --icon "GrammarBuddy.app" 150 170 --app-drop-link 410 170 --no-internet-enable \
  --codesign "$SIGN_IDENTITY" "$DMG" "$APP" > "$OUT/dmg.log" 2>&1 || { tail -20 "$OUT/dmg.log"; exit 1; }

echo "==> 5/6 notarize the disk image"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait > "$OUT/notary-dmg.log" 2>&1 || { tail -20 "$OUT/notary-dmg.log"; exit 1; }
grep -q "status: Accepted" "$OUT/notary-dmg.log" || { tail -20 "$OUT/notary-dmg.log"; exit 1; }
xcrun stapler staple "$DMG" >/dev/null
spctl -a -t open --context context:primary-signature -vv "$DMG" 2>&1 | head -2
shasum -a 256 "$DMG"

if [ -n "${SKIP_PUBLISH:-}" ]; then echo "==> done (not published): $DMG"; exit 0; fi
echo "==> 6/6 GitHub Release $TAG"
NOTES="${RELEASE_NOTES:-docs/release-notes/$TAG.md}"
gh release create "$TAG" "$DMG" --repo "$REPO_SLUG" --title "GrammarBuddy $VERSION" --notes-file "$NOTES" --target "$(git rev-parse HEAD)"
echo "==> published: https://github.com/$REPO_SLUG/releases/tag/$TAG"
