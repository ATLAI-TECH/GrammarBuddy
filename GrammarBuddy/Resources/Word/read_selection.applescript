-- GrammarBuddy M0: read the Word selection plus everything WordReplacer needs to map and to skip.
-- osascript read_selection.applescript
-- Output: records separated by ASCII 30, fields by ASCII 31. Record kinds:
--   DOC   name, full name, story type, sel start, sel end, track revisions, read only, protection type
--   VIEW  original view settings (already restored when this script returns)
--   TEXT  content of text object of selection (read with the view pinned, see below)
--   FIELD field type, code start, code end, result start, result end, show codes (as found)
--   REV   revision type, start, end, author, date
--   FN    footnote reference start (inside the selection)
--   CM    comment scope start, scope end
--   TBL   table start, end
-- Pinned while reading (Word 16.114: "text retrieval mode" cannot be set, it reads missing value, so the
-- only lever is the window view): revisions view final, balloon revisions, show field codes false,
-- show codes false on each field in the selection. All of it is restored before returning.
on run argv
	set kRS to ASCII character 30
	set kFS to ASCII character 31
	set out to {}
	tell application "Microsoft Word"
		set d to active document
		set sel to text object of selection
		set s0 to start of content of sel
		set e0 to end of content of sel
		set end of out to "DOC" & kFS & (name of d) & kFS & (full name of d) & kFS & ((story type of sel) as text) & kFS & s0 & kFS & e0 & kFS & (track revisions of d) & kFS & (read only of d) & kFS & ((protection type of d) as text)
		set v to view of active window
		set ov to {revisions view of v, revisions mode of v, show field codes of v}
		set end of out to "VIEW" & kFS & ((item 1 of ov) as text) & kFS & ((item 2 of ov) as text) & kFS & (item 3 of ov)
		-- fields: per-field show codes also changes content
		set fl to fields of sel
		set fshow to {}
		repeat with i from 1 to (count of fl)
			set f to item i of fl
			set end of fshow to show codes of f
		end repeat
		try
			set revisions view of v to revisions view final
			set revisions mode of v to balloon revisions
			set show field codes of v to false
			repeat with i from 1 to (count of fl)
				if item i of fshow then set show codes of (item i of fl) to false
			end repeat
			set r to create range d start s0 end e0
			set txt to content of r
			if txt is missing value then set txt to ""
			set end of out to "TEXT" & kFS & txt
			repeat with i from 1 to (count of fl)
				set f to item i of fl
				set fc to field code of f
				set rr to result range of f
				set end of out to "FIELD" & kFS & ((field type of f) as text) & kFS & (start of content of fc) & kFS & (end of content of fc) & kFS & (start of content of rr) & kFS & (end of content of rr) & kFS & (item i of fshow)
			end repeat
		on error m number n
			set end of out to "ERROR" & kFS & n & kFS & m
		end try
		-- restore (always)
		try
			repeat with i from 1 to (count of fl)
				if item i of fshow then set show codes of (item i of fl) to true
			end repeat
		end try
		set revisions view of v to item 1 of ov
		set revisions mode of v to item 2 of ov
		set show field codes of v to item 3 of ov
		-- revisions: "count of revisions of <range>" always returns 0 in 16.114; use the list instead
		set rl to revisions of sel
		repeat with i from 1 to (count of rl)
			set rv to item i of rl
			set t to text object of rv
			set end of out to "REV" & kFS & ((revision type of rv) as text) & kFS & (start of content of t) & kFS & (end of content of t) & kFS & (author of rv) & kFS & ((date value of rv) as text)
		end repeat
		set nl to footnotes of sel
		repeat with i from 1 to (count of nl)
			set end of out to "FN" & kFS & (start of content of note reference of (item i of nl))
		end repeat
		-- comments: "Word comments of <range>" only lists comments whose scope END lies in the range, so a
		-- selection that starts before a comment and ends inside it misses it. Query from s0 to the end of
		-- the story and keep the ones whose scope starts before e0.
		set cl to Word comments of (create range d start s0 end (end of content of text object of d))
		repeat with i from 1 to (count of cl)
			set sc to scope of (item i of cl)
			set cs to start of content of sc
			if cs ≤ e0 then set end of out to "CM" & kFS & cs & kFS & (end of content of sc)
		end repeat
		set tl to tables of sel
		repeat with i from 1 to (count of tl)
			set tr to text object of (item i of tl)
			set end of out to "TBL" & kFS & (start of content of tr) & kFS & (end of content of tr)
		end repeat
	end tell
	set AppleScript's text item delimiters to kRS
	return out as text
end run
