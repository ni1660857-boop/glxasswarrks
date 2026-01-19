import Foundation

// MARK: - Cache Manager
/// In-memory and disk caching for API responses

public actor CacheManager {
    public static let shared = CacheManager()
    
    private var memoryCache: [String: CacheEntry] = [:]
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxMemoryEntries = 500
    
    private struct CacheEntry {
        let data: Data
        let expiry: Date
        var isExpired: Bool { Date() > expiry }
    }
    
    private init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("LiquidGlassCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    public func get<T: Codable>(key: String) -> T? {
        // Check memory
        if let entry = memoryCache[key], !entry.isExpired {
            return try? JSONDecoder().decode(T.self, from: entry.data)
        }
        
        // Check disk
        let fileURL = cacheDirectory.appendingPathComponent(key.md5Hash)
        guard let data = try? Data(contentsOf: fileURL),
              let wrapper = try? JSONDecoder().decode(DiskCacheWrapper<T>.self, from: data),
              Date() < wrapper.expiry else { return nil }
        
        return wrapper.value
    }
    
    public func set<T: Codable>(key: String, value: T, ttl: TimeInterval) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let expiry = Date().addingTimeInterval(ttl)
        
        // Memory cache
        memoryCache[key] = CacheEntry(data: data, expiry: expiry)
        if memoryCache.count > maxMemoryEntries {
            let expired = memoryCache.filter { $0.value.isExpired }.keys
            expired.forEach { memoryCache.removeValue(forKey: $0) }
        }
        
        // Disk cache
        let wrapper = DiskCacheWrapper(value: value, expiry: expiry)
        if let wrapperData = try? JSONEncoder().encode(wrapper) {
            try? wrapperData.write(to: cacheDirectory.appendingPathComponent(key.md5Hash))
        }
    }
    
    public func remove(key: String) {
        memoryCache.removeValue(forKey: key)
        try? fileManager.removeItem(at: cacheDirectory.appendingPathComponent(key.md5Hash))
    }
    
    public func clear() {
        memoryCache.removeAll()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

private struct DiskCacheWrapper<T: Codable>: Codable {
    let value: T
    let expiry: Date
}

extension String {
    var md5Hash: String {
        let data = Data(utf8)
        var hash = [UInt8](repeating: 0, count: 16)
        data.withUnsafeBytes { hash = Array($0.prefix(16)) }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
