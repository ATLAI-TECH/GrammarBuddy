import sys; sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..'))
from wo import W, text, u16
import gbword as g
D=sys.argv[1]; R=lambda b: W(D,b)
base=text(D)
W(D,'select (create range d start 0 end 334)')
info=g.read(); t=info["text"]
E=[g.find(t,"grow")+("grows",), g.find(t,"commented")+("annotated",), g.find(t,"fox")+("cat",)]
def chk(label, whole=True):
    recs,_=g.write(info,E,mode="check",whole=whole); print(f"  {label:28s}", ["|".join(r) for r in recs])
print("(0) no change:"); chk("whole+per-edit"); chk("per-edit only",False)
cases=[("(a) insert 'Hello ' at 0", 'insert text "Hello " at (create range d start 0 end 0)', False),
       ("(b) edit after selection (table cell A1->Z1)", 'set r to text object of cell 1 of row 1 of table 1 of d\nset r to create range d start (start of content of r) end (start of content of r) + 2\nset content of r to "Z1"', False),
       ("(c) delete ' fast' inside selection", None, False),
       ("(e) tracked deletion of 'Plants ' before edits", 'set track revisions of d to true\nset content of (create range d start 0 end 7) to ""\nset track revisions of d to false', True)]
for label, cmd, tracked in cases:
    if cmd is None:
        i,j=g.find(t," fast"); s,e=g.word_range(info["pos"],i,j); cmd=f'set content of (create range d start {s} end {e}) to ""'
    R(cmd); print(label, "| doc text now differs:", text(D)!=base)
    chk("whole+per-edit"); chk("per-edit only",False)
    if tracked: R('reject revision 1 of d') if False else R('undo d times 1')
    else: R('undo d times 1')
    print("  restored:", text(D)==base, R('count of revisions of d'))
