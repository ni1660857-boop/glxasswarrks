import Foundation
import Combine

// MARK: - HiFi API

@MainActor
public final class HiFiAPI: ObservableObject {
    public static let shared = HiFiAPI()
    
    @Published public private(set) var currentQuality: AudioQuality = .lossless
    @Published public private(set) var isBuffering: Bool = false
    @Published public private(set) var lastError: Error?
    
    private let moduleRegistry: ModuleRegistry
    private let cacheManager: CacheManager
    private let securityManager: SecurityManager
    
    public struct Config {
        public var preferredQuality: AudioQuality = .lossless
        public var allowQualityDowngrade: Bool = true
        public var maxRetries: Int = 3
        public var cacheEnabled: Bool = true
        public var cacheDuration: TimeInterval = 3600
        public static let `default` = Config()
    }
    
    public var config: Config = .default
    
    private init() {
        self.moduleRegistry = ModuleRegistry()
        self.cacheManager = CacheManager.shared
        self.securityManager = SecurityManager.shared
    }
    
    public var registry: ModuleRegistry { moduleRegistry }
    
    public func search(query: String, limit: Int = 25) async throws -> SearchResults {
        guard let module = moduleRegistry.primaryModule else {
            throw HiFiError.noModulesAvailable
        }
        return try await module.searchTracks(query: query, limit: limit)
    }
    
    public func resolveStream(track: Track, quality: AudioQuality? = nil) async throws -> StreamInfo {
        let preferredQuality = quality ?? config.preferredQuality
        isBuffering = true
        defer { isBuffering = false }
        
        guard let module = moduleRegistry.module(id: track.moduleId) else {
            throw HiFiError.moduleNotFound(track.moduleId)
        }
        
        let streamInfo = try await module.getTrackStream(trackId: track.id, preferredQuality: preferredQuality)
        try await securityManager.validateModuleURL(streamInfo.url, moduleId: track.moduleId)
        self.currentQuality = streamInfo.quality
        return streamInfo
    }
    
    public func getAlbum(albumId: String, moduleId: String) async throws -> Album {
        guard let module = moduleRegistry.module(id: moduleId) else {
            throw HiFiError.moduleNotFound(moduleId)
        }
        return try await module.getAlbum(albumId: albumId)
    }
    
    public func setPreferredQuality(_ quality: AudioQuality) {
        config.preferredQuality = quality
    }
}

public enum HiFiError: LocalizedError {
    case noModulesAvailable
    case moduleNotFound(String)
    case streamResolutionFailed
    case downloadNotAllowed
    
    public var errorDescription: String? {
        switch self {
        case .noModulesAvailable: return "No music modules available"
        case .moduleNotFound(let id): return "Module not found: \(id)"
        case .streamResolutionFailed: return "Stream resolution failed"
        case .downloadNotAllowed: return "Download not allowed"
        }
    }
}
