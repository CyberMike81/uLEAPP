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
    var stateColor: Color {
        switch tool.status {
        case "current": return Palette.green
        case "available": return Palette.orange
        case "failed": return Palette.pink
        case "checking", "updating", "installing": return Palette.green
        default: return Palette.muted
        }
    }
    var body: some View {
        HStack(spacing: 14) {
            if let icon = tool.icon {
                Image(nsImage: icon).resizable().interpolation(.high)
                    .frame(width: 44, height: 44).accessibilityHidden(true)
            } else {
                Image(systemName: "app.dashed").font(.system(size: 28))
                    .foregroundStyle(Palette.muted).frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(tool.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    if !tool.version.isEmpty {
                        Text(tool.version).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted)
                    }
                }
                Text(tool.description).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                if ["checking", "updating", "installing"].contains(tool.status) {
                    ProgressView().controlSize(.small).scaleEffect(0.7).frame(width: 14, height: 14)
                } else if tool.status == "current" {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                } else if tool.status == "available" {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 12))
                } else if tool.status == "failed" {
                    Image(systemName: "exclamationmark.circle.fill").font(.system(size: 12))
                }
                Text(tool.statusLabel).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(stateColor)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(stateColor.opacity(0.09)).clipShape(Capsule())
            if tool.existingBundlePath != nil {
                Button("Launch") { launch() }
                    .controlSize(.small).tint(Palette.green)
                    .disabled(launchDisabled)
                    .help("Open \(tool.name)")
                    .accessibilityLabel("Launch \(tool.name)")
            }
            if tool.version.isEmpty {
                Button(tool.existingBundlePath == nil ? "Install" : "Add") { install() }
                    .controlSize(.small).tint(Palette.green)
                    .disabled(actionsDisabled)
                    .help(tool.existingBundlePath == nil ? "Install \(tool.name) through Homebrew" : "Add a matching existing \(tool.name) app to Homebrew")
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
        .accessibilityElement(children: .contain)
    }
}

struct UpdaterView: View {
    @ObservedObject var model: UpdaterModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 15) {
                Image(nsImage: NSImage(contentsOf: Bundle.main.url(forResource: "AppIcon", withExtension: "icns")!) ?? NSApplication.shared.applicationIconImage)
                    .resizable().interpolation(.high).frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("uLEAPP").font(.system(size: 33, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("One place. Every LEAPP up to date.").font(.system(size: 14)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Text(model.demo ? "DEMO · 0.2.2" : "FOR macOS · 0.2.2")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(Palette.green).padding(.horizontal, 11).padding(.vertical, 7)
                    .overlay(Capsule().stroke(Palette.green.opacity(0.25)))
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: model.busy ? "arrow.triangle.2.circlepath" : (model.failedCount > 0 ? "exclamationmark.circle" : (model.lastChecked.isEmpty ? "sparkle" : "checkmark.circle")))
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(model.failedCount > 0 ? Palette.pink : Palette.green).frame(width: 30)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.loading ? "Finding your LEAPP apps" : model.title)
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                        Text(model.loading ? "Reading the apps managed by Homebrew." : model.subtitle)
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
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border))

            HStack {
                Text("YOUR LEAPP TOOLS").font(.system(size: 10, weight: .semibold)).tracking(1.3)
                Spacer()
                Text("\(model.installedCount) managed by Homebrew").font(.system(size: 11))
            }.foregroundStyle(Palette.muted).padding(.horizontal, 3)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.tools) { tool in
                        ToolRow(tool: tool,
                                actionsDisabled: model.busy || model.loading || !model.brewFound,
                                launchDisabled: model.busy || model.loading,
                                launch: { model.launch(tool) },
                                install: { model.start(.install, cask: tool.id) })
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
                if model.detailsExpanded {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(model.log.isEmpty ? "Update details will appear here." : model.log)
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                            Color.clear.frame(height: 1).id("log-bottom")
                        }
                        .frame(height: 135).background(Color.black.opacity(0.25)).cornerRadius(9)
                        .onChange(of: model.log.count) { _ in proxy.scrollTo("log-bottom", anchor: .bottom) }
                    }
                }
            }
            HStack(spacing: 10) {
                if model.busy {
                    Button(model.stopRequested ? "Stopping after this operation…" : "Stop after this operation") { model.requestStop() }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.muted)
                        .disabled(model.stopRequested)
                } else if model.missingCount > 0 && !model.loading {
                    Button("Install missing apps (\(model.missingCount))") { model.start(.install) }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.green)
                        .disabled(!model.brewFound)
                } else {
                    Text(model.lastChecked.isEmpty ? "Only your installed LEAPP apps are updated." : "Last checked \(model.lastChecked)")
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 4)
                Button { model.start(.check) } label: { Label("Check for updates", systemImage: "arrow.clockwise") }
                    .buttonStyle(ActionStyle()).keyboardShortcut("r", modifiers: .command)
                    .disabled(model.busy || model.loading || !model.brewFound)
                if model.busy || !model.allInstalledCurrent {
                    Button { model.start(model.installedCount == 0 ? .install : .update) } label: { Label(model.installedCount == 0 ? "Install apps" : "Update apps", systemImage: "arrow.down.to.line") }
                        .buttonStyle(ActionStyle(primary: true)).keyboardShortcut("u", modifiers: .command)
                        .disabled(model.busy || model.loading || !model.brewFound)
                }
            }
            if !model.brewFound {
                Link("Get Homebrew", destination: URL(string: "https://brew.sh")!).foregroundStyle(Palette.green)
            }
        }
        .padding(.horizontal, 26).padding(.top, 38).padding(.bottom, 23)
        .frame(minWidth: 790, minHeight: 690)
        .background(Palette.background).preferredColorScheme(.dark)
        .onAppear { model.loadInstalled() }
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
            .applicationName: "uLEAPP", .applicationVersion: "0.2.2", .credits: credits
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
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: min(900, available.height - 40)),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "uLEAPP"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(srgbRed: 17/255, green: 23/255, blue: 18/255, alpha: 1)
        window.minSize = NSSize(width: 790, height: 690)
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

