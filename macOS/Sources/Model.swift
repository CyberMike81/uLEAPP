import AppKit
import SwiftUI

struct LEAPPTool: Identifiable {
    let id: String
    let name: String
    let description: String
    let bundle: String
    var directOnly: Bool { id == "batch-leapp" || id == "mapdownloader" }
    var manualDownload: Bool { id == "batch-leapp" }
    var homebrewVersion = ""
    var applicationVersion = ""
    var directVersion = ""
    var upstreamVersion = ""
    var version = ""
    var status = "unknown"
    var checkedAt: Date?
    static func friendlyTime(_ date: Date) -> String {
        let time = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        return Calendar.current.isDateInToday(date) ? "today, " + time : DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
    var pillLabel: String {
        if manualDownload && !["failed", "checking", "waiting"].contains(status) { return existingBundlePath == nil ? "Manual download" : "Installed by you" }
        switch status {
        case "current": return "Up to date" + (version.isEmpty ? "" : " · " + version)
        case "available", "pending":
            if version.isEmpty { return upstreamVersion.isEmpty ? "Available" : "Available · " + upstreamVersion }
            return upstreamVersion.isEmpty ? "Update available" : "Update " + version + " → " + upstreamVersion
        case "installed": return "Installed" + (version.isEmpty ? "" : " · " + version)
        case "unmanaged": return "Installed by you"
        default: return statusLabel
        }
    }
    var statusHelp: String {
        let evidence = checkedAt.map { "Checked against GitHub " + Self.friendlyTime($0) + "." } ?? "Not checked against GitHub in this session."
        return status == "failed" ? "Open Details for the error. Last successful check: " + evidence : evidence
    }
    private func atLeastDirect(_ version: String) -> Bool {
        guard !directVersion.isEmpty, !version.isEmpty else { return false }
        return (try? !UpstreamRelease.assess(["tag_name": directVersion, "draft": false, "prerelease": false], installed: version).1) ?? false
    }
    var canReturnToHomebrew: Bool { !directOnly && atLeastDirect(homebrewVersion) && atLeastDirect(applicationVersion) }
    var returnHomebrewHelp: String {
        if canReturnToHomebrew { return "Use the verified Homebrew copy in Applications; uLEAPP copies are kept." }
        if !atLeastDirect(homebrewVersion) { return "Homebrew’s installed version must reach " + directVersion + " before switching." }
        return "The Homebrew app in Applications must reach " + directVersion + " before switching."
    }
    func sourceLine(usesHomebrew: Bool) -> String {
        if manualDownload { return description + " · Publisher offers a manual download only; macOS may ask before first launch." }
        if !directVersion.isEmpty {
            var text = description + " · Launch opens uLEAPP’s copy " + directVersion
            if !homebrewVersion.isEmpty && !applicationVersion.isEmpty {
                let sameVersion = (try? UpstreamRelease.parts(applicationVersion) == UpstreamRelease.parts(homebrewVersion)) ?? false
                text += sameVersion ? " (Homebrew copy " + applicationVersion + " in Applications)" : " (Applications copy " + applicationVersion + "; Homebrew installed " + homebrewVersion + ")"
            }
            return text
        }
        if !homebrewVersion.isEmpty && usesHomebrew { return description + " · Managed by Homebrew" }
        if existingBundlePath != nil { return description + " · Installed by you" }
        return description
    }
    static let all: [LEAPPTool] = [
        .init(id: "lava", name: "LAVA", description: "Artifact viewer", bundle: "LAVA"),
        .init(id: "aleapp-gui", name: "ALEAPP", description: "Android artifacts", bundle: "ALEAPP"),
        .init(id: "ileapp-gui", name: "iLEAPP", description: "iOS & iPadOS artifacts", bundle: "iLEAPP"),
        .init(id: "rleapp-gui", name: "RLEAPP", description: "Provider returns", bundle: "RLEAPP"),
        .init(id: "vleapp-gui", name: "VLEAPP", description: "Vehicle artifacts", bundle: "VLEAPP"),
        .init(id: "dleapp-gui", name: "DLEAPP", description: "Desktop artifacts", bundle: "DLEAPP"),
        .init(id: "gleapp", name: "GLEAPP", description: "Image & video triage", bundle: "GLEAPP"),
        .init(id: "mapdownloader", name: "Map Downloader", description: "Offline maps for GLEAPP", bundle: "GLEAPP Map Downloader")
    ] + (DirectMacInstaller.architecture == "arm64" ? [.init(id: "batch-leapp", name: "Batch LEAPP", description: "Run LEAPPs across extractions", bundle: "Batch LEAPP")] : [])
    var statusLabel: String {
        switch status {
        case "download": return "Manual download"
        case "installed": return "Installed"
        case "notInstalled": return "Not installed"
        case "unmanaged": return "Installed manually"
        case "waiting": return "Waiting"
        case "checking": return "Checking"
        case "updating": return "Updating"
        case "installing": return "Installing"
        case "current": return "Up to date"
        case "available": return "Update available"
        case "pending": return "Homebrew update pending"
        case "failed": return "Needs attention"
        case "skipped": return "Not managed by Homebrew"
        default: return "Not checked"
        }
    }
    private(set) var existingBundlePath: String?
    private(set) var icon: NSImage?
    mutating func refreshPresentation(store: DirectMacStore? = DirectMacStore(), discoverManual: Bool = false, applicationPaths: [String]? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        existingBundlePath = (applicationPaths ?? ["/Applications/\(bundle).app", "\(home)/Applications/\(bundle).app"])
            .first { FileManager.default.fileExists(atPath: $0) }
        applicationVersion = ""
        if store != nil, let path = existingBundlePath,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path).appendingPathComponent("Contents/Info.plist")),
           let info = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
           let found = info["CFBundleShortVersionString"] as? String {
            applicationVersion = found
            if (discoverManual || directOnly) && version.isEmpty && !(manualDownload && found == "0.0.0") { version = found }
        }
        directVersion = ""
        if let store = store, let direct = try? store.current(self) {
            existingBundlePath = direct.1.path
            directVersion = direct.0.version
            version = direct.0.version
        }
        if let path = existingBundlePath {
            icon = NSWorkspace.shared.icon(forFile: path)
        } else {
            let iconName = id.replacingOccurrences(of: "-gui", with: "")
            icon = Bundle.main.url(forResource: iconName, withExtension: "png", subdirectory: "tool-icons")
                .flatMap { NSImage(contentsOf: $0) }
        }
    }

}

