import Foundation
import JavaScriptCore
import Combine

// MARK: - Music Module Protocol

/// Core protocol that all music source modules must implement.
/// Each module provides access to a specific music catalog and streaming service.
///
/// Modules operate in a sandboxed environment with strict security controls:
/// - Domain allowlisting for network requests
/// - Signed module verification
/// - Rate limiting and policy enforcement
public protocol MusicModule: Actor {
    
    // MARK: - Module Identity
    
    /// Unique identifier for the module (e.g., "im-miserable", "spotify")
    var id: String { get }
    
    /// Human-readable module name
    var name: String { get }
    
    /// Semantic version string (e.g., "1.0.0")
    var version: String { get }
    
    /// Module description for the UI
    var description: String { get }
    
    /// Feature labels (e.g., ["High Quality", "Lossless"])
    var labels: [String] { get }
    
    /// Module icon URL (optional)
    var iconURL: URL? { get }
    
    // MARK: - Module State
    
    /// Whether the module is currently enabled
    var isEnabled: Bool { get }
    
    /// Whether authentication is required
    var requiresAuth: Bool { get }
    
    /// Current authentication status
    var isAuthenticated: Bool { get async }
    
    /// Allowed domains for network requests (security sandbox)
    var allowedDomains: [String] { get }
    
    /// Module signature for verification (optional for built-in modules)
    var signature: ModuleSignature? { get }
    
    // MARK: - Search Operations
    
    /// Search for tracks matching the query.
    /// - Parameters:
    ///   - query: Search string
    ///   - limit: Maximum number of results (default 25)
    /// - Returns: SearchResults containing matching tracks, albums, and artists
    func searchTracks(query: String, limit: Int) async throws -> SearchResults
    
    // MARK: - Content Operations
    
    /// Get detailed information about an album.
    /// - Parameter albumId: The album identifier
    /// - Returns: Album with full track listing
    func getAlbum(albumId: String) async throws -> Album
    
    /// Get detailed information about an artist.
    /// - Parameter artistId: The artist identifier
    /// - Returns: Artist with biography and discography
    func getArtist(artistId: String) async throws -> Artist
    
    // MARK: - Stream Operations
    
    /// Resolve a playable stream URL for a track.
    /// - Parameters:
    ///   - trackId: The track identifier
    ///   - preferredQuality: Desired audio quality (may be downgraded if unavailable)
    /// - Returns: StreamInfo containing the URL and audio metadata
    func getTrackStream(
        trackId: String,
        preferredQuality: AudioQuality
    ) async throws -> StreamInfo
    
    // MARK: - Download Operations (Optional)
    
    /// Check if offline downloads are supported and permitted.
    /// - Parameter trackId: The track to check
    /// - Returns: Whether download is allowed
    func canDownload(trackId: String) async -> Bool
    
    /// Get download URL for offline storage.
    /// Only available when the source grants offline rights.
    /// - Parameters:
    ///   - trackId: The track identifier
    ///   - quality: Desired download quality
    /// - Returns: URL for downloading the track
    func getDownloadURL(
        trackId: String,
        quality: AudioQuality
    ) async throws -> URL
    
    // MARK: - Authentication (Optional)
    
    /// Initiate authentication flow.
    /// - Returns: Authentication URL for OAuth or similar
    func authenticate() async throws -> URL?
    
    /// Complete authentication with callback data.
    /// - Parameter callbackURL: The OAuth callback URL
    func handleAuthCallback(callbackURL: URL) async throws
    
    /// Sign out and clear credentials.
    func signOut() async
}

// MARK: - Module Signature

/// Cryptographic signature for module verification
public struct ModuleSignature: Codable, Sendable {
    public let data: Data
    public let algorithm: String
    public let certificateId: String
    public let timestamp: Date
    
    public init(data: Data, algorithm: String = "SHA256withRSA", certificateId: String) {
        self.data = data
        self.algorithm = algorithm
        self.certificateId = certificateId
        self.timestamp = Date()
    }
}

// MARK: - Module Manifest

/// Remote module manifest for dynamic loading
public struct ModuleManifest: Codable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let description: String
    public let author: String
    public let homepage: URL?
    public let downloadURL: URL
    public let checksum: String
    public let signature: ModuleSignature
    public let minAppVersion: String
    public let allowedDomains: [String]
    public let permissions: [ModulePermission]
    public let updatedAt: Date
    
    public enum ModulePermission: String, Codable, Sendable {
        case network = "NETWORK"
        case storage = "STORAGE"
        case notifications = "NOTIFICATIONS"
        case backgroundAudio = "BACKGROUND_AUDIO"
    }
}

// MARK: - Module Capability

