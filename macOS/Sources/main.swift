import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: 1)
    }
}
enum Palette {
    static let background = Color(hex: 0x111712)
    static let card = Color(hex: 0x1C241E)
    static let border = Color.white.opacity(0.08)
    static let green = Color(hex: 0x8EE563)
    static let pink = Color(hex: 0xFA3B6A)
    static let orange = Color(hex: 0xFF9C38)
    static let muted = Color(hex: 0xA7B4AB)
}
struct ActionStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 17).padding(.vertical, 11)
            .foregroundStyle(primary ? Color(hex: 0x15210F) : Color.white)
            .background(primary ? Palette.green : Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }
}
struct ToolRow: View {
    let tool: LEAPPTool
    let actionsDisabled: Bool
    let launchDisabled: Bool
    let launch: () -> Void
    let install: () -> Void
    let directUpdate: () -> Void
    var stateColor: Color {
        switch tool.status {
        case "current": return Palette.green
        case "available", "pending": return Palette.orange
        case "failed": return Palette.pink
        case "checking", "updating", "installing": return Palette.green
        default: return Palette.muted
        }
    }
    var body: some View {
        HStack(spacing: 12) {
            if let icon = tool.icon {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: 32, height: 32).accessibilityHidden(true)
            } else {
                Image(systemName: "app.dashed").font(.system(size: 24)).foregroundStyle(Palette.muted).frame(width: 32, height: 32).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(tool.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text(tool.sourceLine)
                    .font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                    .help(tool.sourceLine)
            }
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                if ["checking", "updating", "installing"].contains(tool.status) { ProgressView().controlSize(.mini).frame(width: 12, height: 12) }
                Text(tool.pillLabel).font(.system(size: 10, weight: .medium))
            }.foregroundStyle(stateColor).padding(.horizontal, 8).padding(.vertical, 5)
                .background(stateColor.opacity(0.09)).clipShape(Capsule()).help(tool.statusHelp)
            if !tool.manualDownload && ["pending", "available"].contains(tool.status) && !tool.version.isEmpty {
                Button("Update") { directUpdate() }.controlSize(.small).tint(Palette.green).disabled(actionsDisabled)
            }
            if tool.manualDownload {
                Button("Get latest") { install() }.controlSize(.small).disabled(actionsDisabled)
            } else if tool.version.isEmpty {
                Button("Install") { install() }
                    .controlSize(.small).tint(Palette.green).disabled(actionsDisabled)
                    .help("Download and install the official Mac release")
            }
            if tool.existingBundlePath != nil {
                Button("Launch") { launch() }.controlSize(.small).tint(Palette.green).disabled(launchDisabled)
                    .help("Open \(tool.name)").accessibilityLabel("Launch \(tool.name)")
            }
            Menu {
                if let path = tool.existingBundlePath {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
                }
                if let repository = UpstreamRelease.repositories[tool.id] {
                    Link("Release notes", destination: URL(string: "https://github.com/" + repository + "/releases/latest")!)
                }
            } label: { Image(systemName: "ellipsis").frame(width: 18, height: 18).foregroundStyle(Palette.muted) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().disabled(actionsDisabled)
                .accessibilityLabel("More actions for " + tool.name)
        }.padding(.horizontal, 12).padding(.vertical, 5).accessibilityElement(children: .contain)
    }

}

