import sys; sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..'))
from wo import W,text,u16
D=sys.argv[1]; R=lambda b: W(D,b)
base=text(D)
def show(label,t):
    print(label,"| len",u16(t), "| same as base" if t==base else "| "+repr(t))
R('select (create range d start 0 end 0)')
assert R('get name of active window')==D
orig=R('set v to view of active window\nget {revisions view of v, show revisions and comments of v, show insertions and deletions of v, revisions mode of v, show field codes of v, show hidden text of v, show all of v, view type of v}')
print("orig view:",orig)
tests=[("revisions view original",'set revisions view of v to revisions view original'),
       ("show revisions and comments false",'set show revisions and comments of v to false'),
       ("show insertions and deletions false",'set show insertions and deletions of v to false'),
       ("revisions mode in line",'set revisions mode of v to in line revisions'),
       ("show field codes true",'set show field codes of v to true'),
       ("show all true",'set show all of v to true'),
       ("draft view",'set view type of v to draft view'),
       ("show hidden text true",'set show hidden text of v to true')]
restore=('set v to view of active window\nset revisions view of v to {0}\nset show revisions and comments of v to {1}\nset show insertions and deletions of v to {2}\n'
         'set revisions mode of v to {3}\nset show field codes of v to {4}\nset show hidden text of v to {5}\nset show all of v to {6}\nset view type of v to {7}').format(*[x.strip() for x in orig.split(",")])
for label,cmd in tests:
    try:
        t=R('set v to view of active window\n'+cmd+'\nreturn content of text object of d')
        sel=R('set r to create range d start 300 end 334\nreturn content of r')
        show(label,t); print("   range 300-334:",repr(sel), "| end", R('end of content of text object of d'))
    except Exception as ex: print(label,"ERR",ex)
    R(restore)
print("restored:",R('set v to view of active window\nget {revisions view of v, show revisions and comments of v, show insertions and deletions of v, revisions mode of v, show field codes of v, show hidden text of v, show all of v, view type of v}'))
# per-field show codes
t=R('set show codes of field 1 of d to true\nreturn content of text object of d'); show("field 1 show codes true",t)
R('set show codes of field 1 of d to false')
show("after restore",text(D))
