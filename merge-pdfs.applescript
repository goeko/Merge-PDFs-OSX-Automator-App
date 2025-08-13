
(**
 * merge-pdfs.applescript
 * Droplet app: drop/select multiple PDFs -> merges them in given order
 * Output file: "<first-file-basename>-ALL.pdf" in same folder
 *)

use AppleScript version "2.8"
use framework "Foundation"
use framework "Quartz" -- PDFKit
use scripting additions

on open theFiles
	-- Validate input
	if (count of theFiles) is 0 then
		display alert "Keine Dateien übergeben." buttons {"OK"} default button 1 as critical
		return
	end if
	
	-- Convert to NSURLs and ensure PDFs
	set pdfURLs to {}
	repeat with f in theFiles
		set fPOSIX to POSIX path of (f as text)
		set fURL to current application's |NSURL|'s fileURLWithPath:fPOSIX
		set {ok, uti} to (fURL's getResourceValue:(reference) forKey:(current application's NSURLTypeIdentifierKey) |error|:(missing value))
		set isPDF to false
		if ok as boolean then
			if uti as text contains "com.adobe.pdf" then set isPDF to true
		end if
		if not isPDF then
			-- also allow by extension as fallback
			set ext to (fURL's pathExtension() as text)
			if (ext as text)'s lowercaseString() is "pdf" then set isPDF to true
		end if
		if isPDF then
			set end of pdfURLs to fURL
		end if
	end repeat
	
	if (count of pdfURLs) < 2 then
		display alert "Mindestens zwei PDF-Dateien auswählen." buttons {"OK"} default button 1 as critical
		return
	end if
	
	-- Build output URL in same directory as first file
	set firstURL to item 1 of pdfURLs
	set dirURL to firstURL's URLByDeletingLastPathComponent()
	set baseName to (firstURL's URLByDeletingPathExtension()'s lastPathComponent()) as text
	set outName to baseName & "-ALL.pdf"
	set outURL to (dirURL's URLByAppendingPathComponent:outName)
	
	-- If exists, add numeric suffix
	set fm to current application's NSFileManager's defaultManager()
	set i to 2
	repeat while ((outURL's checkResourceIsReachableAndReturnError:(missing value)) as boolean)
		set outName to baseName & "-ALL(" & (i as text) & ").pdf"
		set outURL to (dirURL's URLByAppendingPathComponent:outName)
		set i to i + 1
	end repeat
	
	-- Merge using PDFKit
	set mergedDoc to current application's PDFDocument's alloc()'s init()
	set insertIndex to 0
	repeat with srcURL in pdfURLs
		set srcDoc to current application's PDFDocument's alloc()'s initWithURL:srcURL
		if srcDoc = missing value then
			-- skip unreadable
		else
			set pageCount to srcDoc's pageCount()
			repeat with p from 0 to (pageCount - 1)
				set page to (srcDoc's pageAtIndex:p)
				(mergedDoc's insertPage:page atIndex:insertIndex)
				set insertIndex to insertIndex + 1
			end repeat
		end if
	end repeat
	
	-- Write file
	set ok to mergedDoc's writeToURL:outURL
	if ok as boolean is false then
		display alert "Konnte Ausgabedatei nicht schreiben." buttons {"OK"} default button 1 as critical
		return
	end if
	
	-- Reveal in Finder
	tell application "Finder"
		reveal (POSIX path of (outURL's |path|() as text)) as POSIX file
		activate
	end tell
end open

-- Support running without drag & drop (double-click): prompt for files
on run
	set chosen to choose file with prompt "Wähle zwei oder mehr PDFs zum Zusammenführen:" of type {"com.adobe.pdf"} with multiple selections allowed
	open chosen
end run