struct UpdaterView: View {
    @ObservedObject var model: UpdaterModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 15) {
                Image(nsImage: NSImage(contentsOf: Bundle.main.url(forResource: "AppIcon", withExtension: "icns")!) ?? NSApplication.shared.applicationIconImage)
                    .resizable().interpolation(.high).frame(width: 52, height: 52)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("uLEAPP").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("One place. Every LEAPP up to date.").font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Text(model.demo ? "DEMO · 0.3.13" : "FOR macOS · 0.3.13")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(Palette.green).padding(.horizontal, 11).padding(.vertical, 7)
                    .overlay(Capsule().stroke(Palette.green.opacity(0.25)))
            }
            if let update = model.appUpdate {
                HStack {
                    Text("uLEAPP \(update.version) is available").font(.system(size: 12)).foregroundStyle(Palette.green)
                    Spacer()
                    Link("Release notes", destination: update.page)
                    Link("Download update", destination: update.download)
                }.font(.system(size: 12))
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: model.busy ? "arrow.triangle.2.circlepath" : (model.failedCount > 0 ? "exclamationmark.circle" : (model.lastChecked == nil ? "sparkle" : "checkmark.circle")))
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(model.failedCount > 0 ? Palette.pink : Palette.green).frame(width: 30)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.loading ? "Finding your LEAPP apps" : model.title)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Text(model.loading ? "Reading your installed apps." : model.subtitle)
                            .font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                if model.busy {
                    ProgressView(value: model.progress).tint(Palette.green)
                    HStack {
                        Text(model.phase).font(.system(size: 11)).foregroundStyle(Palette.muted)
                        Spacer()
                        Text("\(model.completedCount) / \(model.progressTotal)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted)
                    }
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border))

            HStack {
                Text("YOUR LEAPP TOOLS").font(.system(size: 10, weight: .semibold)).tracking(1.3)
                Spacer()
                Text("\(model.displayedInstalledCount) of \(model.tools.count) installed" + (model.availableCount + model.pendingCount > 0 ? " · \(model.availableCount + model.pendingCount) available" : "")).font(.system(size: 11))
            }.foregroundStyle(Palette.muted).padding(.horizontal, 3)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.tools) { tool in
                        ToolRow(tool: tool,
                                actionsDisabled: model.busy || model.loading,
                                launchDisabled: model.busy || model.loading,
                                launch: { model.launch(tool) },
                                install: { if tool.manualDownload { model.downloadCompanion(tool) } else { model.start(.install, cask: tool.id) } },
                                directUpdate: { model.start(.update, cask: tool.id) })
                        if tool.id != model.tools.last?.id {
                            Rectangle().fill(Palette.border).frame(height: 1).padding(.leading, 76)
                        }
                    }
                }
            }
            .background(Palette.card).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { model.detailsExpanded.toggle() }
                    } label: {
                        Label("Details", systemImage: model.detailsExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }.buttonStyle(.plain)
                    Button { withAnimation(.easeInOut(duration: 0.15)) { model.settingsExpanded.toggle() } } label: {
                        Label("Settings", systemImage: model.settingsExpanded ? "chevron.down" : "chevron.right").font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }.buttonStyle(.plain)
                    Spacer()
                    if model.detailsExpanded && !model.log.isEmpty {
                        Button("Copy log") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(model.log, forType: .string)
                        }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.muted)
                        if let url = model.logURL {
                            Button("Show log") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.muted)
                        }
                    }
                }
                if model.settingsExpanded {
                    VStack(alignment: .leading, spacing: 7) {
            Toggle("Check for uLEAPP updates automatically", isOn: Binding(get: { model.automaticUpdates }, set: { model.setAutomaticUpdates($0) }))
                .font(.system(size: 11)).foregroundStyle(Palette.muted).disabled(!model.updatePreferenceEnabled || model.demo)
                        Text("Updates come from each tool’s official release. Launch opens the latest successfully installed copy. Automatic uLEAPP checks run at startup and once a day; downloads start only when you choose them.").font(.system(size: 10)).foregroundStyle(Palette.muted)
                    }.padding(.vertical, 4)
                }
                if model.detailsExpanded {
                    if model.tools.contains(where: { $0.manualDownload }) {
                        Text("Batch LEAPP’s current Mac build is not notarized and reports version 0.0.0. Install it manually from the publisher; macOS may block first launch. uLEAPP cannot confirm that copy is current and does not bypass security checks.")
                            .font(.system(size: 10)).foregroundStyle(Palette.muted).textSelection(.enabled)
                    }
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(model.log.isEmpty ? "Update details will appear here." : model.log)
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                            Color.clear.frame(height: 1).id("log-bottom")
                        }
                        .frame(height: 100).background(Color.black.opacity(0.25)).cornerRadius(9)
                        .onChange(of: model.log.count) { _ in proxy.scrollTo("log-bottom", anchor: .bottom) }
                    }
                }
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.lastChecked.map { "Last checked " + LEAPPTool.friendlyTime($0) } ?? "Only your installed LEAPP apps are updated.")
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                    if model.busy || model.loading {
                        Button(model.stopRequested ? "Stopping…" : (model.loading ? "Stop" : "Stop after this operation")) { model.requestStop() }
                            .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.muted).disabled(model.stopRequested)
                    } else if model.missingCount > 0 {
                        Button("Install missing apps (\(model.missingCount))") { model.start(.install) }
                            .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.green).disabled(model.busy || model.loading)
                    }
                }
                Spacer(minLength: 4)
                Button { model.removeOldInstalls() } label: { Label("Remove old installs", systemImage: "trash") }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.muted)
                    .disabled(model.busy || model.loading || model.demo)
                    .help("Keep the current and previous direct installs; review older copies before moving them to Trash")
                Button { model.start(.check) } label: { Label("Check for updates", systemImage: "arrow.clockwise") }
                    .buttonStyle(ActionStyle()).keyboardShortcut("r", modifiers: .command)
                    .disabled(model.busy || model.loading)
                if model.busy || !model.allInstalledCurrent {
                    Button { model.start(model.installedCount == 0 ? .install : .update) } label: { Label(model.installedCount == 0 ? "Install apps" : "Update apps", systemImage: "arrow.down.to.line") }
                        .buttonStyle(ActionStyle(primary: true)).keyboardShortcut("u", modifiers: .command)
                        .disabled(model.busy || model.loading)
                }
            }

        }
        .padding(.horizontal, 18).padding(.top, 30).padding(.bottom, 14)
        .frame(minWidth: 790, minHeight: 640)
        .background(Palette.background).preferredColorScheme(.dark)
        .onAppear { model.loadInstalled(); model.startSelfUpdateChecks() }
        .onChange(of: model.busy) { running in
            if !running && model.failedCount > 0 { model.detailsExpanded = true }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = UpdaterModel(demo: CommandLine.arguments.contains("--demo") || CommandLine.arguments.contains("--demo-missing"), demoMissing: CommandLine.arguments.contains("--demo-missing"))
    var window: NSWindow!
    @objc func showAbout(_ sender: Any?) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = "Idea by\n@CyberMike81\n\nMIT licensed · License notices\nCommunity updater for the LEAPP family of tools."
        let credits = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ])
        credits.addAttribute(.link, value: URL(string: "https://github.com/CyberMike81")!,
                             range: (text as NSString).range(of: "@CyberMike81"))
        if let notices = Bundle.main.url(forResource: "THIRD-PARTY-NOTICES", withExtension: "md") {
            credits.addAttribute(.link, value: notices, range: (text as NSString).range(of: "License notices"))
        }
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "uLEAPP", .applicationVersion: "0.3.13", .credits: credits
        ])
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        let aboutItem = appMenu.addItem(withTitle: "About uLEAPP", action: #selector(showAbout(_:)), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit uLEAPP", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApplication.shared.mainMenu = menu
        let available = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 1000)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: min(1040, available.width - 24), height: min(840, available.height - 16)),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "uLEAPP"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(srgbRed: 17/255, green: 23/255, blue: 18/255, alpha: 1)
        window.minSize = NSSize(width: min(790, available.width - 24), height: min(640, available.height - 16))
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(rootView: UpdaterView(model: model))
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func mayClose() -> Bool {
        guard model.busy else { return true }
        let alert = NSAlert()
        alert.messageText = "An update operation is running"
        alert.informativeText = "Keep uLEAPP open until the current operation finishes. You can ask it to stop afterward."
        alert.addButton(withTitle: "Keep open")
        alert.addButton(withTitle: "Stop after this operation")
        if alert.runModal() == .alertSecondButtonReturn { model.requestStop() }
        return false
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { mayClose() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { mayClose() ? .terminateNow : .terminateCancel }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

if CommandLine.arguments.contains(where: { ["--homebrew-candidate", "--complete-homebrew-return", "--askpass"].contains($0) }) {
    FileHandle.standardError.write(Data("This legacy helper has been retired. uLEAPP installs official releases.\n".utf8)); exit(2)
}
if CommandLine.arguments.contains("--direct-tool-version") {
    do {
        guard CommandLine.arguments.count == 3, let tool = LEAPPTool.all.first(where: { $0.id == CommandLine.arguments[2] }) else { exit(1) }
        guard let current = try DirectMacStore().current(tool) else { exit(3) }
        print(current.0.version); exit(0)
    } catch { FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1) }
}
if CommandLine.arguments.contains("--check-tool-release") { exit(UpstreamRelease.run(CommandLine.arguments)) }
if CommandLine.arguments.contains("--version") { print("uLEAPP 0.3.13"); exit(0) }
if CommandLine.arguments.contains("--help") {
    print("uLEAPP for Mac\n--no-update-check Disable automatic update requests for this run\n--version     Report the app version\n--selfcheck   Check the packaged app without changing installed tools\n--demo        Preview the interface with simulated updates")
    exit(0)
}
if CommandLine.arguments.contains("--self-test") || CommandLine.arguments.contains("--selfcheck") {
    if CommandLine.arguments.contains("--selfcheck") {
        precondition(Bundle.main.bundleIdentifier == "org.uleapp.updater", "App metadata is missing")
        for name in ["AppIcon.icns", "LICENSE", "THIRD-PARTY-NOTICES.md", "licenses/Swift.txt"] {
            guard let resource = Bundle.main.resourceURL?.appendingPathComponent(name) else {
                fatalError("Missing resource: \(name)")
            }
            precondition(FileManager.default.fileExists(atPath: resource.path), "Missing resource: \(name)")
            if name.hasSuffix(".sh") || name.hasSuffix(".command") {
                precondition(FileManager.default.isExecutableFile(atPath: resource.path), "Worker is not executable: \(name)")
            }
        }
        for tool in LEAPPTool.all {
            let name = tool.id.replacingOccurrences(of: "-gui", with: "")
            guard let icon = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "tool-icons") else {
                fatalError("Missing catalog icon: \(name)")
            }
            precondition(NSImage(contentsOf: icon) != nil, "Catalog icon is not readable: \(name)")
        }
    }
    GitHubMetadata.selfCheck()
    UpstreamRelease.selfCheck()
    DirectMacInstaller.selfCheck()
    var presentation = LEAPPTool.all.first { $0.id == "aleapp-gui" }!
    presentation.version = "2026.4.4"; presentation.directVersion = "2026.4.4"
    presentation.status = "installed"
    precondition(presentation.pillLabel == "Installed · 2026.4.4" && presentation.checkedAt == nil)
    presentation.status = "current"; presentation.checkedAt = Date()
    precondition(presentation.pillLabel == "Up to date · 2026.4.4" && presentation.statusHelp.contains("GitHub"))
    presentation.status = "available"; presentation.upstreamVersion = "2026.4.5"
    precondition(presentation.pillLabel == "Update 2026.4.4 → 2026.4.5")
    var companion = LEAPPTool.all.first { $0.id == "mapdownloader" }!
    companion.directVersion = "0.2.0"
    precondition(companion.sourceLine == "Offline maps for GLEAPP · Installed by uLEAPP")
    let manualFolder = FileManager.default.temporaryDirectory.appendingPathComponent("uleapp-manual-presentation-" + UUID().uuidString + ".app")
    try! FileManager.default.createDirectory(at: manualFolder, withIntermediateDirectories: true)
    var manual = LEAPPTool(id: "batch-leapp", name: "Batch LEAPP", description: "", bundle: "Batch LEAPP")
    manual.refreshPresentation(store: nil, applicationPaths: [manualFolder.path])
    let manualModel = UpdaterModel(directStore: nil)
    manualModel.tools = [manual]
    precondition(manualModel.displayedInstalledCount == 1 && manualModel.installedCount == 0 && manualModel.missingCount == 0)
    precondition(manual.pillLabel == "Installed by you", "A real manual copy is installed, but its unknown version is not called current")
    try! FileManager.default.removeItem(at: manualFolder)
    let directOnly = UpdaterModel(directStore: nil, fetchRelease: { cask in
        let tool = LEAPPTool.all.first { $0.id == cask }!
        let arch = DirectMacInstaller.architecture
        let name = cask == "batch-leapp" ? "Batch-LEAPP-macos-\(arch).zip" : cask == "mapdownloader" ? "GLEAPP-MapDownloader-v1.2.3-macos-\(arch).dmg" : cask == "lava" ? "LAVA-1.2.3-macOS-\(arch == "arm64" ? "Apple_Silicon" : "Mac_Intel").dmg" : "\(tool.bundle)-1.2.3-macos-\(arch).dmg"
        return ["tag_name": "v1.2.3", "draft": false, "prerelease": false,
                "assets": [["name": name, "browser_download_url": "https://github.com/\(UpstreamRelease.repositories[cask]!)/releases/download/v1.2.3/\(name)", "size": Int64(4), "digest": "sha256:" + String(repeating: "a", count: 64)]]]
    })
    directOnly.loadInstalled()
    precondition(!directOnly.loading)
    directOnly.start(.check)
    let deadline = Date().addingTimeInterval(10)
    while directOnly.busy && Date() < deadline { _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02)) }
    precondition(!directOnly.busy && directOnly.tools.filter { $0.status == "available" || $0.status == "download" }.count == LEAPPTool.all.count && directOnly.failedCount == 0, "Official-release checks must cover all tools")
    let model = UpdaterModel(directStore: nil)
    model.tools[0].version = "0.15.0"
    model.tools.firstIndex(where: { $0.id == "ileapp-gui" }).map { model.tools[$0].version = "2026.4.4" }
    precondition(model.installedCount == 2)
    precondition(model.tools.first(where: { $0.id == "ileapp-gui" })?.version == "2026.4.4")
    model.handleLine("ULEAPP\tapp\tlava\tchecking\tChecking for updates")
    precondition(model.tools[0].status == "checking")
    model.handleLine("ULEAPP\tapp\tlava\tavailable\tUpdate available")
    precondition(model.availableCount == 1)
    model.handleLine("ULEAPP\tversion\tlava\t\t0.16.0")
    precondition(model.tools[0].version == "0.16.0")
    model.handleLine("A useful download error")
    model.flushLog()
    precondition(model.log.contains("A useful download error"))
    precondition(!model.log.contains("ULEAPP\t"))
    model.handleLine("ULEAPP\tapp\taleapp-gui\tinstalling\tInstalling")
    precondition(model.tools[1].status == "installing")
    model.handleLine("ULEAPP\tversion\taleapp-gui\t\t2026.4.3")
    model.handleLine("ULEAPP\tapp\taleapp-gui\tcurrent\tInstalled")
    precondition(model.installedCount == 3)
    precondition(model.tools[1].status == "current")
    precondition(!model.allInstalledCurrent)
    for tool in model.tools.filter({ !$0.version.isEmpty }) {
        model.handleLine("ULEAPP\tapp\t\(tool.id)\tcurrent\tUp to date")
    }
    precondition(model.allInstalledCurrent)
    model.handleLine("ULEAPP\tupstream\tlava\t\t0.16.0")
    model.handleLine("ULEAPP\tapp\tlava\tpending\tUpdate available")
    precondition(model.pendingCount == 1 && !model.allInstalledCurrent)
    precondition(model.tools[0].upstreamVersion == "0.16.0")
    model.finish(0)
    precondition(model.title == "New LEAPP releases are available")
    model.handleLine("ULEAPP\tapp\tlava\tcurrent\tUp to date")
    model.handleLine("ULEAPP\tapp\tileapp-gui\tavailable\tUpdate available")
    precondition(!model.allInstalledCurrent)
    model.log = ""
    model.receive(Data("old progress\rnew progress\r".utf8))
    model.receive(Data("final line\r".utf8))
    model.receive(Data("\n".utf8))
    let unicode = Array("café\n".utf8)
    model.receive(Data(unicode.dropLast(2)))
    model.receive(Data(unicode.suffix(2)))
    model.flushLog()
    precondition(model.log == "final line\ncafé\n", "CR progress and split UTF-8 must not inflate or corrupt logs")
    let selfAsset = "uLEAPP-0.3.2-macOS.zip"
    var selfMetadata: [String: Any] = ["tag_name": "v0.3.2", "draft": false, "prerelease": false,
        "html_url": "https://github.com/CyberMike81/uLEAPP/releases/tag/v0.3.2",
        "assets": [["name": selfAsset, "browser_download_url": "https://github.com/CyberMike81/uLEAPP/releases/download/v0.3.2/\(selfAsset)"]]]
    precondition(SelfUpdate.select(selfMetadata, current: "0.3.1")?.version == "0.3.2")
    precondition(SelfUpdate.select(selfMetadata, current: "0.3.2") == nil)
    precondition(SelfUpdate.select(selfMetadata, current: "0.4.0") == nil)
    selfMetadata["prerelease"] = true
    precondition(SelfUpdate.select(selfMetadata, current: "0.3.1") == nil)
    selfMetadata["prerelease"] = false
    selfMetadata["assets"] = [["name": selfAsset, "browser_download_url": "https://example.org/untrusted.zip"]]
    precondition(SelfUpdate.select(selfMetadata, current: "0.3.1") == nil)
    print("uLEAPP self-check passed: installed-app detection and GUI status events.")
    exit(0)
}
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
