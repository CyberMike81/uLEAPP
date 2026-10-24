import AppKit
import SwiftUI

struct LEAPPTool: Identifiable {
    let id: String
    let name: String
    let description: String
    let bundle: String
    var manualDownload: Bool { id == "batch-leapp" }
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
    var sourceLine: String {
        if manualDownload { return description + " · Manual download" }
        if !directVersion.isEmpty { return description + " · Installed by uLEAPP" }
        if existingBundlePath != nil { return description + " · Installed in Applications" }
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
        case "pending": return "Update available"
        case "failed": return "Needs attention"
        case "skipped": return "Not checked"
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
            if discoverManual && version.isEmpty && !(manualDownload && found == "0.0.0") { version = found }
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

enum UpdateMode: String { case check, update, install }

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
    @Published var detailsExpanded = false
    @Published var activeIDs = Set(LEAPPTool.all.map { $0.id })
    let demo: Bool
    let demoMissing: Bool
    private let fetchRelease: (String) throws -> [String: Any]
    private let directStore: DirectMacStore?
    private var buffer = Data()
    private var pendingCarriageReturn = false
    private var pendingLog = ""
    private var logFlush: DispatchWorkItem?
    private var currentMode: UpdateMode = .check
    private var directCancellation: DirectMacCancellation?
    @Published var directProgress = 0.0
    private var logHandle: FileHandle?
    private(set) var logURL: URL?
    var pendingCount: Int { tools.filter { $0.status == "pending" }.count }
    var availableCount: Int { tools.filter { $0.status == "available" }.count }
    var displayedInstalledCount: Int { tools.filter { !$0.version.isEmpty || $0.existingBundlePath != nil }.count }
    var installedCount: Int { tools.filter { !$0.version.isEmpty }.count }
    var missingCount: Int { tools.filter { $0.version.isEmpty && !$0.manualDownload }.count }
    var allInstalledCurrent: Bool { installedCount > 0 && tools.filter { !$0.version.isEmpty }.allSatisfy { $0.status == "current" } }
    var failedCount: Int { tools.filter { $0.status == "failed" }.count }
    var progressTotal: Int { activeIDs.count }
    var completedCount: Int { tools.filter { activeIDs.contains($0.id) && ["installed", "current", "available", "download", "pending", "failed", "skipped", "notInstalled", "unmanaged"].contains($0.status) }.count }
    var progress: Double { (Double(completedCount) + (directCancellation == nil ? 0 : directProgress)) / Double(max(1, progressTotal)) }

    init(demo: Bool = false, demoMissing: Bool = false, directStore: DirectMacStore? = DirectMacStore(), fetchRelease: @escaping (String) throws -> [String: Any] = UpstreamRelease.fetch) {
        self.fetchRelease = fetchRelease
        self.demo = demo; self.demoMissing = demoMissing
        self.directStore = demo ? nil : directStore
        refreshPresentation()
    }
    func refreshPresentation() {
        for index in tools.indices { tools[index].refreshPresentation(store: directStore, discoverManual: true) }
    }
    func selectionForLaunch(_ original: LEAPPTool) throws -> LEAPPTool {
        if let store = directStore { _ = try store.current(original) }
        var selected = original
        selected.version = ""
        selected.refreshPresentation(store: directStore, discoverManual: true)
        return selected
    }
    func launch(_ original: LEAPPTool) {
        guard !busy, !loading, !demo else { return }
        let tool: LEAPPTool
        do { tool = try selectionForLaunch(original) }
        catch { showLaunchError(original, message: error.localizedDescription); return }
        if let index = tools.firstIndex(where: { $0.id == tool.id }) { tools[index] = tool }
        guard let path = tool.existingBundlePath else {
            showLaunchError(tool, message: "The app could not be found in Applications. Refresh your installed apps or install it again.")
            return
        }
        if !tool.directVersion.isEmpty {
            loading = true; stopRequested = false
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let app = URL(fileURLWithPath: path)
                    try DirectMacInstaller.assessPublisher(app)
                    try DirectMacInstaller.quarantine(app)
                    DispatchQueue.main.async {
                        guard let self = self else { return }; self.loading = false
                        if !self.stopRequested { self.openInstalled(tool, path: path) }
                    }
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
        for index in tools.indices { tools[index].version = ""; tools[index].status = "unknown" }
        refreshPresentation()
        if demo {
            for index in tools.indices {
                tools[index].version = demoMissing ? "" : (index == 0 ? "0.15.0" : "2026.4.3")
                tools[index].status = demoMissing ? "notInstalled" : "installed"
            }
            subtitle = "Demo mode — your apps will not change."
            return
        }
        for index in tools.indices {
            do {
                if let store = directStore { _ = try store.current(tools[index]) }
                tools[index].status = tools[index].existingBundlePath == nil ? "notInstalled" : "installed"
            } catch {
                tools[index].status = "failed"
                handleLine(tools[index].name + ": " + error.localizedDescription)
            }
        }
        title = failedCount > 0 ? "A few things need attention" : "Ready for the next LEAPP"
        subtitle = failedCount > 0 ? "Open Details to see what happened." : "\(displayedInstalledCount) of \(tools.count) apps installed. Updates come from the official releases."
        if failedCount > 0 { detailsExpanded = true; flushLog() }
    }
    func start(_ mode: UpdateMode, cask: String? = nil) {
        guard !busy, !loading else { return }
        if !demo { loadInstalled() }
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
        let selected = tools.filter { (cask == nil || $0.id == cask) && (mode == .check || !$0.manualDownload) && (mode != .install || $0.version.isEmpty) && (mode != .update || !$0.version.isEmpty) }
        if demo {
            activeIDs = Set(selected.map { $0.id }); busy = true; stopRequested = false
            title = mode == .check ? "Checking official releases" : "Updating your apps"
            runDemo(mode); return
        }
        if mode == .check { checkDirect(selected) }
        else { updateDirect(selected) }
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
                    tools[index].refreshPresentation(store: directStore, discoverManual: true)
                }
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
        directCancellation?.cancel()
        stopRequested = true
        subtitle = "Stopping safely. Completed installs will be kept."
    }
    func finish(_ status: Int32, launchError: String? = nil) {
        if !buffer.isEmpty { handleLine(String(decoding: buffer, as: UTF8.self)); buffer.removeAll(keepingCapacity: true) }
        pendingCarriageReturn = false; flushLog(); refreshPresentation()
        try? logHandle?.close(); logHandle = nil; busy = false; phase = ""
        if let error = launchError { handleLine(error); flushLog() }
        for index in tools.indices where activeIDs.contains(tools[index].id) && ["waiting", "checking", "updating", "installing"].contains(tools[index].status) { tools[index].status = status == 130 ? "unknown" : "failed" }
        title = status == 130 ? "Stopped safely" : status != 0 || failedCount > 0 ? "A few things need attention" : availableCount + pendingCount > 0 ? "New LEAPP releases are available" : "Checked apps are up to date"
        subtitle = status == 130 ? "Completed installs have been kept." : "Updates come from the official releases."
        if currentMode == .check && status != 130 { lastChecked = Date() }
    }
    func checkDirect(_ selected: [LEAPPTool], preserveLog: Bool = false) {
        guard !busy, !loading, !demo else { return }
        let cancellation = DirectMacCancellation()
        directCancellation = cancellation; directProgress = 0
        activeIDs = Set(selected.map { $0.id })
        busy = true; stopRequested = false
        title = "Checking official Mac releases"
        subtitle = "Checking the publishers’ official releases. No apps are installed by a check."
        flushLog(); if !preserveLog { log = ""; logURL = nil }
        for index in tools.indices where activeIDs.contains(tools[index].id) { tools[index].status = "checking" }
        let fetch = fetchRelease
        let selectedStore = directStore
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for tool in selected {
                if cancellation.isCancelled { break }
                do {
                    if let store = selectedStore { _ = try store.current(tool) }
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
                self.title = cancellation.isCancelled ? "Stopped safely" : self.failedCount > 0 ? "A few things need attention" : self.availableCount > 0 ? "New Mac releases are available" : "Checked apps are up to date"
                self.subtitle = "Choose Update for available releases; Launch opens the selected installed copy."
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
                        alert.informativeText = "The current version and one previous version are kept. Applications copies, untracked folders and modified apps are left alone."
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
        let selectedStore = directStore
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
                    if let store = selectedStore { _ = try store.current(tool) }
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
                        self.tools[index].refreshPresentation(store: self.directStore, discoverManual: true)
                        self.tools[index].status = "current"; self.tools[index].checkedAt = Date(); self.directProgress = 0
                        self.handleLine("\(tool.name) \(installed.version): installed in ~/Applications/uLEAPP. Previous copies preserved.")
                    }
                } catch {
                    if !(error is CancellationError) { failures += 1 }
                    DispatchQueue.main.async {
                        guard let self = self, let index = self.tools.firstIndex(where: { $0.id == tool.id }) else { return }
                        self.tools[index].status = error is CancellationError ? ("available") : "failed"
                        self.handleLine("\(tool.name): \(error is CancellationError ? "Stopped at your request." : error.localizedDescription)")
                        if error is DirectMacInstaller.AppManagementRequired { self.showLaunchError(tool, message: error.localizedDescription, appManagement: true) }
                    }
                    if cancellation.isCancelled { break }
                }
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                for index in self.tools.indices where self.activeIDs.contains(self.tools[index].id) && self.tools[index].status == "waiting" { self.tools[index].status = "available" }
                self.directCancellation = nil; self.directProgress = 0; self.busy = false; self.phase = ""
                self.flushLog(); try? self.logHandle?.close(); self.logHandle = nil
                self.title = cancellation.isCancelled ? "Stopped safely" : (failures > 0 || self.failedCount > 0) ? "A few things need attention" : "Your LEAPP apps are ready"
                self.subtitle = (failures > 0 || self.failedCount > 0) ? "Open Details for the error. Existing apps were preserved." : "Your apps are ready. Launch opens the latest successfully installed copy."
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
