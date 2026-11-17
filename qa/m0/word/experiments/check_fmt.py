import sys; sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..'))
from wo import W, text
def check(D):
    R=lambda b: W(D,b)
    out={}
    out["italic Arabidopsis thaliana"]=R('set f to find object of (text object of d)\nset r to text object of paragraph 1 of d\nget {italic of (create range d start (start of content of r) + 15 end (start of content of r) + 35), content of (create range d start (start of content of r) + 15 end (start of content of r) + 35)}')
    out["fields"]=[R(f'get {{field type of field {i} of d, content of field code of field {i} of d, content of result range of field {i} of d}}') for i in range(1,int(R('count of fields of d'))+1)]
    out["footnotes"]=[R(f'get {{start of content of note reference of footnote {i} of d, content of text object of footnote {i} of d}}') for i in range(1,int(R('count of footnotes of d'))+1)]
    out["comments"]=[R(f'get {{start of content of scope of Word comment {i} of d, end of content of scope of Word comment {i} of d, content of scope of Word comment {i} of d, content of comment text of Word comment {i} of d}}') for i in range(1,int(R('count of Word comments of d'))+1)]
    out["revisions"]=[R(f'get {{revision type of revision {i} of d, start of content of text object of revision {i} of d, end of content of text object of revision {i} of d, content of text object of revision {i} of d}}') for i in range(1,int(R('count of revisions of d'))+1)]
    return out
if __name__=="__main__":
    for k,v in check(sys.argv[1]).items(): print(k,":",v)
