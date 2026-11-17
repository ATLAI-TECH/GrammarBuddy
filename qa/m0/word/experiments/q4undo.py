import sys; sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..'))
from wo import W, text, u16
import gbword as g
D="Document8"; R=lambda b: W(D,b)
def revs(): return [R(f'get {{revision type of revision {k} of d, content of text object of revision {k} of d}}') for k in range(1,int(R('count of revisions of d'))+1)]
base=text(D)
# A: toggling track revisions alone
s=int(R('start of content of text object of paragraph (count of paragraphs of d) of d'))
print(R(f'get content of (create range d start {s} end {s+5})'))
R(f'set r to create range d start {s} end {s+5}\nset content of r to "Last"')   # untracked plain edit
R('set track revisions of d to true'); R('set track revisions of d to false')
print("A undo1 ->",R('undo d times 1'), "text restored:", text(D)==base, R('track revisions of d'))
# B: 3 tracked edits via write script, then undo times 3
W(D,'select (create range d start 0 end 334)')
info=g.read(); t=info["text"]
E=[g.find(t,"Plants")+("Plant",), g.find(t,"fast")+("quickly",), g.find(t,"commented")+("annotated",)]
recs,dt=g.write(info,E); print([r for r in recs if r[0]!="REV"])
print("revs after write",len(revs()))
print("B undo3 ->",R('undo d times 3'), "text restored:", text(D)==base, revs())
print("redo test ->",R('redo d times 1'), len(revs())); print(R('undo d times 1'), text(D)==base)
