-- GrammarBuddy M0: "撤销本次修改" = reject exactly the revisions this write produced.
-- osascript reject_edits.applescript <docName> s1 e1 [s2 e2 ...]
--   s,e   final Word ranges reported by write_edits.applescript (EDIT records), in document order.
-- Works back to front so earlier ranges stay valid. Inside each range, only "revision insert" and
-- "revision delete" whose text lies entirely inside the range are rejected.
-- Output: REJ k type start end  per rejected revision; SKIP k type start end for anything else found.
on run argv
	set kRS to ASCII character 30
	set kFS to ASCII character 31
	set dn to item 1 of argv
	set n to ((count of argv) - 1) div 2
	set out to {}
	tell application "Microsoft Word"
		set d to document dn
		repeat with k from n to 1 by -1
			set s to (item (2 * k) of argv) as integer
			set e to (item (2 * k + 1) of argv) as integer
			set rl to revisions of (create range d start s end e)
			repeat with i from (count of rl) to 1 by -1
				set rv to item i of rl
				set t to text object of rv
				set rs to start of content of t
				set re to end of content of t
				set ty to revision type of rv
				if rs ≥ s and re ≤ e and (ty is revision insert or ty is revision delete) then
					reject rv
					set end of out to "REJ" & kFS & k & kFS & (ty as text) & kFS & rs & kFS & re
				else
					set end of out to "SKIP" & kFS & k & kFS & (ty as text) & kFS & rs & kFS & re
				end if
			end repeat
		end repeat
	end tell
	set AppleScript's text item delimiters to kRS
	return out as text
end run
