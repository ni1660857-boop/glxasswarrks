import Foundation

// MARK: - Spotify Metadata Service
/// Enriches tracks with Spotify metadata (artwork, popularity, etc.)

public actor SpotifyMetadataService {
    public static let shared = SpotifyMetadataService()
    
    private let baseURL = "https://api.spotify.com/v1"
    private var accessToken: String?
    private var tokenExpiry: Date?
    
    // Client credentials - in production, these should be secured
    private let clientId = ""
    private let clientSecret = ""
    
    private init() {}
    
    // MARK: - Authentication
    public func authenticate() async throws {
        guard !clientId.isEmpty && !clientSecret.isEmpty else { return }
        
        let credentials = "\(clientId):\(clientSecret)"
        guard let data = credentials.data(using: .utf8) else { return }
        let base64 = data.base64EncodedString()
        
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
        
        let (data2, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data2)
        
        accessToken = response.access_token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(response.expires_in - 60))
    }
    
    // MARK: - Search
    public func search(query: String, type: String = "track", limit: Int = 10) async throws -> SpotifySearchResult {
        try await ensureAuthenticated()
        
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        var request = URLRequest(url: URL(string: "\(baseURL)/search?q=\(encoded)&type=\(type)&limit=\(limit)")!)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SpotifySearchResult.self, from: data)
    }
    
    private func ensureAuthenticated() async throws {
        if accessToken == nil || (tokenExpiry ?? .distantPast) < Date() {
            try await authenticate()
        }
    }
}

// MARK: - Response Models
private struct TokenResponse: Codable {
    let access_token: String
    let expires_in: Int
}

public struct SpotifySearchResult: Codable {
    public let tracks: SpotifyTracks?
}

public struct SpotifyTracks: Codable {
    public let items: [SpotifyTrack]
}

public struct SpotifyTrack: Codable {
    public let id: String
    public let name: String
    public let artists: [SpotifyArtist]
    public let album: SpotifyAlbum
    public let popularity: Int
}

public struct SpotifyArtist: Codable {
    public let id: String
    public let name: String
}

public struct SpotifyAlbum: Codable {
    public let id: String
    public let name: String
    public let images: [SpotifyImage]
}

public struct SpotifyImage: Codable {
    public let url: String
    public let width: Int?
    public let height: Int?
}
