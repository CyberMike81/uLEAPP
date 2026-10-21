import AppKit
import SwiftUI

struct LEAPPTool: Identifiable {
    let id: String
    let name: String
    let description: String
    let bundle: String
    var version = ""
    var status = "unknown"
    static let all: [LEAPPTool] = [
        .init(id: "lava", name: "LAVA", description: "Artifact viewer", bundle: "LAVA"),
        .init(id: "aleapp-gui", name: "ALEAPP", description: "Android artifacts", bundle: "ALEAPP"),
        .init(id: "ileapp-gui", name: "iLEAPP", description: "iOS & iPadOS artifacts", bundle: "iLEAPP"),
        .init(id: "rleapp-gui", name: "RLEAPP", description: "Provider returns", bundle: "RLEAPP"),
        .init(id: "vleapp-gui", name: "VLEAPP", description: "Vehicle artifacts", bundle: "VLEAPP"),
        .init(id: "dleapp-gui", name: "DLEAPP", description: "Desktop artifacts", bundle: "DLEAPP"),
        .init(id: "gleapp", name: "GLEAPP", description: "Image & video triage", bundle: "GLEAPP")
    ]
    var statusLabel: String {
        switch status {
        case "installed": return "Installed"
        case "notInstalled": return "Not installed"
        case "unmanaged": return "Installed manually"
        case "waiting": return "Waiting"
        case "checking": return "Checking"
        case "updating": return "Updating"
        case "installing": return "Installing"
        case "current": return "Up to date"
        case "available": return "Update available"
        case "failed": return "Needs attention"
        case "skipped": return "Not managed by Homebrew"
        default: return "Not checked"
        }
    }
    private(set) var existingBundlePath: String?
    private(set) var icon: NSImage?
    mutating func refreshPresentation() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        existingBundlePath = ["/Applications/\(bundle).app", "\(home)/Applications/\(bundle).app"]
            .first { FileManager.default.fileExists(atPath: $0) }
        if let path = existingBundlePath {
            icon = NSWorkspace.shared.icon(forFile: path)
        } else {
            let iconName = id.replacingOccurrences(of: "-gui", with: "")
            icon = Bundle.main.url(forResource: iconName, withExtension: "png", subdirectory: "tool-icons")
                .flatMap { NSImage(contentsOf: $0) }
        }
    }

}

enum UpdateMode: String { case check, update, install }

final class UpdaterModel: ObservableObject {
    @Published var tools = LEAPPTool.all
    @Published var busy = false
    @Published var loading = false
    @Published var stopRequested = false
    @Published var title = "Ready for the next LEAPP"
    @Published var subtitle = "Check your tools, then update them together."
    @Published var phase = ""
    @Published var log = ""
    @Published var lastChecked = ""
    @Published var brewFound = true
    @Published var detailsExpanded = false
    @Published var activeIDs = Set(LEAPPTool.all.map { $0.id })
    let demo: Bool
    let demoMissing: Bool
    private var buffer = Data()
    private var pendingCarriageReturn = false
    private var pendingLog = ""
    private var logFlush: DispatchWorkItem?
    private let discovery = DiscoveryProcess()
    private var currentMode: UpdateMode = .check
    private var cancelURL: URL?
    private var logHandle: FileHandle?
    private(set) var logURL: URL?
    var availableCount: Int { tools.filter { $0.status == "available" }.count }
    var installedCount: Int { tools.filter { !$0.version.isEmpty }.count }
    var missingCount: Int { tools.filter { $0.version.isEmpty }.count }
    var allInstalledCurrent: Bool { installedCount > 0 && tools.filter { !$0.version.isEmpty }.allSatisfy { $0.status == "current" } }
    var failedCount: Int { tools.filter { $0.status == "failed" }.count }
    var progressTotal: Int { activeIDs.count }
    var completedCount: Int { tools.filter { activeIDs.contains($0.id) && ["installed", "current", "available", "failed", "skipped", "notInstalled", "unmanaged"].contains($0.status) }.count }
    var progress: Double { Double(completedCount) / Double(max(1, progressTotal)) }