if CommandLine.arguments.contains("--askpass") { runAskpass() }
if CommandLine.arguments.contains("--version") { print("uLEAPP 0.2.2"); exit(0) }
if CommandLine.arguments.contains("--help") {
    print("uLEAPP for Mac\n--version     Report the app version\n--selfcheck   Check the packaged app without changing installed tools\n--demo        Preview the interface with simulated updates")
    exit(0)
}
if CommandLine.arguments.contains("--self-test") || CommandLine.arguments.contains("--selfcheck") {
    if CommandLine.arguments.contains("--selfcheck") {
        precondition(Bundle.main.bundleIdentifier == "org.uleapp.updater", "App metadata is missing")
        for name in ["LEAPP Updater.command", "askpass.sh", "AppIcon.icns", "LICENSE", "THIRD-PARTY-NOTICES.md", "licenses/Swift.txt"] {
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
    let model = UpdaterModel()
    model.applyInstalled("lava 0.15.0\nleapps-org/leapps/ileapp-gui 2026.4.4\nopenscad 2021.01\n")
    precondition(model.installedCount == 2)
    precondition(model.tools.first(where: { $0.id == "ileapp-gui" })?.version == "2026.4.4")
    model.handleLine("ULEAPP\tapp\tlava\tchecking\tChecking for updates")
    precondition(model.tools[0].status == "checking")
    model.handleLine("ULEAPP\tapp\tlava\tavailable\tUpdate available")
    precondition(model.availableCount == 1)
    model.handleLine("ULEAPP\tversion\tlava\t\t0.16.0")
    precondition(model.tools[0].version == "0.16.0")
    model.handleLine("A useful Homebrew error")
    precondition(model.log.contains("A useful Homebrew error"))
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
    model.handleLine("ULEAPP\tapp\tileapp-gui\tavailable\tUpdate available")
    precondition(!model.allInstalledCurrent)
    print("uLEAPP self-check passed: installed-app detection and GUI status events.")
    exit(0)
}
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