enum UpdateMode: String { case check, update, install, returnHomebrew }

final class UpdaterModel: ObservableObject {
    @Published var appUpdate: AppUpdate?
    private var selfUpdateTimer: Timer?
    private var selfUpdateStarted = false
    let updatePreferenceEnabled = !CommandLine.arguments.contains("--no-update-check")
    @Published var automaticUpdates = !CommandLine.arguments.contains("--no-update-check") && (UserDefaults.standard.object(forKey: "AutomaticUpdateChecks") == nil || UserDefaults.standard.bool(forKey: "AutomaticUpdateChecks"))
    func setAutomaticUpdates(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "AutomaticUpdateChecks")
        automaticUpdates = enabled && updatePreferenceEnabled
        if automaticUpdates { startSelfUpdateChecks() }
        else { selfUpdateTimer?.invalidate(); selfUpdateTimer = nil; selfUpdateStarted = false; appUpdate = nil }
    }
    func startSelfUpdateChecks() {
        guard !demo, automaticUpdates, !selfUpdateStarted else { return }
        selfUpdateStarted = true
        checkSelfUpdate()
        selfUpdateTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in self?.checkSelfUpdate() }
    }
    private func checkSelfUpdate() {
        guard automaticUpdates, !demo else { return }
        SelfUpdate.check(completion: { [weak self] update in
            DispatchQueue.main.async { if self?.automaticUpdates == true, let update = update { self?.appUpdate = update } }
        }, failure: { [weak self] message in
            DispatchQueue.main.async { if self?.automaticUpdates == true { self?.handleLine("uLEAPP update check: " + message); self?.flushLog() } }
        })
    }
    @Published var tools = LEAPPTool.all
    @Published var busy = false
    @Published var loading = false
    @Published var stopRequested = false
    @Published var title = "Ready for the next LEAPP"
    @Published var subtitle = "Check your tools, then update them together."
    @Published var phase = ""
    @Published var log = ""
    @Published var settingsExpanded = false
    @Published var lastChecked: Date?
    @Published var brewFound = true
    @Published var useHomebrew = UserDefaults.standard.object(forKey: "UseHomebrew") == nil || UserDefaults.standard.bool(forKey: "UseHomebrew")
    let homebrewPreferenceEnabled = !CommandLine.arguments.contains("--no-homebrew")
    private let brewResolver: () -> String?
    private let fetchRelease: (String) throws -> [String: Any]
    var usesHomebrew: Bool { brewFound && useHomebrew && homebrewPreferenceEnabled }
    func setUseHomebrew(_ enabled: Bool) {
        guard !busy, !loading else { return }
        useHomebrew = enabled
        UserDefaults.standard.set(enabled, forKey: "UseHomebrew")
        loadInstalled()
    }
    @Published var detailsExpanded = false
    @Published var activeIDs = Set(LEAPPTool.all.map { $0.id })
    let demo: Bool
    let demoMissing: Bool
    private let directStore: DirectMacStore?
    private var buffer = Data()
    private var pendingCarriageReturn = false
    private var pendingLog = ""
    private var logFlush: DispatchWorkItem?
    private let discovery = DiscoveryProcess()
    private var currentMode: UpdateMode = .check
    private var directCancellation: DirectMacCancellation?
    @Published var directProgress = 0.0
    private var cancelURL: URL?
    private var logHandle: FileHandle?
    private(set) var logURL: URL?
    var pendingCount: Int { tools.filter { $0.status == "pending" }.count }
    var availableCount: Int { tools.filter { $0.status == "available" }.count }
    var installedCount: Int { tools.filter { !$0.version.isEmpty }.count }
    var missingCount: Int { tools.filter { $0.version.isEmpty && !$0.manualDownload }.count }
    var allInstalledCurrent: Bool { installedCount > 0 && tools.filter { !$0.version.isEmpty }.allSatisfy { $0.status == "current" } }
    var failedCount: Int { tools.filter { $0.status == "failed" }.count }
    var progressTotal: Int { activeIDs.count }
    var completedCount: Int { tools.filter { activeIDs.contains($0.id) && ["installed", "current", "available", "download", "pending", "failed", "skipped", "notInstalled", "unmanaged"].contains($0.status) }.count }
    var progress: Double { (Double(completedCount) + (directCancellation == nil ? 0 : directProgress)) / Double(max(1, progressTotal)) }

    init(demo: Bool = false, demoMissing: Bool = false, directStore: DirectMacStore? = DirectMacStore(), brewResolver: @escaping () -> String? = UpdaterModel.brewPath, fetchRelease: @escaping (String) throws -> [String: Any] = UpstreamRelease.fetch) {
        self.fetchRelease = fetchRelease
        self.brewResolver = brewResolver
        self.demo = demo; self.demoMissing = demoMissing
        self.directStore = demo ? nil : directStore
        self.brewFound = brewResolver() != nil
        refreshPresentation()
    }
    func refreshPresentation() {
        for index in tools.indices { tools[index].refreshPresentation(store: directStore, discoverManual: !usesHomebrew) }
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
        if !tool.directVersion.isEmpty {
            loading = true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let app = URL(fileURLWithPath: path)
                    try DirectMacInstaller.assessPublisher(app)
                    try DirectMacInstaller.quarantine(app)
                    DispatchQueue.main.async { self?.loading = false; self?.openInstalled(tool, path: path) }
                } catch { DispatchQueue.main.async { self?.loading = false; self?.showLaunchError(tool, message: error.localizedDescription, appManagement: error is DirectMacInstaller.AppManagementRequired) } }
            }
            return
        }
        openInstalled(tool, path: path)
    }
    private func openInstalled(_ tool: LEAPPTool, path: String) {
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
    private func showLaunchError(_ tool: LEAPPTool, message: String, appManagement: Bool = false) {
        let alert = NSAlert()
        alert.messageText = "Could not launch \(tool.name)"
        alert.informativeText = message
        if appManagement {
            alert.messageText = "Allow uLEAPP to manage apps"
            alert.informativeText = message + "\n\nThe publisher and Gatekeeper checks passed for " + tool.name + ". After changing the setting, try Launch again; macOS may require reopening uLEAPP."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
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
        brewFound = brewResolver() != nil
        guard usesHomebrew, let brew = brewResolver() else {
            applyInstalled("")
            title = "Ready for direct Mac updates"
            subtitle = "Install and update official Mac builds directly. Homebrew is optional."
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
            tools[index].homebrewVersion = versions[tools[index].id] ?? ""
            tools[index].version = versions[tools[index].id] ?? ""
            tools[index].status = versions[tools[index].id] == nil ? (tools[index].existingBundlePath == nil ? "notInstalled" : "unmanaged") : "installed"
        }
        refreshPresentation()
        for index in tools.indices where !tools[index].version.isEmpty { tools[index].status = "installed" }
        subtitle = "\(installedCount) of \(tools.count) apps installed. Ready to check for updates."
        if installedCount == 0 {
            title = "Your first LEAPP starts here"
            subtitle = "Install an app below, or install the missing apps together."
        }
    }
    private var queuedCompanions: [LEAPPTool] = []
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
        if (!usesHomebrew || tools.contains { $0.id == cask && $0.directOnly }) && !demo {
            if mode == .returnHomebrew {
                title = "Homebrew is optional"
                subtitle = "Enable Homebrew management to return a direct copy to Homebrew."
                return
            }
            let selected = tools.filter { (cask == nil || $0.id == cask) && (mode != .install || $0.version.isEmpty) && (mode != .update || !$0.version.isEmpty) }
            if mode == .check { checkDirect(selected) }
            else { updateDirect(selected) }
            return
        }
        queuedCompanions = mode == .returnHomebrew ? [] : tools.filter { $0.directOnly && (cask == nil || $0.id == cask) && (mode != .install || $0.version.isEmpty) && (mode != .update || !$0.version.isEmpty) }
        currentMode = mode
        activeIDs = cask.map { Set([$0]) } ?? Set(tools.filter { !$0.directOnly }.map { $0.id })
        busy = true
        stopRequested = false
        title = mode == .check ? "Looking for the latest LEAPPs" : (mode == .install ? "Making room for your next LEAPP" : "Keeping your LEAPPs current")
        subtitle = mode == .check ? "Checking supported tools for new releases." : (mode == .install ? "Installing the requested apps through the official Homebrew tap." : "Please keep your LEAPP apps closed while updating.")
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
        environment["ULEAPP_RELEASE_CHECKER"] = Bundle.main.executableURL?.path
        environment["ULEAPP_CANCEL_FILE"] = cancelURL?.path
        environment["SUDO_ASKPASS"] = askpass
        environment["HOMEBREW_NO_COLOR"] = "1"
        let arguments: [String]
        if mode == .returnHomebrew, let cask = cask { arguments = [worker, "--return-to-homebrew", cask] }
        else if mode == .check { arguments = [worker, "--check"] }
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
                    tools[index].refreshPresentation(store: directStore, discoverManual: !usesHomebrew)
                }
                if fields[1] == "homebrew" { tools[index].homebrewVersion = fields[4] }
                if fields[1] == "upstream" { tools[index].upstreamVersion = fields[4]; tools[index].checkedAt = Date() }
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
        if let directCancellation = directCancellation {
            directCancellation.cancel()
            stopRequested = true
            subtitle = "Stopping safely."
            return
        }
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
        if currentMode == .check && status != 130 { lastChecked = Date() }
        let companions = queuedCompanions; queuedCompanions = []
        if status != 130 && !demo && (currentMode == .check || currentMode == .install || currentMode == .update) {
            let direct = (currentMode == .update ? tools.filter { $0.status == "pending" } : []) + companions
            if !direct.isEmpty {
                if currentMode == .check { checkDirect(direct, preserveLog: true) } else { updateDirect(direct) }
                return
            }
        }
        if status == 130 {
            title = "Stopped safely"
            subtitle = "Completed updates have been kept. You can continue whenever you're ready."
        } else if status != 0 || failedCount > 0 {
            title = "A few things need attention"
            subtitle = "Open Details to see what happened, then try again."
        } else if currentMode == .returnHomebrew {
            title = "Homebrew management restored"
            subtitle = "Launch uses the Homebrew copy in Applications. Direct app folders were retained."
        } else if currentMode == .install {
            title = "Your LEAPP apps are ready"
            subtitle = "Installation finished. You can check for updates whenever you're ready."
        } else if installedCount == 0 {
            title = "No LEAPP apps installed"
            subtitle = "Choose Install to add a tool."
        } else if pendingCount > 0 {
            title = "New LEAPP releases are available"
            subtitle = "\(pendingCount) awaiting Homebrew. Choose Update to install the official Mac downloads. \(availableCount) other updates can be installed through Homebrew."
            lastChecked = Date()
        } else if currentMode == .check && availableCount > 0 {
            title = "\(availableCount) \(availableCount == 1 ? "update is" : "updates are") ready"
            subtitle = "Close your LEAPP apps, then choose Update apps."
            lastChecked = Date()
        } else {
            title = "You're all up to date"
            subtitle = "Your installed LEAPP apps are ready for the next case."
            lastChecked = Date()
        }
    }
    func checkDirect(_ selected: [LEAPPTool], preserveLog: Bool = false) {
        guard !busy, !loading, !demo else { return }
        let cancellation = DirectMacCancellation()
        directCancellation = cancellation; directProgress = 0
        activeIDs = Set(selected.map { $0.id })
        busy = true; stopRequested = false
        title = "Checking official Mac releases"
        subtitle = "Homebrew is optional; checking does not install apps."
        flushLog(); if !preserveLog { log = ""; logURL = nil }
        for index in tools.indices where activeIDs.contains(tools[index].id) { tools[index].status = "checking" }
        let fetch = fetchRelease
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for tool in selected {
                if cancellation.isCancelled { break }
                do {
                    let metadata = try fetch(tool.id)
                    try cancellation.check()
                    let release = try DirectMacInstaller.select(metadata, tool: tool, architecture: DirectMacInstaller.architecture)
                    let update = try tool.version.isEmpty || UpstreamRelease.assess(metadata, installed: tool.version).1
                    DispatchQueue.main.async {
                        guard let self = self, let index = self.tools.firstIndex(where: { $0.id == tool.id }) else { return }
                        self.tools[index].upstreamVersion = release.version
                        self.tools[index].checkedAt = Date()
                        self.tools[index].status = tool.manualDownload ? "download" : update ? "available" : "current"
                        self.handleLine("\(tool.name): installed \(tool.version.isEmpty ? "none" : tool.version), latest \(release.version).")
                    }
                } catch {
                    DispatchQueue.main.async {
                        guard let self = self, let index = self.tools.firstIndex(where: { $0.id == tool.id }) else { return }
                        self.tools[index].status = error is CancellationError ? "unknown" : "failed"
                        self.handleLine("\(tool.name): " + error.localizedDescription)
                    }
                }
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                for index in self.tools.indices where self.activeIDs.contains(self.tools[index].id) && self.tools[index].status == "checking" { self.tools[index].status = "unknown" }
                self.directCancellation = nil; self.busy = false; self.phase = ""; self.flushLog()
                self.title = cancellation.isCancelled ? "Stopped safely" : self.failedCount > 0 ? "A few things need attention" : self.availableCount > 0 ? "New Mac releases are available" : "You're all up to date"
                self.subtitle = "Choose Install or Update to use the official Mac download."
                self.lastChecked = Date()
            }
        }
    }
    func downloadCompanion(_ tool: LEAPPTool) {
        guard !busy, !loading, !demo else { return }
        loading = true
        let fetch = fetchRelease
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let release = try DirectMacInstaller.select(fetch(tool.id), tool: tool, architecture: DirectMacInstaller.architecture)
                DispatchQueue.main.async {
                    self?.loading = false
                    self?.title = "Download opened in your browser"
                    self?.subtitle = "Batch LEAPP requires manual installation. Its current Mac build is not notarized; uLEAPP does not bypass macOS security checks."
                    NSWorkspace.shared.open(release.url)
                }
            } catch { DispatchQueue.main.async { self?.loading = false; self?.showLaunchError(tool, message: error.localizedDescription) } }
        }
    }
    func removeOldInstalls() {
        guard !busy, !loading, !demo else { return }
        let cancellation = DirectMacCancellation()
        directCancellation = cancellation; busy = true; stopRequested = false
        let snapshots = tools
        phase = "Finding old uLEAPP-managed installs"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let candidates = try DirectMacStore().oldInstalls(snapshots, cancellation: cancellation)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.busy = false; self.directCancellation = nil; self.phase = ""
                    if cancellation.isCancelled { return }
                    let alert = NSAlert()
                    if candidates.isEmpty {
                        alert.messageText = "No old installs to remove"
                        alert.informativeText = "The current version and one previous version are kept. Homebrew copies, untracked folders and modified apps are left alone."
                        alert.addButton(withTitle: "OK"); alert.runModal(); return
                    }
                    alert.messageText = "Move \(candidates.count) old installs to Trash?"
                    alert.informativeText = "The current version and one previous version of each app will be kept.\n\n" + candidates.map { $0.label }.joined(separator: "\n")
                    alert.addButton(withTitle: "Move to Trash"); alert.addButton(withTitle: "Cancel")
                    guard alert.runModal() == .alertFirstButtonReturn else { return }
                    self.busy = true; self.stopRequested = true; self.phase = "Moving old installs to Trash"
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            // Re-read current records and app contents after the confirmation.
                            let fresh = try DirectMacStore().oldInstalls(snapshots, cancellation: DirectMacCancellation())
                            let proposed = Set(candidates.map { $0.folder })
                            let safe = fresh.filter { proposed.contains($0.folder) }.map { $0.folder }
                            NSWorkspace.shared.recycle(safe) { moved, error in
                                DispatchQueue.main.async {
                                    self.busy = false; self.stopRequested = false; self.phase = ""
                                    self.title = error == nil ? "Old installs removed" : "Some installs could not be moved"
                                    self.subtitle = error?.localizedDescription ?? "\(moved.count) older versions moved to Trash. Current and previous versions kept."
                                    self.handleLine(self.subtitle); self.flushLog()
                                }
                            }
                        } catch {
                            DispatchQueue.main.async { self.busy = false; self.stopRequested = false; self.phase = ""; self.title = "Could not remove old installs"; self.subtitle = error.localizedDescription }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.busy = false; self?.directCancellation = nil; self?.phase = ""
                    if !(error is CancellationError) { self?.title = "Could not check old installs"; self?.subtitle = error.localizedDescription }
                }
            }
        }
    }
    func updateDirect(_ selected: [LEAPPTool]) {
        guard !busy, !loading, !demo, !selected.isEmpty else { return }
        let cancellation = DirectMacCancellation()
        directCancellation = cancellation
        directProgress = 0
        activeIDs = Set(selected.map { $0.id })
        busy = true; stopRequested = false
        title = "Installing the latest Mac releases"
        subtitle = "Downloading verified packages. Keep your LEAPP apps closed."
        for index in tools.indices where activeIDs.contains(tools[index].id) { tools[index].status = "waiting" }
        do {
            let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/uLEAPP/Direct-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("updater.log")
            try Data(log.utf8).write(to: url)
            logURL = url; logHandle = try FileHandle(forWritingTo: url); try logHandle?.seekToEnd()
        } catch {
            directCancellation = nil; busy = false; title = "Could not start the update"
            subtitle = error.localizedDescription; return
        }
        let fetch = fetchRelease
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var failures = 0
            for tool in selected {
                if cancellation.isCancelled { break }
                if tool.manualDownload {
                    DispatchQueue.main.async {
                        if let self = self, let index = self.tools.firstIndex(where: { $0.id == tool.id }) { self.tools[index].status = "download" }
                        self?.handleLine("Batch LEAPP requires its Download button and manual installation; macOS security checks remain in place.") }
                    continue
                }
                DispatchQueue.main.async {
                    guard let self = self, let index = self.tools.firstIndex(where: { $0.id == tool.id }) else { return }
                    self.tools[index].status = "updating"; self.directProgress = 0
                }
                do {
                    let metadata = try fetch(tool.id)
                    try cancellation.check()
                    _ = try DirectMacInstaller.select(metadata, tool: tool, architecture: DirectMacInstaller.architecture)
                    if try !tool.version.isEmpty && !UpstreamRelease.assess(metadata, installed: tool.version).1 {
                        DispatchQueue.main.async {
                            guard let self = self, let index = self.tools.firstIndex(where: { $0.id == tool.id }) else { return }
                            self.tools[index].status = "current"; self.tools[index].checkedAt = Date(); self.directProgress = 0
                            self.handleLine("\(tool.name): already current; no files were changed.")
                        }
                        continue
                    }
                    let installed = try DirectMacInstaller().install(tool, cancellation: cancellation, metadata: metadata, phase: { message in
                        DispatchQueue.main.async { self?.phase = message }
                    }, progress: { fraction in
                        DispatchQueue.main.async { self?.directProgress = fraction * 0.9 }
                    })
                    DispatchQueue.main.async {
                        guard let self = self, let index = self.tools.firstIndex(where: { $0.id == tool.id }) else { return }
                        self.tools[index].version = installed.version
                        self.tools[index].refreshPresentation(store: self.directStore, discoverManual: !self.usesHomebrew)
                        self.tools[index].status = "current"; self.tools[index].checkedAt = Date(); self.directProgress = 0
                        self.handleLine("\(tool.name) \(installed.version): installed in ~/Applications/uLEAPP. Previous copies preserved.")
                    }
                } catch {
                    if !(error is CancellationError) { failures += 1 }
                    DispatchQueue.main.async {
                        guard let self = self, let index = self.tools.firstIndex(where: { $0.id == tool.id }) else { return }
                        self.tools[index].status = error is CancellationError ? (self.usesHomebrew ? "pending" : "available") : "failed"
                        self.handleLine("\(tool.name): \(error is CancellationError ? "Stopped at your request." : error.localizedDescription)")
                        if error is DirectMacInstaller.AppManagementRequired { self.showLaunchError(tool, message: error.localizedDescription, appManagement: true) }
                    }
                    if cancellation.isCancelled { break }
                }
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                for index in self.tools.indices where self.activeIDs.contains(self.tools[index].id) && self.tools[index].status == "waiting" { self.tools[index].status = self.usesHomebrew ? "pending" : "available" }
                self.directCancellation = nil; self.directProgress = 0; self.busy = false; self.phase = ""
                self.flushLog(); try? self.logHandle?.close(); self.logHandle = nil
                self.title = cancellation.isCancelled ? "Stopped safely" : (failures > 0 || self.failedCount > 0) ? "A few things need attention" : "Your LEAPP apps are ready"
                self.subtitle = (failures > 0 || self.failedCount > 0) ? "Open Details for the error. Existing apps were preserved." : "Direct installs use ~/Applications/uLEAPP. Launch opens the selected version."
                self.lastChecked = Date()
            }
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
