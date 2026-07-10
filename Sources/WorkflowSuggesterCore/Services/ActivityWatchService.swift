import Foundation

public enum AWError: Error, CustomStringConvertible {
    case bucketNotFound(prefix: String)
    case requestFailed(String)

    public var description: String {
        switch self {
        case .bucketNotFound(let prefix):
            return "No \(prefix)* bucket found. Is ActivityWatch running with that watcher active?"
        case .requestFailed(let message):
            return "ActivityWatch request failed: \(message)"
        }
    }
}

public actor ActivityWatchService {
    private let baseURL: URL

    public init(baseURL: URL = URL(string: "http://localhost:5600/api/0")!) {
        self.baseURL = baseURL
    }

    /// Discover bucket IDs at runtime — don't hardcode a hostname, since bucket IDs are
    /// hostname-suffixed and differ across machines.
    public func discoverWindowBucket() async throws -> String {
        try await discoverBucket(prefix: "aw-watcher-window_")
    }

    public func discoverAFKBucket() async throws -> String {
        try await discoverBucket(prefix: "aw-watcher-afk_")
    }

    private func discoverBucket(prefix: String) async throws -> String {
        let url = baseURL.appendingPathComponent("buckets/")
        let (data, response) = try await URLSession.shared.data(from: url)
        try Self.checkHTTPStatus(response)
        let buckets = try JSONDecoder().decode([String: BucketInfo].self, from: data)
        guard let match = buckets.keys.first(where: { $0.hasPrefix(prefix) }) else {
            throw AWError.bucketNotFound(prefix: prefix)
        }
        return match
    }

    public func fetchEvents(bucketId: String, since: Date) async throws -> [AWEvent] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("buckets/\(bucketId)/events"),
            resolvingAgainstBaseURL: false
        )!
        let formatter = ISO8601DateFormatter()
        components.queryItems = [
            URLQueryItem(name: "start", value: formatter.string(from: since))
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        try Self.checkHTTPStatus(response)
        return try AWDateDecoding.decoder().decode([AWEvent].self, from: data)
    }

    private static func checkHTTPStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AWError.requestFailed("HTTP \(code)")
        }
    }
}
