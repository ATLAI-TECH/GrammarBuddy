#!/bin/bash
# Run harness commands while a host app is frontmost, one tester at a time, then give the front back.
#   qa/front.sh <QA dir> <host bundle id> "<harness commands>"
# Some things only work while the host is in front (Word builds a new document's text, Chrome / Safari report the
# focused field and accept pastes). A lock makes several testers take turns; each turn should stay under ~30 s.
set -u
Q="$1"; BUNDLE="$2"; CMDS="$3"
cd "$(dirname "$0")/.."
LOCK=/tmp/gbqa/.front.lock
for i in $(seq 1 240); do mkdir "$LOCK" 2>/dev/null && break; sleep 0.5; done
[ -d "$LOCK" ] || { echo "could not get the front lock"; exit 1; }
PREV=$(lsappinfo info -only bundleid "$(lsappinfo front)" 2>/dev/null | sed 's/.*="\(.*\)"/\1/')
trap 'open -b "${PREV:-atlai.TermBuddy}" 2>/dev/null; rmdir "$LOCK" 2>/dev/null' EXIT
open -b "$BUNDLE"
sleep 1.2
qa/gbqa.sh "$Q" "$CMDS"
