#!/bin/bash
# For contributors without the ATLAI team: build Debug signed with a stable self-signed identity, so the
# Accessibility permission survives rebuilds (design §10). Create the identity once in Keychain Access:
#   Keychain Access → Certificate Assistant → Create a Certificate… → Name "GrammarBuddy Dev",
#   Identity Type "Self Signed Root", Certificate Type "Code Signing".
set -e
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project GrammarBuddy.xcodeproj -scheme GrammarBuddy -configuration Debug -derivedDataPath build/dd \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="GrammarBuddy Dev" DEVELOPMENT_TEAM="" build
echo "Built: build/dd/Build/Products/Debug/GrammarBuddy.app"
