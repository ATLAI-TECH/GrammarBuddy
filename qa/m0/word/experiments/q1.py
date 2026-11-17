import sys; sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..'))
from wo import W, text, u16
import gbword as g
D=sys.argv[1]
W(D,'select (create range d start 0 end 334)')
info=g.read(); t=info["text"]
print("read ms %.0f"%info["ms"], "sel", info["start"], info["end"], "u16", u16(t))
E=[]
for sub,new,nth in [("Plants","Plant",0),("grow","grows",0),("fast","quickly",0),("used","applied",0),("commented","annotated",0)]:
    i,j=g.find(t,sub,nth); E.append((i,j,new))
print("plan", g.plan(info,E))
recs,dt=g.write(info,E)
print("write ms %.0f"%dt)
for r in recs: print(r)
