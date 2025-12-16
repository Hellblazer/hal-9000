-- DEVONthink Import Tool
-- Usage: osascript import.applescript "mode" "source" "name" "tags" "database" "groupPath"
-- Modes: "file" (local), "webarchive" (URL to web doc), "download" (URL to file)

on run argv
	set importMode to item 1 of argv
	set sourceInput to item 2 of argv
	set customName to ""
	set tagsString to ""
	set targetDatabase to ""
	set targetGroup to ""

	if (count of argv) > 2 then
		set customName to item 3 of argv
	end if

	if (count of argv) > 3 then
		set tagsString to item 4 of argv
	end if

	if (count of argv) > 4 then
		set targetDatabase to item 5 of argv
	end if

	if (count of argv) > 5 then
		set targetGroup to item 6 of argv
	end if

	-- Validate input
	if sourceInput is "" then
		return "{\"error\":\"Source path or URL is required\"}"
	end if

	-- Parse tags
	set tagList to {}
	if tagsString is not "" then
		set oldDelims to AppleScript's text item delimiters
		set AppleScript's text item delimiters to ","
		set newTags to text items of tagsString
		set AppleScript's text item delimiters to oldDelims

		repeat with i from 1 to count of newTags
			set tagText to item i of newTags as text
			set trimmedTag to my simpleTrim(tagText)
			if trimmedTag is not "" then
				set end of tagList to trimmedTag
			end if
		end repeat
	end if

	try
		tell application id "DNtp"
			-- Determine target location
			set targetLocation to missing value

			if targetDatabase is not "" then
				set db to database targetDatabase
				if targetGroup is not "" then
					set targetLocation to create location targetGroup in db
				else
					set targetLocation to db
				end if
			else
				set targetLocation to incoming group of current database
			end if

			-- Import based on mode
			set importedRecord to missing value

			if importMode is "file" then
				-- Local file import
				set importedRecord to import sourceInput to targetLocation

			else if importMode is "webarchive" then
				-- Create web archive from URL
				set importedRecord to create web document from sourceInput in targetLocation

			else if importMode is "download" then
				-- Download file and import (for PDFs, etc.)
				set tempDir to (do shell script "mktemp -d")

				-- Extract filename using shell (use unique var name to avoid DEVONthink conflicts)
				set dlFileName to do shell script "echo " & quoted form of sourceInput & " | sed 's/\\?.*$//' | sed 's|.*/||'"
				if dlFileName does not contain "." then
					set dlFileName to dlFileName & ".pdf"
				end if
				if dlFileName is "" then
					set dlFileName to "import_" & (do shell script "date +%s") & ".pdf"
				end if

				set tempFile to tempDir & "/" & dlFileName

				-- Download with curl (with safety flags)
				-- --fail: fail on HTTP errors, --max-filesize: 100MB limit, --connect-timeout: 30s, --max-time: 300s
				set curlCmd to "curl -L -s --fail --max-filesize 104857600 --connect-timeout 30 --max-time 300 -o " & quoted form of tempFile & " " & quoted form of sourceInput
				do shell script curlCmd

				-- Check file exists
				try
					do shell script "test -s " & quoted form of tempFile
				on error
					do shell script "rm -rf " & quoted form of tempDir
					error "Download failed: empty or missing file"
				end try

				-- Import the downloaded file
				set importedRecord to import tempFile to targetLocation

				-- Cleanup
				do shell script "rm -rf " & quoted form of tempDir
			else
				return "{\"error\":\"Unknown import mode: " & importMode & "\"}"
			end if

			-- Apply custom name if provided
			if customName is not "" then
				set name of importedRecord to customName
			end if

			-- Apply tags if any
			if (count of tagList) > 0 then
				set tags of importedRecord to tagList
			end if

			-- Extract properties
			set recordUUID to uuid of importedRecord
			set recordName to name of importedRecord
			set recordType to type of importedRecord as string
			set recordPath to path of importedRecord
			set recordTags to tags of importedRecord
			set recordSize to size of importedRecord

		end tell

		-- Build JSON response
		set tagsJSON to "["
		if (count of recordTags) > 0 then
			repeat with i from 1 to count of recordTags
				set tagText to item i of recordTags as text
				set escapedTag to my escapeString(tagText)
				set tagsJSON to tagsJSON & "\"" & escapedTag & "\""
				if i < (count of recordTags) then
					set tagsJSON to tagsJSON & ","
				end if
			end repeat
		end if
		set tagsJSON to tagsJSON & "]"

		set docJSON to "{"
		set docJSON to docJSON & "\"uuid\":\"" & recordUUID & "\","
		set docJSON to docJSON & "\"name\":\"" & my escapeString(recordName) & "\","
		set docJSON to docJSON & "\"type\":\"" & recordType & "\","
		set docJSON to docJSON & "\"path\":\"" & my escapeString(recordPath) & "\","
		set docJSON to docJSON & "\"tags\":" & tagsJSON & ","
		set docJSON to docJSON & "\"size\":" & recordSize & ""
		set docJSON to docJSON & "}"

		return docJSON

	on error errMsg
		return "{\"error\":\"Import failed: " & my escapeString(errMsg) & "\"}"
	end try
end run

on getFilenameFromUrl(url)
	try
		set fileName to do shell script "echo " & quoted form of url & " | sed 's/\\?.*$//' | sed 's|.*/||'"

		if fileName does not contain "." then
			set fileName to fileName & ".pdf"
		end if

		if fileName is "" then
			return "import_" & (do shell script "date +%s") & ".pdf"
		end if

		return fileName
	on error
		return "import_" & (do shell script "date +%s") & ".pdf"
	end try
end getFilenameFromUrl

on escapeString(str)
	set str to my replaceText(str, "\\", "\\\\")
	set str to my replaceText(str, "\"", "\\\"")
	set str to my replaceText(str, return, "\\r")
	set str to my replaceText(str, linefeed, "\\n")
	set str to my replaceText(str, tab, "\\t")
	set cleanStr to ""
	repeat with i from 1 to length of str
		set c to character i of str
		set cid to id of c
		if cid < 32 and cid is not 9 and cid is not 10 and cid is not 13 then
			-- Skip control character
		else
			set cleanStr to cleanStr & c
		end if
	end repeat
	return cleanStr
end escapeString

on simpleTrim(str)
	set str to str as text
	repeat while str begins with " " or str begins with tab
		if (length of str) > 1 then
			set str to text 2 thru -1 of str
		else
			return ""
		end if
	end repeat
	repeat while str ends with " " or str ends with tab
		if (length of str) > 1 then
			set str to text 1 thru -2 of str
		else
			return ""
		end if
	end repeat
	return str
end simpleTrim

on replaceText(theText, findStr, replaceStr)
	set AppleScript's text item delimiters to findStr
	set textItems to text items of theText
	set AppleScript's text item delimiters to replaceStr
	set theText to textItems as text
	set AppleScript's text item delimiters to ""
	return theText
end replaceText
