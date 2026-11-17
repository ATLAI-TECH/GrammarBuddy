import sys; sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..'))
from wo import run,u16
D=sys.argv[1] if len(sys.argv)>1 else "Document5"
R=lambda v: run(f'tell application "Microsoft Word"\nset d to document "{D}"\n{v}\nend tell')[0]
print(repr(R('content of text object of d')))
print("end",R('end of content of text object of d'),"fn",R('count of footnotes of d'),"cm",R('count of Word comments of d'),"tb",R('count of tables of d'),"fld",R('count of fields of d'),"rev",R('count of revisions of d'), "track", R('track revisions of d'))
for i in range(1,int(R('count of footnotes of d'))+1):
    print("fn",i,R(f'set f to footnote {i} of d\nget {{start of content of note reference of f, end of content of note reference of f, content of text object of f}}'))
for i in range(1,int(R('count of Word comments of d'))+1):
    print("cm",i,R(f'set f to Word comment {i} of d\nget {{start of content of scope of f, end of content of scope of f, content of scope of f, content of comment text of f}}'))
for i in range(1,int(R('count of fields of d'))+1):
    print("fld",i,R(f'set f to field {i} of d\nget {{field type of f, start of content of field code of f, end of content of field code of f, content of field code of f, start of content of result range of f, end of content of result range of f, content of result range of f}}'))
for i in range(1,int(R('count of revisions of d'))+1):
    print("rev",i,R(f'set f to revision {i} of d\nget {{revision type of f, start of content of text object of f, end of content of text object of f, content of text object of f, date value of f}}'))
