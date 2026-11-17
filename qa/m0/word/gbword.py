"""M0 driver around read_selection.applescript / write_edits.applescript (prototype of WordReplacer).
Edits are given on the text that was read: (i, j, new) in UTF-16 offsets of that text."""
import os, re, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from wordpos import hidden_intervals, build_map, word_range
from wo import u16

def osa(script, args, timeout=120):
    t = time.time()
    p = subprocess.run(["osascript", os.path.join(HERE, script)] + [str(a) for a in args],
                       capture_output=True, timeout=timeout)
    dt = (time.time() - t) * 1000
    if p.returncode:
        raise RuntimeError(p.stderr.decode().strip())
    out = p.stdout.decode()
    if out.endswith("\n"): out = out[:-1]
    return [r.split("\x1f") for r in out.split("\x1e")], dt

def read():
    recs, dt = osa("read_selection.applescript", [])
    info = {"fields": [], "revs": [], "fns": [], "cms": [], "tbls": [], "ms": dt}
    for r in recs:
        k = r[0]
        if k == "DOC":
            info.update(name=r[1], full=r[2], story=r[3], start=int(r[4]), end=int(r[5]), track=r[6], ro=r[7], prot=r[8])
        elif k == "TEXT": info["text"] = "\x1f".join(r[1:])
        elif k == "FIELD": info["fields"].append((r[1],) + tuple(int(x) for x in r[2:6]))
        elif k == "REV": info["revs"].append((r[1], int(r[2]), int(r[3]), r[4], r[5]))
        elif k == "FN": info["fns"].append(int(r[1]))
        elif k == "CM": info["cms"].append((int(r[1]), int(r[2])))
        elif k == "TBL": info["tbls"].append((int(r[1]), int(r[2])))
        elif k == "VIEW": info["view"] = r[1:]
        elif k == "ERROR": raise RuntimeError(r)
    dels = [(s, e) for t, s, e, a, dd in info["revs"] if t == "revision delete"]
    info["pos"] = build_map(info["text"], info["start"],
                            hidden_intervals([f[1:] for f in info["fields"]], dels))
    return info

def u16slice(s, i, j):
    b = s.encode("utf-16-le"); return b[2*i:2*j].decode("utf-16-le")

WORD = re.compile(r"\w", re.U)
def context(text, i, j):
    """Extend [i, j) (UTF-16) by one word on each side."""
    s = text.encode("utf-16-le").decode("utf-16-le")  # python str; offsets below are str offsets
    # convert utf16 -> str index
    def to_str(k):
        acc = 0
        for idx, ch in enumerate(s):
            if acc >= k: return idx
            acc += 2 if ord(ch) > 0xFFFF else 1
        return len(s)
    a, b = to_str(i), to_str(j)
    while a > 0 and not WORD.match(s[a-1]): a -= 1
    while a > 0 and WORD.match(s[a-1]): a -= 1
    while b < len(s) and not WORD.match(s[b]): b += 1
    while b < len(s) and WORD.match(s[b]): b += 1
    return u16(s[:a]), u16(s[:b])

def plan(info, edits):
    """edits: [(i, j, new)] sorted, non-overlapping, UTF-16 offsets into info['text']."""
    args = []
    pos, text = info["pos"], info["text"]
    for i, j, new in sorted(edits):
        ws, we = word_range(pos, i, j)
        ci, cj = context(text, i, j)
        cs, ce = word_range(pos, ci, cj)
        args += [ws, we, new, u16(new), cs, ce, u16slice(text, ci, cj)]
    return args

def write(info, edits, mode="track", doc=None, full=None, whole=True):
    rng = [info["start"], info["end"], info["text"]] if whole else [0, 0, ""]
    args = [doc or info["name"], info["full"] if full is None else full, mode] + rng + plan(info, edits)
    return osa("write_edits.applescript", args)

def find(text, sub, nth=0):
    i = -1
    for _ in range(nth + 1): i = text.index(sub, i + 1)
    return u16(text[:i]), u16(text[:i]) + u16(sub)
