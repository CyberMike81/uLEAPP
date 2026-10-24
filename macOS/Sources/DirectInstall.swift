// SPDX-License-Identifier: MIT
import AppKit
import CryptoKit
import Darwin
import Foundation

struct DirectMacRelease {
    let version: String
    let name: String
    let url: URL
    let digest: String
    let size: Int64
}
struct DirectMacApp: Codable {
    let version: String
    let relativePath: String
}

// Direct copies have their own versioned folders and records. Homebrew's app
// bundle and receipts remain intact; Launch uses the selected direct copy.
struct DirectMacStore {
    let apps: URL
    let records: URL
    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        apps = home.appendingPathComponent("Applications/uLEAPP", isDirectory: true)
        records = home.appendingPathComponent("Library/Application Support/uLEAPP/direct-installs", isDirectory: true)
    }
    func current(_ tool: LEAPPTool) throws -> (DirectMacApp, URL)? {
        let record = records.appendingPathComponent(tool.id + ".json")
        guard FileManager.default.fileExists(atPath: record.path) else { return nil }
        let value = try JSONDecoder().decode(DirectMacApp.self, from: Data(contentsOf: record))
        _ = try UpstreamRelease.parts(value.version)
        let expected = "\(tool.id)/\(value.version)/\(tool.bundle).app"
        guard value.relativePath == expected else { throw UpstreamRelease.Failure(message: "The saved direct installation path is invalid.") }
        let app = apps.appendingPathComponent(expected)
        guard app.resolvingSymlinksInPath().path.hasPrefix(apps.resolvingSymlinksInPath().path + "/"),
              FileManager.default.fileExists(atPath: app.appendingPathComponent("Contents/Info.plist").path) else {
            throw UpstreamRelease.Failure(message: "The selected direct installation is missing or has moved.")
        }
        return (value, app)
    }
    func publish(_ staged: URL, tool: LEAPPTool, version: String) throws -> URL {
        let fm = FileManager.default
        _ = try UpstreamRelease.parts(version)
        let folder = apps.appendingPathComponent(tool.id).appendingPathComponent(version)
        guard !fm.fileExists(atPath: folder.path) else { throw UpstreamRelease.Failure(message: "This version already has a direct installation folder. Nothing was replaced.") }
        try fm.createDirectory(at: records, withIntermediateDirectories: true)
        guard apps.standardizedFileURL == apps.resolvingSymlinksInPath().standardizedFileURL,
              records.standardizedFileURL == records.resolvingSymlinksInPath().standardizedFileURL else {
            throw UpstreamRelease.Failure(message: "Direct installation folders must not be symbolic links.")
        }
        let record = DirectMacApp(version: version, relativePath: "\(tool.id)/\(version)/\(tool.bundle).app")
        try JSONEncoder().encode(record).write(to: staged.appendingPathComponent(".uleapp-install.json"), options: .atomic)
        try fm.moveItem(at: staged, to: folder)
        do {
            try JSONEncoder().encode(record).write(to: records.appendingPathComponent(tool.id + ".json"), options: .atomic)
        } catch { try? fm.removeItem(at: folder); throw error }
        return folder.appendingPathComponent(tool.bundle + ".app")
    }
    struct OldInstall {
        let label: String
        let folder: URL
    }
    // Only marked version folders whose app signature is intact are eligible.
    // Unknown files (including cases/reports) leave the whole folder untouched.
    func oldInstalls(_ tools: [LEAPPTool], cancellation: DirectMacCancellation,
                     validate: (URL) throws -> Void = { app in
                         try DirectMacInstaller.command("/usr/bin/codesign", ["--verify", "--strict", "--deep", app.path])
                     }) throws -> [OldInstall] {
        let fm = FileManager.default
        var result: [OldInstall] = []
        for tool in tools {
            try cancellation.check()
            guard let selected = try current(tool) else { continue }
            let parent = apps.appendingPathComponent(tool.id, isDirectory: true)
            guard parent.standardizedFileURL == parent.resolvingSymlinksInPath().standardizedFileURL else { continue }
            var versions: [(String, URL)] = []
            for folder in try fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) {
                try cancellation.check()
                let attributes = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard attributes.isDirectory == true, attributes.isSymbolicLink != true,
                      (try? UpstreamRelease.parts(folder.lastPathComponent)) != nil,
                      let data = try? Data(contentsOf: folder.appendingPathComponent(".uleapp-install.json")),
                      let marker = try? JSONDecoder().decode(DirectMacApp.self, from: data),
                      marker.version == folder.lastPathComponent,
                      marker.relativePath == "\(tool.id)/\(marker.version)/\(tool.bundle).app" else { continue }
                versions.append((marker.version, folder))
            }
            versions.sort { (try! UpstreamRelease.parts($1.0)).lexicographicallyPrecedes(try! UpstreamRelease.parts($0.0)) }
            let previous = versions.first { $0.0 != selected.0.version }?.0
            for (version, folder) in versions where version != selected.0.version && version != previous {
                try cancellation.check()
                let contents = try fm.contentsOfDirectory(atPath: folder.path)
                guard Set(contents).subtracting([tool.bundle + ".app", ".uleapp-install.json", ".DS_Store"]).isEmpty else { continue }
                let app = folder.appendingPathComponent(tool.bundle + ".app", isDirectory: true)
                let attrs = try app.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard attrs.isDirectory == true, attrs.isSymbolicLink != true else { continue }
                do { try validate(app) } catch { continue }
                result.append(OldInstall(label: "\(tool.name) \(version)", folder: folder))
            }
        }
        return result
    }

}

