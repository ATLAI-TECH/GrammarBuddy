on run argv
	set dn to item 1 of argv
	tell application "Microsoft Word"
		set d to document dn
		set n to end of content of text object of d
		set out to {}
		repeat with p from 0 to n - 1
			set c to content of (create range d start p end p + 1)
			if c is missing value then set c to "<MV>"
			set end of out to c
		end repeat
	end tell
	set AppleScript's text item delimiters to (ASCII character 30)
	return out as text
end run
