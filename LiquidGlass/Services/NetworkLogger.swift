import Foundation

// MARK: - Network Logger
/// Privacy-aware network logging for observability

public actor NetworkLogger {
    public static let shared = NetworkLogger()
    
    private var logs: [NetworkLog] = []
    private let maxLogs = 1000
    
    private init() {}
    
    public struct NetworkLog: Identifiable, Sendable {
        public let id = UUID()
        public let timestamp: Date
        public let moduleId: String
        public let type: LogType
        public let message: String
        public let duration: TimeInterval?
        
        public enum LogType: String, Sendable {
            case search, stream, request, error, policy
        }
    }
    
    public func log(moduleId: String, url: URL, method: String, duration: TimeInterval, statusCode: Int?) async {
        let sanitized = sanitizeURL(url)
        let message = "\(method) \(sanitized) -> \(statusCode ?? 0)"
        append(NetworkLog(timestamp: Date(), moduleId: moduleId, type: .request, message: message, duration: duration))
    }
    
    public func logSearch(moduleId: String, query: String, resultCount: Int, duration: TimeInterval) async {
        append(NetworkLog(timestamp: Date(), moduleId: moduleId, type: .search, message: "Search '\(query)' -> \(resultCount) results", duration: duration))
    }
    
    public func logStreamResolution(moduleId: String, trackId: String, quality: AudioQuality, duration: TimeInterval) async {
        append(NetworkLog(timestamp: Date(), moduleId: moduleId, type: .stream, message: "Stream \(trackId) @ \(quality.displayName)", duration: duration))
    }
    
    public func logError(moduleId: String, error: Error) async {
        append(NetworkLog(timestamp: Date(), moduleId: moduleId, type: .error, message: error.localizedDescription, duration: nil))
    }
    
    public func logPolicyViolation(moduleId: String, reason: String) async {
        append(NetworkLog(timestamp: Date(), moduleId: moduleId, type: .policy, message: "POLICY: \(reason)", duration: nil))
    }
    
    public func getLogs(moduleId: String? = nil, limit: Int = 100) -> [NetworkLog] {
        let filtered = moduleId != nil ? logs.filter { $0.moduleId == moduleId } : logs
        return Array(filtered.suffix(limit))
    }
    
    public func clear() { logs.removeAll() }
    
    private func append(_ log: NetworkLog) {
        logs.append(log)
        if logs.count > maxLogs { logs.removeFirst(logs.count - maxLogs) }
    }
    
    private func sanitizeURL(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        components.queryItems = components.queryItems?.map { item in
            let sensitive = ["token", "key", "secret", "auth", "session", "sig"]
            return sensitive.contains(item.name.lowercased()) ? URLQueryItem(name: item.name, value: "***") : item
        }
        return components.string ?? url.absoluteString
    }
}
