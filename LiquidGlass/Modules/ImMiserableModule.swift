import Foundation

// MARK: - I'm Miserable Module
/// Dedicated module for tidal.kinoplus.online - High quality lossless streaming

public actor ImMiserableModule: MusicModule {
    
    // MARK: - Module Identity
    public let id = "im-miserable"
    public let name = "Im Miserable"
    public let version = "1.0.0"
    public let description = "KINOPLUS TIDAL INSTANCE, LOSSLESS STREAMING"
    public let labels = ["High Quality", "Lossless"]
    public let iconURL: URL? = nil
    public var isEnabled = true
    public let requiresAuth = false
    public let allowedDomains = ["tidal.kinoplus.online", "resources.tidal.com"]
    public let signature: ModuleSignature? = nil
    
    // MARK: - Configuration
    private let baseURL = "https://tidal.kinoplus.online"
    private let urlSession: URLSession
    
    // MARK: - Initialization
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "ImMiserable/1.0"
        ]
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Search
    public func searchTracks(query: String, limit: Int = 25) async throws -> SearchResults {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/search/?s=\(encoded)&limit=\(limit)")!
        
        let response: SearchResponse = try await fetchJSON(from: url)
        
        let tracks = response.data.items.map { item -> Track in
            Track(
                id: String(item.id),
                title: item.title,
                artistName: item.artist?.name ?? item.artists?.first?.name ?? "Unknown Artist",
                artistId: item.artist?.id.map(String.init) ?? item.artists?.first?.id.map(String.init),
                album: item.album?.title ?? "Unknown Album",
                albumId: item.album?.id.map(String.init),
                albumCover: getTidalCoverURL(uuid: item.album?.cover),
                trackNumber: item.trackNumber,
                duration: TimeInterval(item.duration ?? 0),
                quality: parseQuality(item.audioQuality),
                moduleId: id
            )
        }
        
        return SearchResults(
            tracks: tracks,
            totalTracks: response.data.totalNumberOfItems ?? tracks.count
        )
    }
    
    // MARK: - Stream Resolution
    public func getTrackStream(trackId: String, preferredQuality: AudioQuality) async throws -> StreamInfo {
        let qualityParam = qualityToAPIParam(preferredQuality)
        let url = URL(string: "\(baseURL)/track/?id=\(trackId)&quality=\(qualityParam)")!
        
        let response: TrackResponse = try await fetchJSON(from: url)
        
        guard let manifest = response.data.manifest else {
            throw ModuleError.streamNotAvailable
        }
        
        guard let streamURL = extractStreamURL(from: manifest) else {
            throw ModuleError.invalidResponse("Failed to decode manifest")
        }
        
        return StreamInfo(
            url: streamURL,
            codec: parseCodec(response.data.codec),
            container: .flac,
            sampleRate: response.data.sampleRate ?? 44100,
            bitDepth: response.data.bitDepth ?? 16,
            quality: parseQuality(response.data.audioQuality),
            expiry: Date().addingTimeInterval(3600),
            trackId: trackId
        )
    }
    
    // MARK: - Album
    public func getAlbum(albumId: String) async throws -> Album {
        throw ModuleError.albumNotFound(albumId)
    }
    
    // MARK: - Helpers
    private func fetchJSON<T: Decodable>(from url: URL) async throws -> T {
        let (data, response) = try await urlSession.data(from: url)
        
        guard let http = response as? HTTPURLResponse else {
            throw ModuleError.networkError("Invalid response")
        }
        
        if http.statusCode == 429 {
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw ModuleError.rateLimited(retryAfter: retry)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw ModuleError.networkError("HTTP \(http.statusCode)")
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func extractStreamURL(from manifest: String) -> URL? {
        guard let data = Data(base64Encoded: manifest),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urls = json["urls"] as? [String],
              let first = urls.first else { return nil }
        return URL(string: first)
    }
    
    private func getTidalCoverURL(uuid: String?) -> URL? {
        guard let uuid = uuid else { return nil }
        if uuid.hasPrefix("http") { return URL(string: uuid) }
        let regex = try? NSRegularExpression(pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", options: .caseInsensitive)
        let range = NSRange(uuid.startIndex..., in: uuid)
        guard regex?.firstMatch(in: uuid, range: range) != nil else { return URL(string: uuid) }
        let path = uuid.replacingOccurrences(of: "-", with: "/")
        return URL(string: "https://resources.tidal.com/images/\(path)/640x640.jpg")
    }
    
    private func parseQuality(_ quality: String?) -> AudioQuality {
        switch quality?.uppercased() {
        case "MASTER", "HI_RES": return .master
        case "HI_RES_LOSSLESS": return .hiRes
        case "LOSSLESS": return .lossless
        case "HIGH": return .high
        case "LOW": return .low
        default: return .lossless
        }
    }
    
    private func parseCodec(_ codec: String?) -> AudioCodec {
        switch codec?.uppercased() {
        case "FLAC": return .flac
        case "ALAC": return .alac
        case "AAC": return .aac
        case "MQA": return .mqa
        default: return .flac
        }
    }
    
    private func qualityToAPIParam(_ quality: AudioQuality) -> String {
        switch quality {
        case .master: return "MASTER"
        case .hiRes: return "HI_RES"
        case .lossless: return "LOSSLESS"
        case .high: return "HIGH"
        case .normal: return "NORMAL"
        case .low: return "LOW"
        }
    }
}

// MARK: - API Response Models
private struct SearchResponse: Codable {
    let version: String
    let data: SearchData
}

private struct SearchData: Codable {
    let items: [TrackItem]
    let totalNumberOfItems: Int?
}

private struct TrackItem: Codable {
    let id: Int
    let title: String
    let artist: ArtistItem?
    let artists: [ArtistItem]?
    let album: AlbumItem?
    let duration: Int?
    let trackNumber: Int?
    let audioQuality: String?
}

private struct ArtistItem: Codable {
    let id: Int?
    let name: String
}

private struct AlbumItem: Codable {
    let id: Int?
    let title: String?
    let cover: String?
}

private struct TrackResponse: Codable {
    let version: String
    let data: TrackData
}

private struct TrackData: Codable {
    let trackId: Int?
    let manifest: String?
    let audioQuality: String?
    let bitDepth: Int?
    let sampleRate: Int?
    let codec: String?
}
