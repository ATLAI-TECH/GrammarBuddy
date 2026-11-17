import sys; sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..'))
from wo import W, text, u16
import gbword as g
D="Document8"; R=lambda b: W(D,b)
base=text(D)
def cm(): return R('get {start of content of scope of Word comment 1 of d, end of content of scope of Word comment 1 of d, content of scope of Word comment 1 of d, content of comment text of Word comment 1 of d}') if int(R('count of Word comments of d')) else "NO COMMENT"
for label, subs in [("last word of scope", [("words","terms")]), ("middle (scope = 2 words, edit both)", [("commented words","flagged terms")]), ("first word", [("commented","annotated")])]:
    W(D,'select (create range d start 240 end 290)')
    info=g.read(); t=info["text"]
    E=[g.find(t,a)+(b,) for a,b in subs]
    recs,_=g.write(info,E); ed=[r for r in recs if r[0]=="EDIT"]
    print(label, "| written", ed, "| comment:", cm())
    # accept our revisions in that range -> what does the comment look like then?
    s,e=int(ed[0][2]),int(ed[-1][3])
    R(f'set rl to revisions of (create range d start {s} end {e})\nrepeat with i from (count of rl) to 1 by -1\naccept (item i of rl)\nend repeat')
    print("   after accept:", cm(), repr(R('content of text object of paragraph 4 of d')))
    R('undo d times 10') if False else None
    # restore: undo accept(s) + write
    n=len(E)*2
    R(f'undo d times {n + len(E)}')
    print("   restored:", text(D)==base, cm())
