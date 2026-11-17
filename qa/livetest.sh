#!/bin/bash
# Live-check test in the real TextEdit with the standard text (qa/testdoc/README.md).
#   qa/livetest.sh [built-in model id]
# Opens a copy, pins TextEdit for the live checker (works even when TextEdit is not frontmost), waits for the
# underlines, checks them, then accepts every mark and compares the text that is left in TextEdit.
set -u
cd "$(dirname "$0")/.."
MODEL="${1:-mlx-community/Qwen3-14B-4bit}"
Q=/tmp/gbqa/livetest
DOC="/tmp/gbtest/live-$(date +%H%M%S).txt"
mkdir -p /tmp/gbtest && cp qa/testdoc/GrammarBuddy-test.txt "$DOC"
pkill -f "gb_qa_dir $Q" 2>/dev/null; sleep 1; rm -rf "$Q"
qa/gbqa.sh "$Q" --launch --fresh --no-onboarding >/dev/null || { echo "app did not start"; exit 1; }
sleep 1
open -a TextEdit "$DOC"; sleep 2
qa/gbqa.sh "$Q" "engine:builtin=$MODEL; live:app=com.apple.TextEdit; live:on" >/dev/null

python3 -I - "$Q" "$DOC" <<'PY'
import json, subprocess, sys, time
Q, DOC = sys.argv[1], sys.argv[2]
orig = open(DOC, encoding="utf-8").read().rstrip("\n").split("\n")
def cmd(c): return subprocess.run(["qa/gbqa.sh", Q, c], capture_output=True, text=True, timeout=300).stdout
def state():
    cmd("dump"); return json.load(open(Q + "/state.json"))
# 1. wait until the number of marks is stable
t0, last, stable = time.time(), -1, 0
while time.time() - t0 < 120:
    time.sleep(3); s = state(); n = len(s["liveMarks"])
    stable = stable + 1 if n == last and n > 0 else 0
    last = n
    if stable >= 3: break
s = state()
if s["liveValue"].rstrip("\n").split("\n")[0] != orig[0]:
    print("FAIL: the live checker is not looking at the test document:", s["liveValue"][:60]); sys.exit(1)
marks = s["liveMarks"]
print(f"marks found: {len(marks)} in {int(time.time() - t0)} s")
for m in marks: print("  ", m)
ok = True
labels = " ".join(marks)
for need in ["Their → There", "reason → reasons", "then → than", "you're → your", "attach → attached", "tomorow → tomorrow", "一至 → 一致"]:
    if need not in labels: print("FAIL: missing mark", need); ok = False
# every mark must have a real on-screen rectangle
for m in marks:
    size = m.rsplit(" ", 1)[-1]
    w, h = [int(x) for x in size.split("×")]
    if w < 3 or h < 5 or h > 60: print("FAIL: odd rectangle", m); ok = False
# 2. accept everything, one at a time
empty = 0
for _ in range(60):
    s = state()
    if not s["liveMarks"]:
        empty += 1
        if empty >= 3: break
        time.sleep(3); continue
    empty = 0
    cmd("live:accept=0; wait:1.5")
time.sleep(6)
s = state()
final = s["liveValue"].rstrip("\n").split("\n")
print("marks left:", len(s["liveMarks"]), "| toast:", s.get("lastToast") or "-")
expect = {0: ["There are three reasons", "flowers earlier than Col-0", "flc-3", "(16 h light / 8 h dark)", "[12, 15]"],
          1: ["your quick reply", "attached", "there are any problems", "Friday"],
          2: ["have finished", "tomorrow", "it's"],
          3: ["这与前人的报道一致", "[12]"]}
for i, needs in expect.items():
    miss = [n for n in needs if i >= len(final) or n.lower() not in final[i].lower()]   # re-checks may also fix capitals
    print(f"paragraph {i + 1}: {'PASS' if not miss else 'FAIL missing ' + str(miss)}  {final[i] if i < len(final) else ''!r}")
    ok = ok and not miss
for i in (4, 5):
    same = i < len(final) and final[i] == orig[i]
    print(f"paragraph {i + 1}: {'PASS (untouched)' if same else 'FAIL: changed'}")
    ok = ok and same
if len(final) != len(orig): print("FAIL: paragraph count changed"); ok = False
print("\nRESULT:", "all passed" if ok else "FAILED")
sys.exit(0 if ok else 1)
PY
RC=$?
qa/gbqa.sh "$Q" "live:off; quit" >/dev/null 2>&1 &
echo "test copy left open in TextEdit: $DOC (close it without saving)"
exit $RC