    init(demo: Bool = false, demoMissing: Bool = false) {
        self.demo = demo; self.demoMissing = demoMissing
        refreshPresentation()
    }
    func refreshPresentation() {
        for index in tools.indices { tools[index].refreshPresentation() }
    }
    static func brewPath() -> String? {
        let paths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/brew" }
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    func launch(_ tool: LEAPPTool) {
        guard !busy, !loading, !demo else { return }
        guard let path = tool.existingBundlePath else {
            showLaunchError(tool, message: "The app could not be found in Applications. Refresh your installed apps or install it again.")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: configuration) { [weak self] _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.showLaunchError(tool, message: error.localizedDescription)
                }
            }
        }
    }
    private func showLaunchError(_ tool: LEAPPTool, message: String) {
        let alert = NSAlert()
        alert.messageText = "Could not launch \(tool.name)"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    func loadInstalled() {
        guard !busy, !loading else { return }
        refreshPresentation()
        if demo {
            for index in tools.indices {
                tools[index].version = demoMissing ? "" : (index == 0 ? "0.15.0" : "2026.4.3")
                tools[index].status = demoMissing ? "notInstalled" : "installed"
            }
            subtitle = "Demo mode — your apps will not change."
            return
        }
        guard let brew = Self.brewPath() else {
            brewFound = false
            title = "Homebrew is needed"
            subtitle = "Install Homebrew to manage and update your LEAPP apps."
            return
        }
        loading = true
        stopRequested = false
        discovery.reset()
        let discovery = self.discovery
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: brew)
            process.arguments = ["list", "--cask", "--versions"]
            var environment = ProcessInfo.processInfo.environment
            environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
            process.environment = environment
            process.standardOutput = pipe
            process.standardError = pipe
            process.standardInput = FileHandle.nullDevice
            do {
                try discovery.run(process)
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let output = String(decoding: data, as: UTF8.self)
                let succeeded = process.terminationStatus == 0
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.loading = false
                    if self.stopRequested {
                        self.title = "Stopped safely"
                        self.subtitle = "Installed-app discovery was cancelled."
                        return
                    }
                    if succeeded { self.applyInstalled(output) }
                    else {
                        self.title = "Could not read your installed apps"
                        self.subtitle = "Open Details to see Homebrew's message."
                        self.log = output
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.loading = false
                    self?.title = self?.stopRequested == true ? "Stopped safely" : "Could not start Homebrew"
                    self?.subtitle = self?.stopRequested == true ? "Installed-app discovery was cancelled." : error.localizedDescription
                }
            }
        }
    }
    func applyInstalled(_ output: String) {
        refreshPresentation()
        var versions: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            if let first = parts.first {
                versions[String(first).components(separatedBy: "/").last!] = parts.dropFirst().joined(separator: ", ")
            }
        }
        for index in tools.indices {
            tools[index].version = versions[tools[index].id] ?? ""
            tools[index].status = versions[tools[index].id] == nil ? (tools[index].existingBundlePath == nil ? "notInstalled" : "unmanaged") : "installed"
        }
        subtitle = "\(installedCount) of 7 apps managed by Homebrew. Ready to check for updates."
        if installedCount == 0 {
            title = "Your first LEAPP starts here"
            subtitle = "Install an app below, or install the missing apps together."
        }
    }
    func start(_ mode: UpdateMode, cask: String? = nil) {
        guard !busy, !loading else { return }
        if mode == .install && !demo && tools.contains(where: { $0.id == "lava" && $0.version.isEmpty && (cask == nil || cask == "lava") }) {
            let alert = NSAlert()
            alert.messageText = "Install LAVA under its own license?"
            alert.informativeText = "LAVA is freeware from LEAPPs and has its own terms. uLEAPP is MIT licensed. Review LAVA's license before installing it."
            alert.addButton(withTitle: "Install LAVA")
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Read LAVA license")
            let response = alert.runModal()
            if response == .alertThirdButtonReturn {
                NSWorkspace.shared.open(URL(string: "https://github.com/leapps-org/LAVA-releases/blob/main/LICENSE")!)
                return
            }
            guard response == .alertFirstButtonReturn else { return }
        }
        currentMode = mode
        activeIDs = cask.map { Set([$0]) } ?? Set(tools.map { $0.id })
        busy = true
        stopRequested = false
        title = mode == .check ? "Looking for the latest LEAPPs" : (mode == .install ? "Making room for your next LEAPP" : "Keeping your LEAPPs current")
        subtitle = mode == .check ? "Checking all seven tools for new releases." : (mode == .install ? "Installing the requested apps through the official Homebrew tap." : "Please keep your LEAPP apps closed while updating.")
        phase = "Preparing Homebrew"
        flushLog()
        log = ""
        buffer.removeAll(keepingCapacity: true)
        pendingCarriageReturn = false
        for index in tools.indices where activeIDs.contains(tools[index].id) { tools[index].status = "waiting" }
        if demo { runDemo(mode); return }
        guard let worker = Bundle.main.path(forResource: "LEAPP Updater", ofType: "command"),
              let askpass = Bundle.main.path(forResource: "askpass", ofType: "sh") else {
            finish(1, launchError: "The bundled updater is missing. Rebuild or reinstall uLEAPP.")
            return
        }
        do {
            let runID = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-") + "-" + UUID().uuidString.prefix(6)
            let runDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/uLEAPP/\(runID)", isDirectory: true)
            try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
            let outputURL = runDirectory.appendingPathComponent("updater.log")
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            logURL = outputURL
            logHandle = try FileHandle(forWritingTo: outputURL)
            cancelURL = runDirectory.appendingPathComponent("stop-requested")
        } catch { finish(1, launchError: error.localizedDescription); return }
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (environment["PATH"] ?? "")
        environment["ULEAPP_EVENTS"] = "1"
        environment["ULEAPP_CANCEL_FILE"] = cancelURL?.path
        environment["SUDO_ASKPASS"] = askpass
        environment["HOMEBREW_NO_COLOR"] = "1"
        let arguments: [String]
        if mode == .check { arguments = [worker, "--check"] }
        else if mode == .install { arguments = cask.map { [worker, "--install", $0] } ?? [worker, "--install-missing"] }
        else { arguments = [worker] }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = arguments
            process.environment = environment
            process.standardOutput = pipe
            process.standardError = pipe
            process.standardInput = FileHandle.nullDevice
            do {
                try process.run()
                while true {
                    let data = pipe.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    DispatchQueue.main.async { self?.receive(data) }
                }
                process.waitUntilExit()
                let status = process.terminationStatus
                DispatchQueue.main.async { self?.finish(status) }
            } catch {
                DispatchQueue.main.async { self?.finish(1, launchError: error.localizedDescription) }
            }
        }
    }
    func receive(_ data: Data) {
        // Preserve partial UTF-8 and CRLF across reads. A bare CR replaces the
        // current progress line instead of adding thousands of log entries.
        for byte in data {
            if pendingCarriageReturn {
                pendingCarriageReturn = false
                if byte != 10 { buffer.removeAll(keepingCapacity: true) }
            }
            if byte == 13 { pendingCarriageReturn = true }
            else if byte == 10 {
                handleLine(String(decoding: buffer, as: UTF8.self))
                buffer.removeAll(keepingCapacity: true)
            } else {
                buffer.append(byte)
                if buffer.count > 100_000 { buffer.removeFirst(buffer.count - 100_000) }
            }
        }
    }
    func flushLog() {
        logFlush?.cancel()
        logFlush = nil
        guard !pendingLog.isEmpty else { return }
        log = String((log + pendingLog).suffix(100_000))
        pendingLog = ""
    }
    func handleLine(_ line: String) {
        let fields = line.components(separatedBy: "\t")
        if fields.count >= 5 && fields[0] == "ULEAPP" {
            if fields[1] == "phase" { phase = fields[4] }
            if let index = tools.firstIndex(where: { $0.id == fields[2] }) {
                if fields[1] == "version" {
                    tools[index].version = fields[4]
                    tools[index].refreshPresentation()
                }
                if fields[1] == "app" {
                    tools[index].status = fields[3]
                    if fields[3] == "skipped" && tools[index].version.isEmpty {
                        tools[index].status = tools[index].existingBundlePath == nil ? "notInstalled" : "unmanaged"
                    }
                    if fields[3] == "checking" { phase = "Checking \(tools[index].name)" }
                    if fields[3] == "updating" { phase = "Updating \(tools[index].name)" }
                    if fields[3] == "installing" { phase = "Installing \(tools[index].name)" }
                }
            }
        } else {
            let entry = line + "\n"
            pendingLog += entry
            if pendingLog.count > 100_000 { pendingLog = String(pendingLog.suffix(100_000)) }
            if logFlush == nil {
                let work = DispatchWorkItem { [weak self] in self?.flushLog() }
                logFlush = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
            }
            if let bytes = entry.data(using: .utf8) { try? logHandle?.write(contentsOf: bytes) }
        }
    }
    func requestStop() {
        guard (busy || loading), !stopRequested else { return }
        if loading {
            stopRequested = true
            discovery.cancel()
            subtitle = "Stopping installed-app discovery."
            return
        }
        if demo { stopRequested = true; subtitle = "Will stop after the current app finishes."; return }
        guard let url = cancelURL else { return }
        do {
            try Data().write(to: url)
            stopRequested = true
            subtitle = "Will stop after the current operation finishes."
        } catch { log += "Could not request a stop: \(error.localizedDescription)\n" }
    }
    func finish(_ status: Int32, launchError: String? = nil) {
        if !buffer.isEmpty {
            handleLine(String(decoding: buffer, as: UTF8.self))
            buffer.removeAll(keepingCapacity: true)
        }
        pendingCarriageReturn = false
        flushLog()
        refreshPresentation()
        try? logHandle?.close()
        logHandle = nil
        busy = false
        phase = ""
        if let error = launchError { log += error + "\n" }
        let unfinished = tools.indices.filter { activeIDs.contains(tools[$0].id) && ["waiting", "checking", "updating", "installing"].contains(tools[$0].status) }
        for index in unfinished { tools[index].status = status == 130 ? "unknown" : "failed" }
        if status == 130 {
            title = "Stopped safely"
            subtitle = "Completed updates have been kept. You can continue whenever you're ready."
        } else if status != 0 || failedCount > 0 {
            title = "A few things need attention"
            subtitle = "Open Details to see what happened, then try again."
        } else if currentMode == .install {
            title = "Your LEAPP apps are ready"
            subtitle = "Installation finished. You can check for updates whenever you're ready."
        } else if installedCount == 0 {
            title = "No LEAPP apps managed by Homebrew"
            subtitle = "Install or register your apps with Homebrew first."
        } else if currentMode == .check && availableCount > 0 {
            title = "\(availableCount) \(availableCount == 1 ? "update is" : "updates are") ready"
            subtitle = "Close your LEAPP apps, then choose Update apps."
            lastChecked = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        } else {
            title = "You're all up to date"
            subtitle = "Your installed LEAPP apps are ready for the next case."
            lastChecked = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        }
    }
    private func runDemo(_ mode: UpdateMode, index: Int = 0) {
        if index == tools.count || stopRequested { finish(stopRequested ? 130 : 0); return }
        if !activeIDs.contains(tools[index].id) { runDemo(mode, index: index + 1); return }
        tools[index].status = mode == .check ? "checking" : (mode == .install ? "installing" : "updating")
        phase = "\(mode == .check ? "Checking" : "Updating") \(tools[index].name)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }
            self.tools[index].status = mode == .check && index < 2 ? "available" : "current"
            if mode == .install { self.tools[index].version = index == 0 ? "0.15.0" : "2026.4.3" }
            self.log += "\(self.tools[index].name): \(self.tools[index].statusLabel) (demo)\n"
            self.runDemo(mode, index: index + 1)
        }
    }
}

// Cancellation is restricted to read-only discovery. Homebrew installations
// continue to a safe boundary through the worker's cancellation file.
final class DiscoveryProcess {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private var deadline: DispatchWorkItem?
    func reset() {
        lock.lock(); defer { lock.unlock() }
        deadline?.cancel(); deadline = nil
        cancelled = false; process = nil
    }
    func run(_ value: Process) throws {
        lock.lock(); defer { lock.unlock() }
        if cancelled { throw CocoaError(.userCancelled) }
        try value.run()
        process = value
        let timeout = DispatchWorkItem { [weak self, weak value] in
            guard let self = self, let value = value else { return }
            self.lock.lock(); defer { self.lock.unlock() }
            if self.process === value, value.isRunning { value.terminate() }
        }
        deadline = timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: timeout)
    }
    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        if let process = process, process.isRunning { process.terminate() }
    }
}
