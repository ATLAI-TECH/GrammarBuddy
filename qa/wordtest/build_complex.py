"""(Live-check variant: same structures, with grammar errors after each of them.)
Build the M0 test document inside an already-open, script-created Word document.
Usage: python3 -I build_testdoc.py <DocumentName>
Does not save (saving to a path outside Word's sandbox blocks Word on a modal dialog)."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'm0', 'word'))
from wo import W, text, u16
D = sys.argv[1]
R = lambda body: W(D, body)
def pos(sub, nth=0):
    t = text(D); i = -1
    for _ in range(nth + 1): i = t.index(sub, i + 1)
    return u16(t[:i]), u16(t[:i]) + u16(sub)
R('set track revisions of d to false')
R('set content of text object of d to "Plants such as Arabidopsis thaliana grows fast in the lab and H2O with x2 is used." & return & '
  '"这是一段中文测试文字，用于检查位置换算。🌱 grows here." & return & "See footnote  for detail, their are two reason." & return & '
  '"These is commented words here in the text, and she dont agree." & return & "The quick brown fox jump over the lazy dog." & return & '
  '"A1	B1" & return & "A2	B2" & return & "Final paragraph have a date field: ."')
# formatting (no length change)
s, e = pos("Arabidopsis thaliana"); R(f'set italic of (create range d start {s} end {e}) to true')
s, e = pos("H2O"); R(f'set subscript of font object of (create range d start {s+1} end {s+2}) to true')
s, e = pos("x2"); R(f'set superscript of font object of (create range d start {s+1} end {s+2}) to true')
# DATE field (field type given -> field text must NOT repeat the keyword)
s, e = pos("date field: ."); s = e - 1
R(f'create new field text range (create range d start {s} end {s}) field type field date field text "\\\\@ \\"yyyy-MM-dd\\""')
# table: separator enum name is not understood; integer 1 = tabs works
s, _ = pos("A1\tB1"); _, e = pos("A2\tB2")
R(f'convert to table (create range d start {s} end {e+1}) separator 1')
# comment
s, e = pos("commented words")
R(f'make new Word comment at d with properties {{comment text:"Check this phrase.", scope:(create range d start {s} end {e})}}')
# footnote: "make new footnote" inserts at the SELECTION, so select the point first
s, e = pos("is used."); s = e - 1
R(f'select (create range d start {s} end {s})\nmake new footnote at (create range d start {s} end {s})')
# 'repeat with f in footnotes' also fails (-1708); the returned reference ("footnote 1 of text range id ...") is unusable; go through the document's footnotes
R('repeat with i from 1 to (count of footnotes of d)\nif start of content of note reference of footnote i of d is %d then\nset r to text object of footnote i of d\nset content of r to "A footnote body."\nend if\nend repeat' % s)
# cross-reference to footnote 1
s, e = pos("See footnote ")
R(f'insert cross reference at (create range d start {e} end {e}) reference type reference type footnote '
  f'reference kind reference footnote number reference item "1"')
# ADDIN citation field (stands in for Zotero/EndNote) with a visible result.
# "create new field ... field type field addin" gives an ADDIN field with NO result and show codes = true,
# and setting its result range inserts text after the field. Work-around: make a QUOTE field (has a result),
# then overwrite its code with the ADDIN code. Do not update the field afterwards.
s, e = pos(" in the lab")
R(f'insert text " " at (create range d start {e} end {e})')
R(f'create new field text range (create range d start {e+1} end {e+1}) field type field quote field text "\\"(Smith 2020)\\""')
R('repeat with i from 1 to (count of fields of d)\nif field type of field i of d is field quote then\nset c to field code of field i of d\n'
  'set content of c to " ADDIN ZOTERO_ITEM CSL_CITATION {\\"citationID\\":\\"gb\\"} "\nend if\nend repeat')
# pre-existing tracked revision ("someone else": in practice the same author, see word.md; changing
# the application user name would be a global preference change, and compare needs saving to disk)
# NB: offsets in the read text are NOT Word positions once fields exist (question 2); use the paragraph's own start.
s = int(R('start of content of text object of paragraph 5 of d')) + "The quick brown fox jump over the ".__len__(); e = s + 4
R(f'set track revisions of d to true\nset r to create range d start {s} end {e}\nset content of r to "sleepy"\nset track revisions of d to false')
print(repr(text(D)))
