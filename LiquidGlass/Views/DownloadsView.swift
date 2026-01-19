import SwiftUI

// MARK: - Downloads View

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @EnvironmentObject var player: AudioPlayer
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfacePrimary.ignoresSafeArea()
                
                if viewModel.downloads.isEmpty {
                    emptyView
                } else {
                    downloadsList
                }
            }
            .navigationTitle("Downloads")
        }
    }
    
    // MARK: - Downloads List
    private var downloadsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Storage info
                storageCard
                
                // Downloads
                ForEach(viewModel.downloads) { item in
                    DownloadRow(item: item)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Storage Card
    private var storageCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Storage Used")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text(viewModel.formattedStorageUsed)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentGlow)
            }
            
            // Progress bar
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentGlow, Color.accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * viewModel.storageProgress)
                    }
            }
            .frame(height: 8)
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentGlow, Color.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No Downloads")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("Download songs to listen offline")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - Download Row
struct DownloadRow: View {
    let item: DownloadItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Album art
            BlurredAsyncImage(url: item.track.albumCover, cornerRadius: 8)
                .frame(width: 56, height: 56)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.track.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(item.track.artistName)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                
                if item.status == .downloading {
                    ProgressView(value: item.progress)
                        .tint(Color.accentGlow)
                }
            }
            
            Spacer()
            
            // Status
            statusIcon
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .downloading:
            Text("\(Int(item.progress * 100))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentGlow)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.orange)
        case .pending:
            Image(systemName: "clock.fill")
                .foregroundStyle(Color.textTertiary)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color.textTertiary)
        }
    }
}

// MARK: - Downloads View Model
@MainActor
class DownloadsViewModel: ObservableObject {
    @Published var downloads: [DownloadItem] = []
    @Published var storageUsed: Int64 = 0
    @Published var storageLimit: Int64 = 10 * 1024 * 1024 * 1024 // 10GB
    
    var storageProgress: Double {
        Double(storageUsed) / Double(storageLimit)
    }
    
    var formattedStorageUsed: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: storageUsed) + " / " + formatter.string(fromByteCount: storageLimit)
    }
    
    init() {
        loadDownloads()
    }
    
    func loadDownloads() {
        // Load from storage
    }
}
