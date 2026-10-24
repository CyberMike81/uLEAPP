// SPDX-License-Identifier: MIT
import Foundation

// Used by the Homebrew worker in a separate CLI process, before it can claim
// that an installed app is current. Network failure is never a current result.
enum UpstreamRelease {
    static let repositories = [
        "lava": "leapps-org/LAVA-releases", "aleapp-gui": "abrignoni/ALEAPP",
        "ileapp-gui": "abrignoni/iLEAPP", "rleapp-gui": "abrignoni/RLEAPP",
        "vleapp-gui": "abrignoni/VLEAPP", "dleapp-gui": "abrignoni/DLEAPP",
        "gleapp": "abrignoni/GLEAPP"
    ]
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    static func parts(_ value: String) throws -> [Int] {
        let text = value.hasPrefix("v") ? String(value.dropFirst()) : value
        guard text.range(of: "^[0-9]+(?:\\.[0-9]+){1,3}$", options: .regularExpression) != nil else {
            throw Failure(message: "Could not compare the installed and published versions: \(value)")
        }
        var result = text.split(separator: ".").compactMap { Int($0) }
        guard result.count == text.split(separator: ".").count else { throw Failure(message: "Invalid version number.") }
        while result.count < 4 { result.append(0) }
        return result
    }
    static func assess(_ json: [String: Any], installed: String) throws -> (String, Bool) {
        guard json["draft"] as? Bool == false, json["prerelease"] as? Bool == false,
              let tag = json["tag_name"] as? String else { throw Failure(message: "GitHub did not return a stable release.") }
        let latest = try parts(tag)
        let versions = installed.split(whereSeparator: { $0.isWhitespace || $0 == "," })
        guard !versions.isEmpty else { throw Failure(message: "The installed app version could not be read.") }
        let current = try versions.map { try parts(String($0)) }.max { $0.lexicographicallyPrecedes($1) }!
        return (tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, current.lexicographicallyPrecedes(latest))
    }
    static func fetch(_ cask: String) throws -> [String: Any] {
        guard let repository = repositories[cask] else { throw Failure(message: "Unknown LEAPP tool.") }
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("uLEAPP/\(SelfUpdate.currentVersion)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let ready = DispatchSemaphore(value: 0)
            var result: Result<[String: Any], Error>?
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                defer { ready.signal() }
                if let error = error { result = .failure(error); return }
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      let data = data, data.count <= 2 * 1024 * 1024,
                      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                    result = .failure(Failure(message: "GitHub release check failed. Check your connection or GitHub's rate limit and retry.")); return
                }
                result = .success(json)
            }
            task.resume()
            guard ready.wait(timeout: .now() + 20) == .success else {
                task.cancel(); throw Failure(message: "GitHub release check timed out. Update status is unknown.")
            }
            return try result!.get()
    }
    static func run(_ arguments: [String]) -> Int32 {
        do {
            guard arguments.count == 4, repositories[arguments[2]] != nil else {
                throw Failure(message: "Use --check-tool-release CASK INSTALLED_VERSION.")
            }
            let (version, newer) = try assess(try fetch(arguments[2]), installed: arguments[3])
            print(version)
            return newer ? 10 : 0
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            return 1
        }
    }
    static func selfCheck() {
        func fixture(_ version: String) -> [String: Any] { ["tag_name": version, "draft": false, "prerelease": false] }
        precondition(try! assess(fixture("v2026.4.5"), installed: "2026.4.4").1)
        precondition(!(try! assess(fixture("v2026.4.5"), installed: "v2026.4.5").1))
        precondition(!(try! assess(fixture("v2026.4.5"), installed: "2026.4.6").1))
        precondition(try! assess(fixture("v2026.4.10"), installed: "2026.4.9").1)
        precondition(!(try! assess(fixture("v1.2.0"), installed: "1.2").1))
        precondition(!(try! assess(fixture("v2026.4.5"), installed: "2026.4.4, 2026.4.5").1))
        for value in ["unknown", "1.2-beta", "", "1.2x"] {
            do { _ = try assess(fixture("v1.2.3"), installed: value); preconditionFailure("Invalid version accepted") } catch {}
        }
        var preview = fixture("v1.2.3"); preview["prerelease"] = true
        do { _ = try assess(preview, installed: "1.0"); preconditionFailure("Preview accepted") } catch {}
    }
}
