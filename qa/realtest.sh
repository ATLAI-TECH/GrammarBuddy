#!/bin/bash
# End-to-end test in the real TextEdit with the standard test text (qa/testdoc/README.md).
#   qa/realtest.sh [built-in model id]
# For each paragraph: select through Accessibility → Fix → expect ⏎ = replace → press ⏎ → read TextEdit back.
# Every front-app step is guarded: it runs only while TextEdit is frontmost.
set -u
cd "$(dirname "$0")/.."
MODEL="${1:-mlx-community/Qwen3-4B-Instruct-2507-4bit}"
Q=/tmp/gbqa/realtest
WORK=/tmp/gbtest
mkdir -p "$WORK"
DOC="$WORK/GrammarBuddy-test-$(date +%H%M%S).txt"
# no trailing newline issues: keep the file exactly as in the repo
cp qa/testdoc/GrammarBuddy-test.txt "$DOC"

pkill -f "gb_qa_dir $Q" 2>/dev/null; sleep 1
rm -rf "$Q"
qa/gbqa.sh "$Q" --launch --fresh --no-onboarding >/dev/null || { echo "app did not start"; exit 1; }
sleep 1
qa/gbqa.sh "$Q" "engine:builtin=$MODEL; guard:com.apple.TextEdit; dump" >/dev/null
python3 -I -c "import json,sys; d=json.load(open('$Q/state.json')); sys.exit(0 if d['accessibilityTrusted'] else 1)" \
  || { echo "GrammarBuddy has no Accessibility permission (System Settings → Privacy & Security → Accessibility)"; exit 1; }

open -a TextEdit "$DOC"
sleep 2

python3 -I - "$Q" "$DOC" <<'PY'
import json, subprocess, sys, time, re
Q, DOC = sys.argv[1], sys.argv[2]
text = open(DOC, encoding="utf-8").read()
paras = text.split("\n")
def u16(s): return len(s.encode("utf-16-le")) // 2
def cmd(c):
    r = subprocess.run(["qa/gbqa.sh", Q, c], capture_output=True, text=True, timeout=400)
    return r.stdout
def state(): return json.load(open(Q + "/state.json"))
def front_value():
    out = cmd("frontread")
    m = re.search(r"value=\[(.*)\]\s*$", out, re.S)
    return (m.group(1) if m else None), out

expect = {
    0: ["There are", "reasons", "flowers", "than Col-0", "flc-3", "(16 h light / 8 h dark)", "[12, 15]"],
    1: ["your quick reply", "attached", "there are", "problems", "Friday"],
    2: ["have finished", "tomorrow", "it's"],      # "i" may stay lowercase in a casual message
    3: ["这与", "一致", "[12]"],
    5: ["The results were consistent across all three experiments."],
}
results = []
# back to front, so earlier offsets stay valid after a replacement
for i in sorted(expect, reverse=True):
    start = sum(u16(p) + 1 for p in paras[:i])
    length = u16(paras[i])
    log = cmd(f"key:escape; frontselect:{start},{length}; wait:0.3; hotkey:fix; wait:1")
    if "SKIPPED" in log:
        results.append((i, "SKIPPED", "TextEdit was not frontmost")); continue
    t0 = time.time()
    while time.time() - t0 < 90:
        cmd("wait:1; dump")
        s = state()
        if s.get("phase", "").startswith(("done", "failed", "input")): break
    s = state()
    if s.get("phase", "").startswith("input"):          # one retry: the read can time out while the model is busy
        cmd(f"key:escape; wait:1; frontselect:{start},{length}; wait:0.5; hotkey:fix; wait:1")
        t0 = time.time()
        while time.time() - t0 < 90:
            cmd("wait:1; dump"); s = state()
            if s.get("phase", "").startswith(("done", "failed", "input")): break
        s = state(); s["retried"] = True
    row = {"read": s.get("original") == paras[i], "enter": s.get("enter"), "reason": s.get("enterReason", ""),
           "seconds": s.get("thinkingSeconds"), "changes": len(s.get("changes", [])), "phase": s.get("phase", "")[:40], "retried": s.get("retried", False)}
    if not s.get("phase", "").startswith("done"):
        results.append((i, "FAIL", f"panel did not finish: {row}")); continue
    if i == 5:
        ok = row["changes"] == 0
        results.append((i, "PASS" if ok else "FAIL", f"unchanged expected; changes={row['changes']} {row}")); cmd("key:escape"); continue
    if row["enter"] != "replace":
        results.append((i, "FAIL", f"⏎ is {row['enter']} ({row['reason']}), expected replace")); cmd("key:escape"); continue
    cmd("key:return; wait:1.5")
    val, raw = front_value()
    if val is None:
        results.append((i, "FAIL", "could not read TextEdit back: " + raw[:120])); continue
    now = val.split("\n")
    got = now[i] if i < len(now) else ""
    missing = [e for e in expect[i] if e not in got]
    others_intact = all(now[j] == paras[j] for j in range(min(len(now), len(paras))) if j < i)
    ok = not missing and others_intact and len(now) == len(paras)
    results.append((i, "PASS" if ok else "FAIL",
                    f"{row['seconds']}s, {row['changes']} changes → {got!r}" + (f" | missing {missing}" if missing else "")
                    + ("" if others_intact else " | OTHER PARAGRAPHS CHANGED")))
cmd("key:escape")
print()
for i, verdict, detail in sorted(results):
    print(f"paragraph {i + 1}: {verdict}  {detail}")
print()
fails = [r for r in results if r[1] != "PASS"]
print("RESULT:", "all passed" if not fails else f"{len(fails)} of {len(results)} failed")
sys.exit(1 if fails else 0)
PY
RC=$?
qa/gbqa.sh "$Q" "quit" >/dev/null 2>&1 &
echo "test copy left open in TextEdit: $DOC (close it without saving)"
exit $RC
