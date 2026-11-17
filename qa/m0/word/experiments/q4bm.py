import sys, subprocess; sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..'))
from wo import W, text, u16
import gbword as g
D="Document8"; R=lambda b: W(D,b)
base=text(D)
W(D,'select (create range d start 0 end 334)')
info=g.read(); t=info["text"]
E=[g.find(t,"fast")+("quickly",), g.find(t,"commented")+("annotated",)]
recs,dt=g.write(info,E); edits=[(int(r[2]),int(r[3])) for r in recs if r[0]=="EDIT"]; print(edits)
for k,(s,e) in enumerate(edits,1):
    for v in [f'make new bookmark at d with properties {{name:"_GB_{k}", text object:(create range d start {s} end {e})}}',
              f'set r to create range d start {s} end {e}\nmake new bookmark at r with properties {{name:"_GB_{k}"}}']:
        try: print("BM",R(v)); break
        except Exception as ex: print("BM ERR",ex)
R('set show hidden bookmarks of (text object of d) to true')
print("bookmarks:",R('get {name, start of bookmark, end of bookmark} of every bookmark of d'))
# user edits afterwards: plain insertion at start + a tracked user edit between
R('set r to create range d start 0 end 0\ninsert text "Hello. " at r')
print("after user edit bookmarks:",R('get {name, start of bookmark, end of bookmark} of every bookmark of d'))
