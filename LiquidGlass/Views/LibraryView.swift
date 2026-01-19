import SwiftUI

// MARK: - Library View

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @EnvironmentObject var player: AudioPlayer
    
    @State private var showCreatePlaylist = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfacePrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Quick Access
                        quickAccessSection
                        
                        // Recent
                        if !viewModel.recentTracks.isEmpty {
                            recentSection
                        }
                        
                        // Playlists
                        playlistsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Library")
            .alert("New Playlist", isPresented: $showCreatePlaylist) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    viewModel.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
        }
    }
    
    // MARK: - Quick Access
    private var quickAccessSection: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            QuickAccessCard(icon: "heart.fill", title: "Liked Songs", color: Color.accentGlow)
            QuickAccessCard(icon: "clock.fill", title: "Recently Played", color: Color.accentSecondary)
            QuickAccessCard(icon: "arrow.down.circle.fill", title: "Downloads", color: .green)
            QuickAccessCard(icon: "music.note.list", title: "Playlists", color: .orange)
        }
    }
    
    // MARK: - Recent Section
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recently Played")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(viewModel.recentTracks) { track in
                        RecentTrackCard(track: track) {
                            Task { await player.playNow([track]) }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Playlists Section
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Playlists")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showCreatePlaylist = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(GlassTheme.cyan)
                }
            }
            
            if viewModel.playlists.isEmpty {
                 Text("No playlists yet")
                    .font(.subheadline)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.playlists) { playlist in
                        PlaylistRow(
                            title: playlist.name,
                            trackCount: playlist.tracks.count,
                            imageURL: nil
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deletePlaylist(id: playlist.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Quick Access Card
struct QuickAccessCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(16)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Recent Track Card
struct RecentTrackCard: View {
    let track: Track
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                BlurredAsyncImage(url: track.albumCover, cornerRadius: 12)
                    .frame(width: 140, height: 140)
                
                Text(track.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(track.artistName)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 140)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Playlist Row
struct PlaylistRow: View {
    let title: String
    let trackCount: Int
    let imageURL: URL?
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surfaceSecondary)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "music.note.list")
                        .foregroundStyle(Color.textTertiary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                
                Text("\(trackCount) tracks")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.textTertiary)
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Library View Model
@MainActor
class LibraryViewModel: ObservableObject {
    @Published var recentTracks: [Track] = []
    @Published var likedTracks: [Track] = []
    @Published var playlists: [Playlist] = []
    @Published var isLoading = false
    
    private let userDefaults = UserDefaults.standard
    private let playlistsKey = "user.playlists"
    
    init() {
        loadLibrary()
    }
    
    func loadLibrary() {
        // Load Playlists
        if let data = userDefaults.data(forKey: playlistsKey),
           let savedPlaylists = try? JSONDecoder().decode([Playlist].self, from: data) {
            self.playlists = savedPlaylists
        }
    }
    
    func createPlaylist(name: String) {
        let newPlaylist = Playlist(name: name)
        playlists.append(newPlaylist)
        savePlaylists()
    }
    
    func deletePlaylist(id: UUID) {
        playlists.removeAll { $0.id == id }
        savePlaylists()
    }
    
    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            userDefaults.set(data, forKey: playlistsKey)
        }
    }
}
