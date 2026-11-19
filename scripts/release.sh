#!/bin/bash
# Build, sign, notarize and publish a release.
#
#   scripts/release.sh            everything, then a GitHub Release with the DMG
#   SKIP_PUBLISH=1 scripts/release.sh   stop after the notarized DMG (releases/GrammarBuddy-<version>.dmg)
#   PUBLISH_ONLY=1 scripts/release.sh   publish the DMG built by the line above (after checking it)
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
if [ -z "${PUBLISH_ONLY:-}" ]; then
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
# Sparkle ships helper programs inside its framework (the installer, the downloader, the updater app). Xcode signs
# the framework but not what is inside it, and notarization rejects helpers without our Developer ID signature.
# Inside out: helpers, framework, then the app again (its seal covers the framework).
SP="$APP/Contents/Frameworks/Sparkle.framework"
if [ -d "$SP" ]; then
  V="$SP/Versions/B"
  codesign -f -s "$SIGN_IDENTITY" -o runtime --timestamp "$V/XPCServices/Installer.xpc"
  codesign -f -s "$SIGN_IDENTITY" -o runtime --timestamp --preserve-metadata=entitlements "$V/XPCServices/Downloader.xpc"
  codesign -f -s "$SIGN_IDENTITY" -o runtime --timestamp "$V/Autoupdate"
  codesign -f -s "$SIGN_IDENTITY" -o runtime --timestamp "$V/Updater.app"
  codesign -f -s "$SIGN_IDENTITY" -o runtime --timestamp "$SP"
  codesign -d --entitlements "$OUT/entitlements.plist" --xml "$APP" 2>/dev/null
  codesign -f -s "$SIGN_IDENTITY" -o runtime --timestamp --entitlements "$OUT/entitlements.plist" "$APP"
fi
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

if [ -n "${SKIP_PUBLISH:-}" ]; then echo "==> done (not published): $DMG   publish with: PUBLISH_ONLY=1 scripts/release.sh"; exit 0; fi
fi   # end of the build part (skipped with PUBLISH_ONLY=1)

echo "==> 6/6 update feed and GitHub Release $TAG"
[ -f "$DMG" ] || { echo "missing $DMG"; exit 1; }
NOTES="${RELEASE_NOTES:-docs/release-notes/$TAG.md}"
# The update feed (appcast.xml): one entry for this version, signed with the Sparkle key in the login keychain.
# It is uploaded as an asset of the release; the app reads .../releases/latest/download/appcast.xml.
SPARKLE_BIN="${SPARKLE_BIN:-build/dd-release/SourcePackages/artifacts/sparkle/Sparkle/bin}"
FEED="build/release-feed"; rm -rf "$FEED"; mkdir -p "$FEED"
cp "$DMG" "$FEED/"
"$SPARKLE_BIN/generate_appcast" --download-url-prefix "https://github.com/$REPO_SLUG/releases/download/$TAG/" \
  --link "https://github.com/$REPO_SLUG/releases/tag/$TAG" -o "$FEED/appcast.xml" "$FEED" 2>&1 | tail -1
grep -q "sparkle:edSignature" "$FEED/appcast.xml" || { echo "the feed has no signature"; exit 1; }
gh release create "$TAG" "$DMG" "$FEED/appcast.xml" --repo "$REPO_SLUG" --title "GrammarBuddy $VERSION" --notes-file "$NOTES" --target "$(git rev-parse HEAD)"
echo "==> published: https://github.com/$REPO_SLUG/releases/tag/$TAG"
