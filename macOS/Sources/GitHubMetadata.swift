// SPDX-License-Identifier: MIT
import Foundation

enum GitHubMetadata {
    private struct Cache: Codable { let repository: String; let etag: String?; let body: Data }
    static func fetch(_ repository: String, cacheRoot: URL? = nil, session: URLSession = .shared) throws -> [String: Any] {
        let root = cacheRoot ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/uLEAPP/GitHub")
        let cache = root.appendingPathComponent(repository.replacingOccurrences(of: "/", with: "_") + ".json")
        let previous = (try? Data(contentsOf: cache)).flatMap { try? JSONDecoder().decode(Cache.self, from: $0) }
        let usable = previous?.repository == repository && (previous?.body.count ?? Int.max) <= 8 * 1024 * 1024 ? previous : nil
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
        request.timeoutInterval = 15; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("uLEAPP/\(SelfUpdate.currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let etag = usable?.etag, etag.count < 1024, !etag.contains("\n"), !etag.contains("\r") { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let ready = DispatchSemaphore(value: 0)
        var result: Result<[String: Any], Error>?
        let task = session.dataTask(with: request) { data, response, error in
            defer { ready.signal() }
            do {
                if let error = error { throw error }
                guard let response = response as? HTTPURLResponse else { throw UpstreamRelease.Failure(message: "No GitHub response.") }
                if response.statusCode == 403 || response.statusCode == 429 {
                    let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining") ?? "unknown"
                    let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset") ?? "unknown"
                    throw UpstreamRelease.Failure(message: "GitHub HTTP \(response.statusCode). Requests remaining: \(remaining); reset (Unix time): \(reset). Wait before checking again.")
                }
                let body: Data
                if response.statusCode == 304, let usable = usable { body = usable.body }
                else {
                    guard response.statusCode == 200, let data = data, data.count <= 8 * 1024 * 1024 else { throw UpstreamRelease.Failure(message: "GitHub HTTP \(response.statusCode). Update status could not be verified.") }
                    body = data
                }
                guard let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else { throw UpstreamRelease.Failure(message: "Invalid release metadata.") }
                if response.statusCode == 200 {
                    try? FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if let encoded = try? JSONEncoder().encode(Cache(repository: repository, etag: response.value(forHTTPHeaderField: "ETag"), body: body)) { try? encoded.write(to: cache, options: .atomic) }
                }
                result = .success(json)
            } catch { result = .failure(error) }
        }
        task.resume()
        guard ready.wait(timeout: .now() + 20) == .success else { task.cancel(); throw UpstreamRelease.Failure(message: "GitHub check timed out. Update status is unknown.") }
        return try result!.get()
    }
    static func selfCheck() {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("metadata-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [MetadataTestProtocol.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        MetadataTestProtocol.status = 200
        let first = try! fetch("tests/fixture", cacheRoot: temporary, session: session)
        MetadataTestProtocol.status = 304
        let second = try! fetch("tests/fixture", cacheRoot: temporary, session: session)
        precondition(first["tag_name"] as? String == second["tag_name"] as? String)
        precondition(MetadataTestProtocol.conditional == "\"one\"")
        MetadataTestProtocol.status = 403
        do { _ = try fetch("tests/fixture", cacheRoot: temporary, session: session); preconditionFailure("Rate limit used stale data") }
        catch { precondition(error.localizedDescription.contains("remaining: 0") && error.localizedDescription.contains("12345")) }
    }

}

private final class MetadataTestProtocol: URLProtocol {
    static var status = 200
    static var conditional: String?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.conditional = request.value(forHTTPHeaderField: "If-None-Match")
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: ["ETag": "\"one\"", "X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "12345"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if Self.status == 200 { client?.urlProtocol(self, didLoad: Data("{\"tag_name\":\"v1.2.3\"}".utf8)) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