/// Describes what a module can do
public struct ModuleCapability: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let search = ModuleCapability(rawValue: 1 << 0)
    public static let streaming = ModuleCapability(rawValue: 1 << 1)
    public static let downloads = ModuleCapability(rawValue: 1 << 2)
    public static let lossless = ModuleCapability(rawValue: 1 << 3)
    public static let hiRes = ModuleCapability(rawValue: 1 << 4)
    public static let lyrics = ModuleCapability(rawValue: 1 << 5)
    public static let playlists = ModuleCapability(rawValue: 1 << 6)
    public static let recommendations = ModuleCapability(rawValue: 1 << 7)
    
    public static let all: ModuleCapability = [
        .search, .streaming, .downloads, .lossless, .hiRes, .lyrics, .playlists, .recommendations
    ]
}

// MARK: - Module Event

/// Events emitted by modules for observability
public enum ModuleEvent: Sendable {
    case searchStarted(query: String)
    case searchCompleted(query: String, resultCount: Int, duration: TimeInterval)
    case searchFailed(query: String, error: Error)
    case streamRequested(trackId: String, quality: AudioQuality)
    case streamResolved(trackId: String, quality: AudioQuality, duration: TimeInterval)
    case streamFailed(trackId: String, error: Error)
    case authenticationRequired
    case authenticationCompleted
    case authenticationFailed(Error)
    case rateLimitHit(retryAfter: TimeInterval?)
    case policyViolation(reason: String)
}

// MARK: - Module Delegate

/// Delegate for receiving module events
public protocol MusicModuleDelegate: AnyObject, Sendable {
    func module(_ module: any MusicModule, didEmit event: ModuleEvent) async
}

// MARK: - Default Implementations

public extension MusicModule {
    var labels: [String] { [] }
    var iconURL: URL? { nil }
    var requiresAuth: Bool { false }
    var signature: ModuleSignature? { nil }
    
    var isAuthenticated: Bool {
        get async { !requiresAuth }
    }
    
    func canDownload(trackId: String) async -> Bool {
        false
    }
    
    func getDownloadURL(trackId: String, quality: AudioQuality) async throws -> URL {
        throw ModuleError.streamNotAvailable
    }
    
    func authenticate() async throws -> URL? {
        nil
    }
    
    func handleAuthCallback(callbackURL: URL) async throws {
        // Default no-op
    }
    
    func signOut() async {
        // Default no-op
    }
    
    func getArtist(artistId: String) async throws -> Artist {
        throw ModuleError.artistNotFound(artistId)
    }
}

// MARK: - Module Context

/// Provides context and utilities to modules during execution
public actor ModuleContext {
    public let moduleId: String
    private let securityManager: SecurityManager
    private let networkLogger: NetworkLogger
    
    public init(
        moduleId: String,
        securityManager: SecurityManager,
        networkLogger: NetworkLogger
    ) {
        self.moduleId = moduleId
        self.securityManager = securityManager
        self.networkLogger = networkLogger
    }
    
    /// Validate a URL against the module's allowed domains
    public func validateURL(_ url: URL) async throws {
        try await securityManager.validateModuleURL(url, moduleId: moduleId)
    }
    
    /// Log a network request (privacy-aware)
    public func logRequest(url: URL, method: String, duration: TimeInterval, statusCode: Int?) async {
        await networkLogger.log(
            moduleId: moduleId,
            url: url,
            method: method,
            duration: duration,
            statusCode: statusCode
        )
    }
}

// MARK: - Base Module Implementation

/// Base actor providing common module functionality
public actor BaseModule {
    public let id: String
    public let name: String
    public let version: String
    public let description: String
    public let allowedDomains: [String]
    
    public var isEnabled: Bool = true
    
    private let urlSession: URLSession
    private weak var delegate: (any MusicModuleDelegate)?
    
    public init(
        id: String,
        name: String,
        version: String,
        description: String,
        allowedDomains: [String]
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.allowedDomains = allowedDomains
        
        // Configure URL session with security settings
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "LiquidGlass/1.0 iOS"
        ]
        self.urlSession = URLSession(configuration: config)
    }
    
    public func setDelegate(_ delegate: any MusicModuleDelegate) {
        self.delegate = delegate
    }
    
    public func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }
    
    /// Protected fetch method with domain validation
    public func fetchJSON<T: Decodable>(
        from url: URL,
        as type: T.Type
    ) async throws -> T {
        // Validate domain
        guard let host = url.host, allowedDomains.contains(where: { host.hasSuffix($0) }) else {
            throw ModuleError.securityViolation("Domain not allowed: \(url.host ?? "unknown")")
        }
        
        let startTime = Date()
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            _ = Date().timeIntervalSince(startTime) // Duration tracked for logging
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ModuleError.networkError("Invalid response")
            }
            
            // Handle rate limiting
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { TimeInterval($0) }
                throw ModuleError.rateLimited(retryAfter: retryAfter)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw ModuleError.networkError("HTTP \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(type, from: data)
            
        } catch let error as ModuleError {
            throw error
        } catch {
            throw ModuleError.networkError(error.localizedDescription)
        }
    }
    
    /// Emit an event to the delegate
    public func emit(_ event: ModuleEvent) async {
        await delegate?.module(self as! any MusicModule, didEmit: event)
    }
}

