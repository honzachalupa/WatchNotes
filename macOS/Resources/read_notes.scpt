tell application "Notes"
    activate
    delay 1
    if exists note 1 then
        set firstNote to note 1
        return {name of firstNote, body of firstNote}
    else
        return "No notes found"
    end if
end tell
