-- GrammarBuddy M0: two-pass write of word-level edits as tracked changes.
-- osascript write_edits.applescript <docName> <fullName> <mode> <rs> <re> <rtext> s1 e1 new1 len1 cs1 ce1 ctx1 [s2 ...]
--   rs,re,rtext  the whole range that was read and its text: compared first (whole-range check)
--   s,e     Word positions of the original piece (e = s for a pure insertion)
--   new     replacement text ("" = deletion)
--   len     UTF-16 length of new (AppleScript "length" counts an emoji as 1, Word as 2)
--   cs,ce   Word positions of the check range: the piece extended by one word on each side
--   ctx     expected content of the check range (as read with the pinned view)
--   mode    "plain" = replace directly (the document's own Track Changes setting is left as it is)
--           "track" = write as revisions (track revisions forced on, restored after)
--           "check" = pass 1 only (no write)
-- Edits must be given in document order; they are written back to front.
-- Output (ASCII 30 between records, ASCII 31 between fields):
--   MISMATCH k actual        pass 1 failed at edit k (k = 0: document / whole range), nothing written
-- All comparisons go through sameText (considering case): AppleScript's plain "is" ignores case
-- ("PLANTS" is "Plants" -> true). The handler must live outside the tell block, because inside
-- tell "Microsoft Word" the word "case" is a Word property and "considering case" does not compile.
--   OK n                     then MODE tracked|plain, then per edit: EDIT k s' e'  (final Word range: the new text,
--                            plus the old text when it was kept as a tracked deletion)
--   REV k type start end     revisions found inside that range after writing
on run argv
	set kRS to ASCII character 30
	set kFS to ASCII character 31
	set dn to item 1 of argv
	set fn to item 2 of argv
	set mode to item 3 of argv
	set rs0 to (item 4 of argv) as integer
	set re0 to (item 5 of argv) as integer
	set rtext to item 6 of argv
	set n to ((count of argv) - 6) div 7
	set ed to {}
	repeat with k from 1 to n
		set b to 6 + (k - 1) * 7
		set end of ed to {(item (b + 1) of argv) as integer, (item (b + 2) of argv) as integer, item (b + 3) of argv, (item (b + 5) of argv) as integer, (item (b + 6) of argv) as integer, item (b + 7) of argv, (item (b + 4) of argv) as integer}
	end repeat
	set out to {}
	tell application "Microsoft Word"
		set d to document dn
		-- name/path check
		if fn is not "" and (full name of d) is not fn then return "MISMATCH" & kFS & 0 & kFS & "document path changed"
		set v to view of window 1 of d
		set ov to {revisions view of v, revisions mode of v, show field codes of v}
		set otr to track revisions of d
		set res to ""
		set step to "pin view"
		try
			set revisions view of v to revisions view final
			set revisions mode of v to balloon revisions
			set show field codes of v to false
			set step to "compare"
			-- pass 1: read-only comparison (whole range, then each edit's check range)
				set c to content of (create range d start rs0 end re0)
				if c is missing value then set c to ""
				if not (my sameText(c, rtext)) then set res to "MISMATCH" & kFS & 0 & kFS & c
				if res is "" then
					repeat with k from 1 to n
						set x to item k of ed
						set c to content of (create range d start (item 4 of x) end (item 5 of x))
						if c is missing value then set c to ""
						if not (my sameText(c, item 6 of x)) then
							set res to "MISMATCH" & kFS & k & kFS & c
							exit repeat
						end if
					end repeat
				end if
			if res is "" and (mode is "track" or mode is "plain") then
				-- "plain" leaves the document's own setting alone: a normal document is simply changed; a document
				-- whose owner switched Track Changes on still records the change, because they asked Word to
				if mode is "track" then set track revisions of d to true
				-- Word can answer "missing value" here (seen on a real manuscript, 2026-11-19: the write went through
				-- and then "if tracking" failed with -1700, so the panel reported an error for a change that was made).
				-- Anything that is not plainly true counts as "not tracking".
				-- NB the variable must not be called "tracking": inside this tell block that is a Word term (character
				-- spacing), "if tracking" asked Word for it, got missing value and failed with -1700 after the write
				set step to "read tracking"
				set gbTracked to false
				try
					if (track revisions of d) is true then set gbTracked to true
				end try
				set step to "write"
				-- pass 2: back to front
				repeat with k from n to 1 by -1
					set x to item k of ed
					set r to create range d start (item 1 of x) end (item 2 of x)
					set content of r to (item 3 of x)
				end repeat
				set step to "restore tracking"
				-- put the setting back only if this script changed it, and only to a real true / false: Word sometimes
				-- reports "missing value" for it, and writing that back fails with -1700 after the text was changed
				if mode is "track" and (otr is true or otr is false) then set track revisions of d to otr
				-- collect: edit k ends up at s + sum(len(new_j), j<k); length len(new)+len(old)
				set step to "report"
				set end of out to "OK" & kFS & n
				if gbTracked then
					set end of out to "MODE" & kFS & "tracked"
				else
					set end of out to "MODE" & kFS & "plain"
				end if
				set shift to 0
				repeat with k from 1 to n
					set x to item k of ed
					set s1 to (item 1 of x) + shift
					-- tracked: the old text stays in the document as a deletion; plain: it is gone
					set oldLen to (item 2 of x) - (item 1 of x)
					if gbTracked then
						set e1 to s1 + (item 7 of x) + oldLen
					else
						set e1 to s1 + (item 7 of x)
					end if
					set end of out to "EDIT" & kFS & k & kFS & s1 & kFS & e1
					set rl to revisions of (create range d start s1 end e1)
					repeat with rv in rl
						set t to text object of rv
						set end of out to "REV" & kFS & k & kFS & ((revision type of rv) as text) & kFS & (start of content of t) & kFS & (end of content of t)
					end repeat
					if gbTracked then
						set shift to shift + (item 7 of x)
					else
						set shift to shift + (item 7 of x) - oldLen
					end if
				end repeat
			else if res is "" then
				set end of out to "CHECKED" & kFS & n
			end if
		on error m number en
			set res to "ERROR" & kFS & en & kFS & m & " (at: " & step & ")"
		end try
		-- cleanup path: always restore
		try
			if mode is "track" and (otr is true or otr is false) then set track revisions of d to otr
		end try
		set revisions view of v to item 1 of ov
		set revisions mode of v to item 2 of ov
		set show field codes of v to item 3 of ov
	end tell
	if res is not "" then return res
	set AppleScript's text item delimiters to kRS
	return out as text
end run

on sameText(a, b)
	considering case, diacriticals, hyphens, punctuation and white space
		return (a is b)
	end considering
end sameText
