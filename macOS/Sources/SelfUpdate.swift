import Foundation

struct AppUpdate {
    let version: String
    let download: URL
    let page: URL
}

enum SelfUpdate {
    static var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3.5" }
    static let repository = "CyberMike81/uLEAPP"
    static func select(_ json: [String: Any], current: String) -> AppUpdate? {
        guard let tag = json["tag_name"] as? String,
              tag.range(of: "^v?[0-9]+\\.[0-9]+\\.[0-9]+$", options: .regularExpression) != nil,
              json["draft"] as? Bool == false, json["prerelease"] as? Bool == false else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let incoming = version.split(separator: ".").compactMap { Int($0) }
        let installed = current.split(separator: ".").compactMap { Int($0) }
        guard incoming.count == 3, installed.count == 3,
              installed.lexicographicallyPrecedes(incoming) else { return nil }
        let name = "uLEAPP-\(version)-macOS.zip"
        let page = "https://github.com/\(repository)/releases/tag/\(tag)"
        let download = "https://github.com/\(repository)/releases/download/\(tag)/\(name)"
        guard json["html_url"] as? String == page,
              let assets = json["assets"] as? [[String: Any]],
              assets.filter({ $0["name"] as? String == name && $0["browser_download_url"] as? String == download }).count == 1,
              let downloadURL = URL(string: download), let pageURL = URL(string: page) else { return nil }
        return AppUpdate(version: version, download: downloadURL, page: pageURL)
    }
    static func check(completion: @escaping (AppUpdate?) -> Void) {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
        request.timeoutInterval = 15
        request.setValue("uLEAPP/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let response = response as? HTTPURLResponse, response.statusCode == 200,
                  let data = data, data.count <= 1024 * 1024,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                completion(nil); return
            }
            completion(select(json, current: currentVersion))
        }.resume()
    }
}
