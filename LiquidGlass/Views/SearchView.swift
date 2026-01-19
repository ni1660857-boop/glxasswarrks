import SwiftUI

// MARK: - Search View

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @EnvironmentObject var player: AudioPlayer
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfacePrimary.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Content
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.results.tracks.isEmpty && !viewModel.query.isEmpty {
                        emptyView
                    } else if !viewModel.results.tracks.isEmpty {
                        resultsList
                    } else {
                        placeholderView
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)
            
            TextField("Songs, artists, albums", text: $viewModel.query)
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { Task { await viewModel.search() } }
            
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
        .onChange(of: viewModel.query) { _ in
            Task { await viewModel.debounceSearch() }
        }
    }
    
    // MARK: - Results List
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.results.tracks) { track in
                    TrackRow(track: track) {
                        Task {
                            await player.playNow([track])
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            GlassLoadingIndicator()
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .padding(.top, 16)
            Spacer()
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)
            Text("No results found")
                .font(.headline)
                .foregroundStyle(Color.textSecondary)
            Text("Try different keywords")
                .font(.subheadline)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
    }
    
    // MARK: - Placeholder View
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.and.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentGlow, Color.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Search for music")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Find your favorite songs and artists")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Track Row
struct TrackRow: View {
    let track: Track
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Album art
                BlurredAsyncImage(url: track.albumCover, cornerRadius: 8)
                    .frame(width: 56, height: 56)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(track.artistName)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Quality & duration
                VStack(alignment: .trailing, spacing: 4) {
                    QualityBadge(quality: track.quality.badge)
                    
                    Text(track.formattedDuration)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .padding(12)
            .glassCard(cornerRadius: 12)
        }
        .buttonStyle(ScaleButtonStyle())
        .contextMenu {
            Button {
                Task {
                    await DownloadsManager.shared.startDownload(track)
                }
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            
            Button {
                // Future: Add to playlist
            } label: {
                Label("Add to Playlist", systemImage: "plus.circle")
            }
        }
    }
}

// MARK: - Search View Model
@MainActor
class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results = SearchResults.empty
    @Published var isLoading = false
    @Published var error: Error?
    
    private let hifiAPI = HiFiAPI.shared
    private var searchTask: Task<Void, Never>?
    
    func search() async {
        guard !query.isEmpty else {
            results = .empty
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            results = try await hifiAPI.search(query: query)
        } catch {
            self.error = error
            results = .empty
        }
        
        isLoading = false
    }
    
    func debounceSearch() async {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if !Task.isCancelled {
                await search()
            }
        }
    }
}
