import Foundation

// MARK: - Core Data Models

/// Represents audio quality levels supported by the HiFi API
public enum AudioQuality: String, Codable, CaseIterable, Sendable {
    case low = "LOW"           // AAC 96kbps
    case normal = "NORMAL"     // AAC 160kbps
    case high = "HIGH"         // AAC 320kbps
    case lossless = "LOSSLESS" // FLAC 16-bit/44.1kHz
    case hiRes = "HI_RES"      // FLAC 24-bit/96kHz+
    case master = "MASTER"     // MQA or Hi-Res FLAC
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .lossless: return "Lossless"
        case .hiRes: return "Hi-Res"
        case .master: return "Master"
        }
    }
    
    var badge: String {
        switch self {
        case .low, .normal: return "AAC"
        case .high: return "AAC 320"
        case .lossless: return "FLAC"
        case .hiRes: return "Hi-Res"
        case .master: return "Master"
        }
    }
    
    var priority: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .lossless: return 3
        case .hiRes: return 4
        case .master: return 5
        }
    }
}

/// Audio codec types
public enum AudioCodec: String, Codable, Sendable {
    case aac = "AAC"
    case alac = "ALAC"
    case flac = "FLAC"
    case mqa = "MQA"
    case mp3 = "MP3"
    case opus = "OPUS"
    case unknown = "UNKNOWN"
    
    var lossless: Bool {
        switch self {
        case .alac, .flac, .mqa: return true
        default: return false
        }
    }
}

/// Audio container formats
public enum AudioContainer: String, Codable, Sendable {
    case mp4 = "MP4"
    case m4a = "M4A"
    case flac = "FLAC"
    case wav = "WAV"
    case ogg = "OGG"
    case unknown = "UNKNOWN"
}

// MARK: - Artist Model

public struct Artist: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let imageURL: URL?
    public let biography: String?
    public let genres: [String]
    
    public init(
        id: String,
        name: String,
        imageURL: URL? = nil,
        biography: String? = nil,
        genres: [String] = []
    ) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.biography = biography
        self.genres = genres
    }
}

// MARK: - Album Model

public struct Album: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let artist: Artist?
    public let artistName: String
    public let coverURL: URL?
    public let releaseDate: Date?
    public let trackCount: Int
    public let duration: TimeInterval
    public let quality: AudioQuality
    public let genres: [String]
    public let tracks: [Track]?
    
    public init(
        id: String,
        title: String,
        artist: Artist? = nil,
        artistName: String,
        coverURL: URL? = nil,
        releaseDate: Date? = nil,
        trackCount: Int = 0,
        duration: TimeInterval = 0,
        quality: AudioQuality = .lossless,
        genres: [String] = [],
        tracks: [Track]? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artistName = artistName
        self.coverURL = coverURL
        self.releaseDate = releaseDate
        self.trackCount = trackCount
        self.duration = duration
        self.quality = quality
        self.genres = genres
        self.tracks = tracks
    }
}

// MARK: - Track Model

public struct Track: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let artist: Artist?
    public let artistName: String
    public let artistId: String?
    public let album: String?
    public let albumId: String?
    public let albumCover: URL?
    public let trackNumber: Int?
    public let discNumber: Int?
    public let duration: TimeInterval
    public let quality: AudioQuality
    public let explicit: Bool
    public let moduleId: String
    
    public init(
        id: String,
        title: String,
        artist: Artist? = nil,
        artistName: String,
        artistId: String? = nil,
        album: String? = nil,
        albumId: String? = nil,
        albumCover: URL? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        duration: TimeInterval = 0,
        quality: AudioQuality = .lossless,
        explicit: Bool = false,
        moduleId: String
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artistName = artistName
        self.artistId = artistId
        self.album = album
        self.albumId = albumId
        self.albumCover = albumCover
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.duration = duration
        self.quality = quality
        self.explicit = explicit
        self.moduleId = moduleId
    }
    
    /// Formatted duration string (MM:SS)
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Stream Info Model

public struct StreamInfo: Codable, Sendable {
    public let url: URL
    public let codec: AudioCodec
    public let container: AudioContainer
    public let sampleRate: Int          // Hz (e.g., 44100, 96000)
    public let bitDepth: Int            // bits (e.g., 16, 24)
    public let bitrate: Int?            // kbps for lossy formats
    public let quality: AudioQuality
    public let expiry: Date?            // URL expiration time
    public let manifestType: ManifestType
    public let trackId: String
    
    public enum ManifestType: String, Codable, Sendable {
        case direct = "DIRECT"          // Direct file URL
        case hls = "HLS"                // HLS manifest
        case dash = "DASH"              // DASH manifest
    }
    
    public init(
        url: URL,
        codec: AudioCodec = .flac,
        container: AudioContainer = .flac,
        sampleRate: Int = 44100,
        bitDepth: Int = 16,
        bitrate: Int? = nil,
        quality: AudioQuality = .lossless,
        expiry: Date? = nil,
        manifestType: ManifestType = .direct,
        trackId: String
    ) {
        self.url = url
        self.codec = codec
        self.container = container
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.bitrate = bitrate
        self.quality = quality
        self.expiry = expiry
        self.manifestType = manifestType
        self.trackId = trackId
    }
    
