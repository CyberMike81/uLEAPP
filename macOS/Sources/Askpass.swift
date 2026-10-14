import AppKit

// Runs as a separate sudo askpass process. Its stdout goes directly to sudo,
// never through the updater's status stream or log. No password is persisted.
func runAskpass() -> Never {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    let alert = NSAlert()
    alert.messageText = "Authorize Homebrew"
    alert.informativeText = "Homebrew needs your Mac login password to update apps in Applications. uLEAPP passes it directly to sudo and does not save it."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Authorize")
    alert.addButton(withTitle: "Cancel")
    let password = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 26))
    password.placeholderString = "Mac login password"
    password.setAccessibilityLabel("Mac login password")
    alert.accessoryView = password
    application.activate(ignoringOtherApps: true)
    alert.window.initialFirstResponder = password
    guard alert.runModal() == .alertFirstButtonReturn else { exit(1) }
    guard let data = (password.stringValue + "\n").data(using: .utf8) else { exit(1) }
    FileHandle.standardOutput.write(data)
    password.stringValue = ""
    exit(0)
}
