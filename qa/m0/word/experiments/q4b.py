import sys; sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..'))
from wo import W, text, u16
import gbword as g
D="Document7"; R=lambda b: W(D,b)
W(D,'select (create range d start 284 end 334)')
info=g.read(); t=info["text"]; print(repr(t), info["revs"])
i,_=g.find(t,"sleepy"); E=[(i,i,"very ")]
print("plan",g.plan(info,E))
recs,dt=g.write(info,E); print(recs)
for k in range(1,int(R('count of revisions of d'))+1):
    print(R(f'get {{revision type of revision {k} of d, start of content of text object of revision {k} of d, end of content of text object of revision {k} of d, content of text object of revision {k} of d}}'))
