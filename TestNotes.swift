import Foundation

let script = """
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
"""

let task = Process()
task.launchPath = "/usr/bin/osascript"
task.arguments = ["-e", script]

let pipe = Pipe()
task.standardOutput = pipe
task.standardError = pipe

task.launch()
task.waitUntilExit()

let data = pipe.fileHandleForReading.readDataToEndOfFile()
if let output = String(data: data, encoding: .utf8) {
    print("Notes access: \(output)")
}
