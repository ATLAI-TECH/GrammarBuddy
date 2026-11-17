"""Tiny helper: run AppleScript via osascript with a hard timeout; UTF-16 length helper.
Used by the M0 Word experiments (see docs/m0/word.md)."""
import subprocess, sys, time
def run(script, timeout=60):
    t = time.time()
    p = subprocess.run(["osascript", "-"], input=script.encode(), capture_output=True, timeout=timeout)
    dt = (time.time() - t) * 1000
    out = p.stdout.decode("utf-8")
    if out.endswith("\n"):
        out = out[:-1]
    if p.returncode:
        raise RuntimeError(p.stderr.decode().strip())
    return out, dt
def u16(s):
    return len(s.encode("utf-16-le")) // 2
def W(doc, body, timeout=60):
    """Run body inside tell Word / set d to document <doc>."""
    return run(f'tell application "Microsoft Word"\nset d to document "{doc}"\n{body}\nend tell', timeout)[0]
def text(doc):
    return W(doc, "content of text object of d")
if __name__ == "__main__":
    s = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    out, dt = run(s)
    print(repr(out)); print("u16len", u16(out), "ms %.0f" % dt)