// MARK: - JavaScript Module Adapter

/// A module that runs dynamic JavaScript code in a sandboxed environment
public actor JavaScriptModule: MusicModule, ObservableObject {
    nonisolated public let id: String
    nonisolated public let name: String
    nonisolated public let version: String
    nonisolated public let description: String
    
    // JS Properties
    private let context: JSContext
    private let sourceCode: String
    
    // Module State
    public var isEnabled: Bool = true
    public var allowedDomains: [String] = []
    
    // Events
    private weak var delegate: (any MusicModuleDelegate)?
    
    public init(sourceCode: String) throws {
        self.sourceCode = sourceCode
        self.context = JSContext()!
        
        // 1. Setup Exception Handling
        context.exceptionHandler = { context, exception in
            print("JS Error: \(exception?.toString() ?? "Unknown")")
        }
        
        // 2. Setup Console Polyfill
        let console: @convention(block) (String) -> Void = { message in
            print("[JS Module] Log: \(message)")
        }
        let consoleObj = JSValue(newObjectIn: context)
        consoleObj?.setObject(unsafeBitCast(console, to: AnyObject.self), forKeyedSubscript: "log" as NSString)
        consoleObj?.setObject(unsafeBitCast(console, to: AnyObject.self), forKeyedSubscript: "error" as NSString)
        context.setObject(consoleObj, forKeyedSubscript: "console" as NSString)
        
        // 3. Setup Fetch Polyfill (Native Bridge)
        // We expose a native function that takes a URL, options, and a callback ID
        // The JS side will wrap this in a Promise
        
        // Native fetch implementation block
        let nativeFetch: @convention(block) (String, [String: Any]?, JSValue, JSValue) -> Void = { urlString, options, resolve, reject in
            guard let url = URL(string: urlString) else {
                reject.call(withArguments: ["Invalid URL"])
                return
            }
            
            // Perform request async detached to not block JS thread
            Task {
                do {
                    // Basic request
                    var request = URLRequest(url: url)
                    if let method = options?["method"] as? String {
                        request.httpMethod = method
                    }
                    if let headers = options?["headers"] as? [String: String] {
                        for (key, value) in headers {
                            request.setValue(value, forHTTPHeaderField: key)
                        }
                    }
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                         reject.call(withArguments: ["Invalid response"])
                         return
                    }
                    
                    // Simple response object for JS
                    // We return text by default, let JS parse JSON if needed
                    let text = String(data: data, encoding: .utf8) ?? ""
                    let responseObj: [String: Any] = [
                        "status": httpResponse.statusCode,
                        "ok": (200...299).contains(httpResponse.statusCode),
                        "text": text,
                        "url": httpResponse.url?.absoluteString ?? urlString
                    ]
                    
                    // Back to JS thread
                    // resolve(responseObj)
                    resolve.call(withArguments: [responseObj])
                    
                } catch {
                    reject.call(withArguments: [error.localizedDescription])
                }
            }
        }
        
        context.setObject(unsafeBitCast(nativeFetch, to: AnyObject.self), forKeyedSubscript: "nativeFetch" as NSString)
        
        // 4. Inject Fetch Wrapper (Promise-based)
        let polyfillScript = """
        const fetch = (url, options) => {
            return new Promise((resolve, reject) => {
                nativeFetch(url, options || {}, resolve, reject);
            });
        };
        """
        context.evaluateScript(polyfillScript)
        
        // 5. Evaluate User Module
        // We wrap it to scope it, but for now let's assume the module exports an object 'module'
        let wrappedCode = """
        var module = {};
        (function() {
            \(sourceCode)
        })();
        """
        context.evaluateScript(wrappedCode)
        
        // 6. Extract Metadata
        let moduleObj = context.objectForKeyedSubscript("module")
        
        guard let module = moduleObj, !module.isUndefined else {
            throw ModuleError.invalidFormat("No 'module' object found")
        }
        
        self.id = module.objectForKeyedSubscript("id")?.toString() ?? UUID().uuidString
        self.name = module.objectForKeyedSubscript("name")?.toString() ?? "Unnamed Module"
        self.version = module.objectForKeyedSubscript("version")?.toString() ?? "1.0.0"
        self.description = module.objectForKeyedSubscript("description")?.toString() ?? "No description"
        
        // Extract allowed domains if present
        if let domains = module.objectForKeyedSubscript("allowedDomains"), domains.isArray {
            self.allowedDomains = domains.toArray() as? [String] ?? []
        }
    }
    
    public func setDelegate(_ delegate: any MusicModuleDelegate) {
        self.delegate = delegate
    }
    
    // MARK: - MusicModule Implementation
    
    public func searchTracks(query: String, limit: Int) async throws -> SearchResults {
        return try await withCheckedThrowingContinuation { continuation in
            guard let searchFunc = context.objectForKeyedSubscript("module")?.objectForKeyedSubscript("searchTracks") else {
                continuation.resume(throwing: ModuleError.notImplemented)
                return
            }
            
            // Call JS function
            // Expectation: searchTracks(query, limit) -> Promise<SearchResults> or SearchResults
            let result = searchFunc.call(withArguments: [query, limit])
            
            handleJSResult(result, continuation: continuation) { jsValue in
                // Parse JSValue to SearchResults
                // This is a simplified parser. Real implementation needs robust JSON conversion.
                // Assuming JS returns: { tracks: [...], albums: [...], artists: [...] }
                
                let tracks: [Track] = self.parseTracks(from: jsValue?.objectForKeyedSubscript("tracks"))
                return SearchResults(tracks: tracks, albums: [], artists: [])
            }
        }
    }
    
    public func getTrackStream(trackId: String, preferredQuality: AudioQuality) async throws -> StreamInfo {
        return try await withCheckedThrowingContinuation { continuation in
             guard let streamFunc = context.objectForKeyedSubscript("module")?.objectForKeyedSubscript("getTrackStream") else {
                continuation.resume(throwing: ModuleError.notImplemented)
                return
            }
            
            let result = streamFunc.call(withArguments: [trackId, preferredQuality.rawValue])
            
            handleJSResult(result, continuation: continuation) { jsValue in
                // Expects: { url: "...", quality: "lossless", format: "mp3" }
                guard let urlString = jsValue?.objectForKeyedSubscript("url")?.toString(),
                      let url = URL(string: urlString) else {
                    throw ModuleError.invalidResponse("Missing URL")
                }
                
                let qualityStr = jsValue?.objectForKeyedSubscript("quality")?.toString() ?? "NORMAL"
                let quality = AudioQuality(rawValue: qualityStr) ?? .normal
                
                return StreamInfo(
                    url: url,
                    codec: .mp3,
                    container: .unknown,
                    quality: quality,
                    trackId: trackId
                )
            }
        }
    }
    
    public func getAlbum(albumId: String) async throws -> Album {
         throw ModuleError.notImplemented // Placeholder
    }
    
    public func getArtist(artistId: String) async throws -> Artist {
         throw ModuleError.notImplemented // Placeholder
    }
    
    // MARK: - Helpers
    
    private func handleJSResult<T>(_ result: JSValue?, continuation: CheckedContinuation<T, Error>, transform: @escaping (JSValue?) throws -> T) {
        guard let result = result else {
            continuation.resume(throwing: ModuleError.executionFailed("Result is nil"))
            return
        }
        
        // Handle Promise
        if result.hasProperty("then") {
            let onFulfilled: @convention(block) (JSValue) -> Void = { value in
                do {
                    let transformed = try transform(value)
                    continuation.resume(returning: transformed)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            let onRejected: @convention(block) (JSValue) -> Void = { reason in
                continuation.resume(throwing: ModuleError.executionFailed(reason.toString()))
            }
            
            result.invokeMethod("then", withArguments: [unsafeBitCast(onFulfilled, to: AnyObject.self), unsafeBitCast(onRejected, to: AnyObject.self)])
            
        } else {
            // Synchronous return
            do {
                let transformed = try transform(result)
                continuation.resume(returning: transformed)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseTracks(from jsArray: JSValue?) -> [Track] {
        guard let jsArray = jsArray, jsArray.isArray else { return [] }
        var tracks: [Track] = []
        
        let length = Int(jsArray.objectForKeyedSubscript("length").toInt32())
        for i in 0..<length {
            if let item = jsArray.atIndex(i) {
                // Map JS object to Track struct
                // ID, Title, Artist, Album, ImageURL
                if let id = item.objectForKeyedSubscript("id")?.toString(),
                   let title = item.objectForKeyedSubscript("title")?.toString() {
                       
                    let artist = item.objectForKeyedSubscript("artist")?.toString() ?? "Unknown"
                    let album = item.objectForKeyedSubscript("album")?.toString() ?? "Unknown"
                    let artUrl = item.objectForKeyedSubscript("artwork")?.toString()
                    
                    tracks.append(Track(
                        id: id,
                        title: title,
                        artistName: artist,
                        album: album,
                        albumCover: URL(string: artUrl ?? ""),
                        duration: 0,
                        moduleId: self.id
                    ))
                }
            }
        }
        return tracks
    }
}
