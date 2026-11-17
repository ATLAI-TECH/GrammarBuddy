"""Word live-check test: wait for marks, then accept every one with a REAL click and a REAL Return, and report
what changed in Word for each (read back through AppleScript). Usage: accept_all.py <qa dir> [max]"""
import json,subprocess,sys,re,time
Q=sys.argv[1]; MAX=int(sys.argv[2]) if len(sys.argv)>2 else 30
def cmd(c): return subprocess.run(["qa/gbqa.sh",Q,c],capture_output=True,text=True,timeout=180).stdout.strip()
def st(): cmd("dump"); return json.load(open(Q+"/state.json"))
def word(): return subprocess.run(["osascript","-e",'tell application "Microsoft Word" to get content of text object of active document'],capture_output=True,text=True,timeout=30).stdout.replace("\r","\n")
def pt(s):
    m=re.search(r"@ (-?\d+),(-?\d+) (\d+)×(\d+)", s); x,y,w,h=map(int,m.groups()); return f"{x+w//2},{y+h//2}"
cmd("live:off; wait:0.5; live:on")
t0=time.time(); first=None
while time.time()-t0<90:
    d=st()
    if d["liveMarks"] and first is None: first=time.time()-t0
    if d["liveMarks"] and "queued" not in d["liveStatus"] and "排队" not in d["liveStatus"]: break
    time.sleep(1)
print(f"first mark {first and round(first,1)}s, all {time.time()-t0:.0f}s | {d['liveStatus']}")
print("AX text:", repr(d["liveValue"])[:700])
for m in d["liveMarks"]: print("  ",m)
tried=set(); ok=bad=0
for _ in range(MAX):
    d=st(); todo=[m for m in d["liveMarks"] if m.split(": ",1)[1].split(" @")[0] not in tried]
    if not todo: break
    mk=todo[0]; name=mk.split(": ",1)[1].split(" @")[0]; tried.add(name)
    b=word()
    cmd(f"realclick:{pt(mk)}; wait:1.4"); c=st()["liveCard"]
    cmd("realkey:return; wait:2.6"); d2=st(); a=word()
    i=0
    while i<min(len(a),len(b)) and a[i]==b[i]: i+=1
    if a==b: bad+=1; cmd("realkey:escape; wait:0.3")
    else: ok+=1
    print(f"[{name}] card={c!r} → {'NOT CHANGED, toast='+repr(d2['lastToast']) if a==b else repr(b[max(0,i-14):i+16])+' ⇒ '+repr(a[max(0,i-14):i+18])}")
print(f"accepted {ok}, refused {bad}")
print("final:", repr(word()))
print("marks left:", st()["liveMarks"])
