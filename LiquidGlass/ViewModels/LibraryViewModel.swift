import Foundation

// MARK: - Library View Model

@MainActor
class LibraryViewModelImpl: ObservableObject {
    @Published var recentTracks: [Track] = []
    @Published var likedTracks: [Track] = []
    @Published var playlists: [Playlist] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let storageKey = "library"
    
    struct Playlist: Identifiable, Codable {
        let id: UUID
        var name: String
        var tracks: [Track]
        var createdAt: Date
        var updatedAt: Date
        
        init(name: String, tracks: [Track] = []) {
            self.id = UUID()
            self.name = name
            self.tracks = tracks
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
    
    init() {
        loadLibrary()
    }
    
    // MARK: - Loading
    
    func loadLibrary() {
        loadRecentTracks()
        loadLikedTracks()
        loadPlaylists()
    }
    
    private func loadRecentTracks() {
        if let data = UserDefaults.standard.data(forKey: "\(storageKey).recent"),
           let tracks = try? JSONDecoder().decode([Track].self, from: data) {
            recentTracks = tracks
        }
    }
    
    private func loadLikedTracks() {
        if let data = UserDefaults.standard.data(forKey: "\(storageKey).liked"),
           let tracks = try? JSONDecoder().decode([Track].self, from: data) {
            likedTracks = tracks
        }
    }
    
    private func loadPlaylists() {
        if let data = UserDefaults.standard.data(forKey: "\(storageKey).playlists"),
           let lists = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = lists
        }
    }
    
    // MARK: - Recent Tracks
    
    func addToRecent(_ track: Track) {
        // Remove if exists
        recentTracks.removeAll { $0.id == track.id }
        
        // Add to front
        recentTracks.insert(track, at: 0)
        
        // Limit to 50
        if recentTracks.count > 50 {
            recentTracks = Array(recentTracks.prefix(50))
        }
        
        saveRecentTracks()
    }
    
    private func saveRecentTracks() {
        if let data = try? JSONEncoder().encode(recentTracks) {
            UserDefaults.standard.set(data, forKey: "\(storageKey).recent")
        }
    }
    
    // MARK: - Liked Tracks
    
    func toggleLike(_ track: Track) {
        if let index = likedTracks.firstIndex(where: { $0.id == track.id }) {
            likedTracks.remove(at: index)
        } else {
            likedTracks.insert(track, at: 0)
        }
        saveLikedTracks()
    }
    
    func isLiked(_ track: Track) -> Bool {
        likedTracks.contains { $0.id == track.id }
    }
    
    private func saveLikedTracks() {
        if let data = try? JSONEncoder().encode(likedTracks) {
            UserDefaults.standard.set(data, forKey: "\(storageKey).liked")
        }
    }
    
    // MARK: - Playlists
    
    func createPlaylist(name: String) -> Playlist {
        let playlist = Playlist(name: name)
        playlists.insert(playlist, at: 0)
        savePlaylists()
        return playlist
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }
    
    func addToPlaylist(_ track: Track, playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        // Don't add duplicates
        guard !playlists[index].tracks.contains(where: { $0.id == track.id }) else { return }
        
        playlists[index].tracks.append(track)
        playlists[index].updatedAt = Date()
        savePlaylists()
    }
    
    func removeFromPlaylist(_ track: Track, playlist: Playlist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        
        playlists[index].tracks.removeAll { $0.id == track.id }
        playlists[index].updatedAt = Date()
        savePlaylists()
    }
    
    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: "\(storageKey).playlists")
        }
    }
}