final class DirectMacCancellation {
    private let lock = NSLock()
    private var stopped = false
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func check() throws { if isCancelled { throw CancellationError() } }
}

final class DirectMacInstaller: NSObject, URLSessionDownloadDelegate {
    static var architecture: String {
        var supported: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &supported, &size, nil, 0) == 0 && supported == 1 ? "arm64" : "x64"
    }
    static func select(_ json: [String: Any], tool: LEAPPTool, architecture: String) throws -> DirectMacRelease {
        guard let repository = UpstreamRelease.repositories[tool.id], architecture == "arm64" || architecture == "x64",
              json["draft"] as? Bool == false, json["prerelease"] as? Bool == false,
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]] else { throw UpstreamRelease.Failure(message: "No supported stable Mac release was returned.") }
        _ = try UpstreamRelease.parts(tag)
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let name = tool.id == "lava" ? "LAVA-\(version)-macOS-\(architecture == "arm64" ? "Apple_Silicon" : "Mac_Intel").dmg" : "\(tool.bundle)-\(version)-macos-\(architecture).dmg"
        let matches = assets.filter { $0["name"] as? String == name }
        let expected = "https://github.com/\(repository)/releases/download/\(tag)/\(name)"
        guard matches.count == 1, let asset = matches.first,
              asset["browser_download_url"] as? String == expected,
              let digest = asset["digest"] as? String,
              digest.range(of: "^sha256:[0-9a-fA-F]{64}$", options: .regularExpression) != nil,
              let size = asset["size"] as? Int64, size > 0, size <= 2 * 1024 * 1024 * 1024,
              let url = URL(string: expected) else { throw UpstreamRelease.Failure(message: "No unique, checksummed \(architecture) Mac disk image is published for \(tool.name).") }
        return DirectMacRelease(version: version, name: name, url: url, digest: String(digest.dropFirst(7)).lowercased(), size: size)
    }
    private let ready = DispatchSemaphore(value: 0)
    private var result: Error?
    private var received = false
    private var destination: URL!
    private var expectedSize: Int64 = 0
    private var progress: (Double) -> Void = { _ in }
    private var lastProgress = Date.distantPast
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > expectedSize { downloadTask.cancel(); return }
        if Date().timeIntervalSince(lastProgress) >= 0.1 || totalBytesWritten == expectedSize {
            lastProgress = Date()
            progress(min(1, Double(totalBytesWritten) / Double(expectedSize)))
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let allowed = ["github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"]
        guard let url = request.url, url.scheme == "https", allowed.contains(url.host ?? ""), url.user == nil, url.password == nil, url.port == nil || url.port == 443 else {
            result = UpstreamRelease.Failure(message: "The download redirected outside official GitHub hosts.")
            completionHandler(nil); return
        }
        completionHandler(request)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else { throw UpstreamRelease.Failure(message: "The Mac download failed.") }
            try FileManager.default.moveItem(at: location, to: destination)
            received = true
        } catch { result = error }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, result == nil { result = error }
        ready.signal()
    }
    private func download(_ release: DirectMacRelease, to file: URL, cancellation: DirectMacCancellation, progress: @escaping (Double) -> Void) throws {
        destination = file; expectedSize = release.size; self.progress = progress
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60; config.timeoutIntervalForResource = 15 * 60
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
        defer { session.invalidateAndCancel() }
        let task = session.downloadTask(with: release.url); task.resume()
        while ready.wait(timeout: .now() + 0.1) != .success {
            if cancellation.isCancelled { task.cancel() }
        }
        try cancellation.check()
        if let error = result { throw error }
        guard received else { throw UpstreamRelease.Failure(message: "No Mac package was downloaded.") }
        try Self.verify(file, release: release)
    }
    static func verify(_ file: URL, release: DirectMacRelease) throws {
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size = size, Int64(size) == release.size else { throw UpstreamRelease.Failure(message: "The downloaded size does not match the publisher's metadata.") }
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty { hash.update(data: data) }
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == release.digest else { throw UpstreamRelease.Failure(message: "The downloaded checksum does not match. Nothing was installed.") }
    }
    @discardableResult static func command(_ executable: String, _ arguments: [String], timeout: Double = 120) throws -> String {
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.standardOutput = pipe; process.standardError = pipe; process.standardInput = FileHandle.nullDevice
        try process.run()
        let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit(); deadline.cancel()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw UpstreamRelease.Failure(message: output.isEmpty ? "\(URL(fileURLWithPath: executable).lastPathComponent) failed." : output) }
        return output
    }
    func install(_ tool: LEAPPTool, store: DirectMacStore = DirectMacStore(), cancellation: DirectMacCancellation,
                 phase: @escaping (String) -> Void, progress: @escaping (Double) -> Void) throws -> DirectMacApp {
        guard !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleURL?.lastPathComponent == tool.bundle + ".app" }) else { throw UpstreamRelease.Failure(message: "Close \(tool.name) before updating it.") }
        try cancellation.check()
        phase("Finding \(tool.name)'s official Mac release")
        let json = try UpstreamRelease.fetch(tool.id)
        try cancellation.check()
        let release = try Self.select(json, tool: tool, architecture: Self.architecture)
        if !tool.version.isEmpty, !(try UpstreamRelease.assess(json, installed: tool.version)).1 {
            throw UpstreamRelease.Failure(message: "The installed version is already as new as this release. Check for updates again.")
        }
        let fm = FileManager.default
        let temporary = fm.temporaryDirectory.appendingPathComponent("uLEAPP-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: temporary, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: temporary) }
        let package = temporary.appendingPathComponent(release.name)
        phase("Downloading \(tool.name) \(release.version)")
        try download(release, to: package, cancellation: cancellation, progress: progress)
        try cancellation.check()
        phase("Verifying and preparing \(tool.name)")
        let mount = temporary.appendingPathComponent("mount", isDirectory: true)
        try fm.createDirectory(at: mount, withIntermediateDirectories: true)
        var attached = false
        defer { if attached { _ = try? Self.command("/usr/bin/hdiutil", ["detach", mount.path]) } }
        try Self.command("/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-noautoopen", "-mountpoint", mount.path, package.path])
        attached = true
        try cancellation.check()
        let app = mount.appendingPathComponent(tool.bundle + ".app", isDirectory: true)
        let infoData = try Data(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard let info = try PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any],
              let version = info["CFBundleShortVersionString"] as? String,
              try UpstreamRelease.parts(version) == UpstreamRelease.parts(release.version),
              let executable = info["CFBundleExecutable"] as? String, !executable.contains("/"), !executable.isEmpty else { throw UpstreamRelease.Failure(message: "The app in the disk image does not match the published version.") }
        let binary = app.appendingPathComponent("Contents/MacOS/" + executable)
        guard binary.resolvingSymlinksInPath().path.hasPrefix(app.resolvingSymlinksInPath().path + "/") else { throw UpstreamRelease.Failure(message: "The app executable leaves its bundle.") }
        let architectures = try Self.command("/usr/bin/lipo", ["-archs", binary.path]).split(whereSeparator: { $0.isWhitespace })
        let wanted = Self.architecture == "arm64" ? "arm64" : "x86_64"
        guard architectures.contains(Substring(wanted)) else { throw UpstreamRelease.Failure(message: "The downloaded app does not support this Mac's processor.") }
        try Self.command("/usr/bin/codesign", ["--verify", "--strict", "--deep", app.path])
        let parent = store.apps.appendingPathComponent(tool.id, isDirectory: true)
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        guard parent.standardizedFileURL == parent.resolvingSymlinksInPath().standardizedFileURL else { throw UpstreamRelease.Failure(message: "The direct installation folder must not be a symbolic link.") }
        let stage = parent.appendingPathComponent(".staging-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) }
        let stagedApp = stage.appendingPathComponent(tool.bundle + ".app")
        try Self.command("/usr/bin/ditto", [app.path, stagedApp.path])
        try Self.command("/usr/bin/codesign", ["--verify", "--strict", "--deep", stagedApp.path])
        try cancellation.check()
        // Finish the short atomic publish before honoring a subsequent stop.
        _ = try store.publish(stage, tool: tool, version: release.version)
        phase("\(tool.name) is ready")
        return DirectMacApp(version: release.version, relativePath: "\(tool.id)/\(release.version)/\(tool.bundle).app")
    }
    static func selfCheck() {
        let tool = LEAPPTool.all.first { $0.id == "aleapp-gui" }!
        func metadata(_ arch: String) -> [String: Any] {
            let name = "ALEAPP-2026.4.4-macos-\(arch).dmg"
            return ["tag_name": "v2026.4.4", "draft": false, "prerelease": false,
                    "assets": [["name": name, "browser_download_url": "https://github.com/abrignoni/ALEAPP/releases/download/v2026.4.4/\(name)",
                                "digest": "sha256:" + String(repeating: "a", count: 64), "size": Int64(4)]]]
        }
        func reject(_ operation: () throws -> Void) {
            do { try operation(); preconditionFailure("Unsafe direct install was accepted") } catch {}
        }
        for arch in ["arm64", "x64"] {
            let selected = try! select(metadata(arch), tool: tool, architecture: arch)
            precondition(selected.name.contains("-\(arch).dmg"))
            reject { _ = try select(metadata(arch), tool: tool, architecture: arch == "arm64" ? "x64" : "arm64") }
        }
        var duplicate = metadata("arm64"); duplicate["assets"] = (duplicate["assets"] as! [[String: Any]]) + (duplicate["assets"] as! [[String: Any]])
        reject { _ = try select(duplicate, tool: tool, architecture: "arm64") }
        var preview = metadata("arm64"); preview["prerelease"] = true
        reject { _ = try select(preview, tool: tool, architecture: "arm64") }
        var unsafe = metadata("arm64"); var assets = unsafe["assets"] as! [[String: Any]]
        assets[0]["browser_download_url"] = "https://example.org/ALEAPP.dmg"; unsafe["assets"] = assets
        reject { _ = try select(unsafe, tool: tool, architecture: "arm64") }
        var noHash = metadata("arm64"); assets = noHash["assets"] as! [[String: Any]]
        assets[0]["digest"] = ""; noHash["assets"] = assets
        reject { _ = try select(noHash, tool: tool, architecture: "arm64") }
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("uleapp-direct-check-" + UUID().uuidString).resolvingSymlinksInPath()
        try! fm.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: home) }
        let bytes = Data("test".utf8); let file = home.appendingPathComponent("test.dmg"); try! bytes.write(to: file)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let valid = DirectMacRelease(version: "2026.4.4", name: "test.dmg", url: URL(string: "https://github.com/test")!, digest: hash, size: 4)
        try! verify(file, release: valid)
        try! Data("evil".utf8).write(to: file)
        reject { try verify(file, release: valid) }
        try! Data().write(to: file)
        reject { try verify(file, release: valid) }
        let store = DirectMacStore(home: home)
        precondition(try! store.current(tool) == nil)
        func staging(_ name: String) -> URL {
            let stage = store.apps.appendingPathComponent(tool.id + "/.test-" + name)
            let contents = stage.appendingPathComponent(tool.bundle + ".app/Contents")
            try! fm.createDirectory(at: contents, withIntermediateDirectories: true)
            try! Data("plist".utf8).write(to: contents.appendingPathComponent("Info.plist"))
            return stage
        }
        let old = try! store.publish(staging("one"), tool: tool, version: "2026.4.3")
        let evidence = old.appendingPathComponent("kept.txt"); try! bytes.write(to: evidence)
        _ = try! store.publish(staging("two"), tool: tool, version: "2026.4.4")
        precondition(try! store.current(tool)!.0.version == "2026.4.4")
        precondition(try! Data(contentsOf: evidence) == bytes)
        _ = try! store.publish(staging("three"), tool: tool, version: "2026.4.5")
        // The old copy with an extra case file must never become eligible.
        let extra = old.deletingLastPathComponent().appendingPathComponent("case-notes.txt")
        try! bytes.write(to: extra)
        let cancellationForScan = DirectMacCancellation()
        precondition(try! store.oldInstalls([tool], cancellation: cancellationForScan, validate: { _ in }).isEmpty)
        try! fm.removeItem(at: extra)
        let eligible = try! store.oldInstalls([tool], cancellation: cancellationForScan, validate: { _ in })
        precondition(eligible.count == 1 && eligible[0].label == "ALEAPP 2026.4.3")
        precondition(fm.fileExists(atPath: evidence.path), "Scanning must not remove an app")
        precondition(try! store.oldInstalls([tool], cancellation: cancellationForScan, validate: { _ in throw UpstreamRelease.Failure(message: "Modified app") }).isEmpty)
        let untracked = store.apps.appendingPathComponent(tool.id + "/2020.1/notes.txt")
        try! fm.createDirectory(at: untracked.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! bytes.write(to: untracked)
        precondition(try! store.oldInstalls([tool], cancellation: cancellationForScan, validate: { _ in }).count == 1)
        precondition(fm.fileExists(atPath: untracked.path))

        reject { _ = try store.publish(staging("duplicate"), tool: tool, version: "2026.4.4") }
        precondition(try! store.current(tool)!.0.version == "2026.4.5")
        let record = store.records.appendingPathComponent(tool.id + ".json")
        try! JSONEncoder().encode(DirectMacApp(version: "2026.4.4", relativePath: "../../bad.app")).write(to: record)
        reject { _ = try store.current(tool) }
        let cancellation = DirectMacCancellation(); cancellation.cancel()
        reject { try cancellation.check() }
    }

}
