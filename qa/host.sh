#!/bin/bash
# Put a text into a real host app for live-check / write-back tests. Never touches existing documents.
#   qa/host.sh textedit <file.txt>     copy to /tmp/gbtest and open in TextEdit
#   qa/host.sh word <file.txt>         NEW unsaved Word document with the text (prints its name)
#   qa/host.sh chrome <file.txt>       local test page with a <textarea>, opened in Chrome
#   qa/host.sh safari <file.txt>       same page, opened in Safari
#   qa/host.sh word-read               text of Word's active document (to verify a change)
set -e
KIND="$1"; SRC="${2:-}"
mkdir -p /tmp/gbtest
STAMP=$(date +%H%M%S)
case "$KIND" in
  textedit) cp "$SRC" "/tmp/gbtest/host-$STAMP.txt"; open -g -a TextEdit "/tmp/gbtest/host-$STAMP.txt"; echo "/tmp/gbtest/host-$STAMP.txt" ;;
  word)
    python3 -I - "$SRC" <<'PY'
import subprocess, sys
t = open(sys.argv[1], encoding="utf-8").read().rstrip("\n")
esc = t.replace("\\", "\\\\").replace('"', '\\"').replace("\n", '" & return & "')
src = f'''tell application "Microsoft Word"
  set d to make new document
  set content of text object of d to "{esc}"
  select (create range d start 0 end 0)
  return name of d
end tell'''
r = subprocess.run(["osascript", "-e", src], capture_output=True, text=True, timeout=90)
print(r.stdout.strip() or r.stderr.strip())
PY
    ;;
  word-read) osascript -e 'tell application "Microsoft Word" to get content of text object of active document' | tr '\r' '\n' ;;
  chrome|safari)
    OUT="/tmp/gbtest/host-$STAMP.html"
    python3 -I - "$SRC" "$OUT" <<'PY'
import html, sys
t = open(sys.argv[1], encoding="utf-8").read().rstrip("\n")
open(sys.argv[2], "w", encoding="utf-8").write(f"""<!doctype html><meta charset="utf-8"><title>GrammarBuddy test page</title>
<style>body{{font:15px -apple-system;margin:30px}}textarea{{width:760px;height:320px;font:15px -apple-system;padding:8px}}</style>
<h3>GrammarBuddy test page</h3><textarea id="t" autofocus>{html.escape(t)}</textarea>
<script>window.onload=()=>{{const t=document.getElementById('t');t.focus();t.setSelectionRange(0,0);}}</script>""")
PY
    if [ "$KIND" = chrome ]; then open -g -a "Google Chrome" "$OUT"; else open -g -a Safari "$OUT"; fi
    echo "$OUT" ;;
  *) echo "usage: qa/host.sh textedit|word|chrome|safari <file> | word-read"; exit 1 ;;
esac
