import AppKit
import Foundation

/// Messages is the one supported source that offers a scripting dictionary,
/// allowing a real fallback send after its banner is no longer actionable.
enum MessagesSender {
    static func send(_ text: String, toChatNamed name: String) -> Bool {
        let script = """
        tell application "Messages"
            repeat with p in participants
                try
                    if (name of p as string) is equal to "\(escape(name))" then
                        send "\(escape(text))" to p
                        return "ok"
                    end if
                end try
            end repeat
        end tell
        return "notfound"
        """

        guard let scriptObject = NSAppleScript(source: script) else { return false }
        var error: NSDictionary?
        let output = scriptObject.executeAndReturnError(&error)
        if let error {
            NSLog("[boringNotch] Messages send failed: \(error)")
            return false
        }
        return output.stringValue == "ok"
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