    /// Formatted quality badge (e.g., "24-bit/96kHz FLAC")
    public var qualityBadge: String {
        if codec.lossless {
            let sampleRateKHz = sampleRate >= 1000 ? "\(sampleRate / 1000)kHz" : "\(sampleRate)Hz"
            return "\(bitDepth)-bit/\(sampleRateKHz) \(codec.rawValue)"
        } else {
            return "\(bitrate ?? 0)kbps \(codec.rawValue)"
        }
    }
    
    /// Check if stream URL is still valid
    public var isExpired: Bool {
        guard let expiry = expiry else { return false }
        return Date() > expiry
    }
}

// MARK: - Search Results

public struct SearchResults: Sendable {
    public let tracks: [Track]
    public let albums: [Album]
    public let artists: [Artist]
    public let totalTracks: Int
    public let totalAlbums: Int
    public let totalArtists: Int
    
    public init(
        tracks: [Track] = [],
        albums: [Album] = [],
        artists: [Artist] = [],
        totalTracks: Int = 0,
        totalAlbums: Int = 0,
        totalArtists: Int = 0
    ) {
        self.tracks = tracks
        self.albums = albums
        self.artists = artists
        self.totalTracks = totalTracks
        self.totalAlbums = totalAlbums
        self.totalArtists = totalArtists
    }
    
    public static let empty = SearchResults()
}

// MARK: - Module Errors

public enum ModuleError: LocalizedError, Sendable {
    case notAuthenticated
    case authenticationFailed(String)
    case networkError(String)
    case streamNotAvailable
    case streamExpired
    case qualityNotAvailable(AudioQuality)
    case trackNotFound(String)
    case albumNotFound(String)
    case artistNotFound(String)
    case rateLimited(retryAfter: TimeInterval?)
    case moduleDisabled
    case securityViolation(String)
    case invalidResponse(String)
    case invalidFormat(String)
    case notImplemented
    case executionFailed(String)
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Authentication required"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .streamNotAvailable:
            return "Stream not available"
        case .streamExpired:
            return "Stream URL has expired"
        case .qualityNotAvailable(let quality):
            return "\(quality.displayName) quality not available"
        case .trackNotFound(let id):
            return "Track not found: \(id)"
        case .albumNotFound(let id):
            return "Album not found: \(id)"
        case .artistNotFound(let id):
            return "Artist not found: \(id)"
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Rate limited. Retry after \(Int(retry)) seconds"
            }
            return "Rate limited. Please try again later"
        case .moduleDisabled:
            return "Module is disabled"
        case .securityViolation(let reason):
            return "Security violation: \(reason)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .invalidFormat(let message):
            return "Invalid format: \(message)"
        case .notImplemented:
            return "Not implemented"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Queue Item

public struct QueueItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let track: Track
    public var streamInfo: StreamInfo?
    public var isPlaying: Bool
    
    public init(track: Track, streamInfo: StreamInfo? = nil, isPlaying: Bool = false) {
        self.id = UUID()
        self.track = track
        self.streamInfo = streamInfo
        self.isPlaying = isPlaying
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: QueueItem, rhs: QueueItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Download Item

public struct DownloadItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let track: Track
    public let quality: AudioQuality
    public var progress: Double
    public var status: DownloadStatus
    public var localURL: URL?
    public var error: String?
    public var startedAt: Date
    public var completedAt: Date?
    
    public enum DownloadStatus: String, Codable, Sendable {
        case pending
        case downloading
        case paused
        case completed
        case failed
        case cancelled
    }
    
    public init(
        track: Track,
        quality: AudioQuality = .lossless,
        progress: Double = 0,
        status: DownloadStatus = .pending
    ) {
        self.id = UUID()
        self.track = track
        self.quality = quality
        self.progress = progress
        self.status = status
        self.startedAt = Date()
    }
}

// MARK: - Library Item

public struct LibraryItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let type: ItemType
    public let trackId: String?
    public let albumId: String?
    public let artistId: String?
    public let moduleId: String
    public var addedAt: Date
    public var lastPlayedAt: Date?
    public var playCount: Int
    
    public enum ItemType: String, Codable, Sendable {
        case track
        case album
        case artist
        case playlist
    }
    
    public init(
        type: ItemType,
        trackId: String? = nil,
        albumId: String? = nil,
        artistId: String? = nil,
        moduleId: String
    ) {
        self.id = UUID()
        self.type = type
        self.trackId = trackId
        self.albumId = albumId
        self.artistId = artistId
        self.moduleId = moduleId
        self.addedAt = Date()
        self.playCount = 0
    }
}

// MARK: - Playlist Model

public struct Playlist: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var tracks: [Track]
    public var createdAt: Date
    public var description: String?
    
    public init(id: UUID = UUID(), name: String, tracks: [Track] = [], description: String? = nil) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.createdAt = Date()
        self.description = description
    }
}
