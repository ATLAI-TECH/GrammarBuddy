#!/bin/bash
# Drive a running DEBUG GrammarBuddy through its QA harness (GrammarBuddy/QA/QAHarness.swift).
#   qa/gbqa.sh <dir> "cmd1; cmd2; ..."     waits until the app has run them (max 300 s), prints the log
#   qa/gbqa.sh <dir> --launch [--fresh]     starts a new app instance bound to <dir>
set -e
DIR="$1"; shift
APP="${GB_APP:-$(cd "$(dirname "$0")/.." && pwd)/build/dd/Build/Products/Debug/GrammarBuddy.app}"
mkdir -p "$DIR"
if [ "$1" = "--launch" ]; then
  rm -f "$DIR/status" "$DIR/done"
  extra=()
  [ "$2" = "--fresh" ] && extra+=(-gb_qa_fresh YES)
  [ "$3" = "--no-onboarding" ] || [ "$2" = "--no-onboarding" ] && extra+=(-gb_qa_no_onboarding YES)
  open -n "$APP" --args -gb_qa_dir "$DIR" "${extra[@]}"
  for i in $(seq 1 60); do [ -f "$DIR/status" ] && { echo "ready"; exit 0; }; sleep 0.5; done
  echo "app did not start"; exit 1
fi
before=$(cat "$DIR/done" 2>/dev/null || echo 0)
printf '%s' "$1" > "$DIR/cmd"
for i in $(seq 1 1200); do
  now=$(cat "$DIR/done" 2>/dev/null || echo 0)
  if [ "$now" != "$before" ]; then cat "$DIR/log"; exit 0; fi
  sleep 0.25
done
echo "timeout"; exit 1
