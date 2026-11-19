"""Exactness test for accepting live suggestions.

For every suggestion: predict the text after accepting it (old text with exactly that range replaced), accept it,
read the host's text back and compare character by character. Any difference is a write that landed in the wrong
place, changed something else, or added / lost characters.

    python3 qa/accepttest/accept_exact.py <qa dir> <host bundle id> [--front] [--order first|last|middle|random] [--max N]

--front: the host only accepts changes while frontmost (Word, browsers): each step goes through qa/front.sh.
The host must already show the test text (qa/host.sh) and live check must be pinned / on.
"""
import json, random, subprocess, sys, time
Q, HOST = sys.argv[1], sys.argv[2]
FRONT = "--front" in sys.argv
ORDER = sys.argv[sys.argv.index("--order") + 1] if "--order" in sys.argv else "random"
MAX = int(sys.argv[sys.argv.index("--max") + 1]) if "--max" in sys.argv else 60
random.seed(7)
def cmd(c):
    a = ["qa/front.sh", Q, HOST, c] if FRONT else ["qa/gbqa.sh", Q, c]
    return subprocess.run(a, capture_output=True, text=True, timeout=240).stdout.strip()
def state(): return json.load(open(Q + "/state.json"))
def u16(s): return s.encode("utf-16-le")
def splice(text, loc, ln, new):
    b = u16(text)
    return (b[:loc * 2] + u16(new) + b[(loc + ln) * 2:]).decode("utf-16-le")
def settle(first=False):
    t0 = time.time(); d = None
    while time.time() - t0 < (90 if first else 30):
        cmd("wait:1.5; dump"); d = state()
        if not d["liveValue"]: continue            # the checker is between two reads
        if "queued" not in d["liveStatus"] and "排队" not in d["liveStatus"] and (d["liveMarksDetail"] or not first): break
    return d
# Safety: the test instance must be restricted to the host. Without it, live check follows the front app and this
# script would accept suggestions into whatever the person at the Mac is typing (it happened on 2026-11-19).
print(cmd(f"guard:{HOST}").splitlines()[-1])
d = settle(first=True)
print(f"start: {d['liveStatus']} | {len(d['liveValue'])} chars")
ok = bad = refused = 0; done = set(); problems = []
for step in range(MAX):
    marks = [(i, m) for i, m in enumerate(d["liveMarksDetail"]) if (m["loc"], m["removed"], m["inserted"]) not in done]
    if not marks: break
    i, m = {"first": marks[0], "last": marks[-1], "middle": marks[len(marks) // 2]}.get(ORDER) or random.choice(marks)
    done.add((m["loc"], m["removed"], m["inserted"]))
    before = d["liveValue"]
    at = u16(before)[m["loc"] * 2:(m["loc"] + m["len"]) * 2].decode("utf-16-le")
    want = splice(before, m["loc"], m["len"], m["inserted"])
    label = f"{m['removed']!r} → {m['inserted']!r} @{m['loc']}"
    r = cmd(f"live:acceptat={m['loc']},{m['len']}; wait:2.2; dump")
    if "SKIPPED" in r or "NOMARK" in r or "BUSY" in r:
        # not a result: the host wasn't in front (someone is using the Mac), or the list changed; try this one again later
        done.discard((m["loc"], m["removed"], m["inserted"]))
        skipped = globals().get("skipped", 0) + 1; globals()["skipped"] = skipped
        print(f"  (not tried: {'host not in front' if 'SKIPPED' in r else 'mark gone'})  {label}")
        if skipped > 12: print("  giving up: the host keeps losing the front"); break
        d = settle(); continue
    d = state(); after = d["liveValue"]
    if at != m["removed"]:
        bad += 1; problems.append(f"MARK RANGE WRONG {label}: text there is {at!r}")
    if after == want: ok += 1; print(f"  ok       {label}")
    elif after == before:
        refused += 1; print(f"  refused  {label}  toast={d['lastToast']!r}")
    else:
        bad += 1
        k = next((j for j in range(min(len(after), len(want))) if after[j] != want[j]), min(len(after), len(want)))
        problems.append(f"WRONG RESULT {label}\n      want …{want[max(0,k-25):k+25]!r}\n      got  …{after[max(0,k-25):k+25]!r}")
        print(f"  WRONG    {label}")
    d = settle()
print(f"\nexact {ok}, refused {refused}, wrong {bad}")
for p in problems: print(" !", p)
print("final text:\n" + d["liveValue"])
