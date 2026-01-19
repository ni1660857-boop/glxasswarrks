import SwiftUI

// MARK: - Queue View

struct QueueView: View {
    @EnvironmentObject var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfacePrimary.ignoresSafeArea()
                
                if player.queue.isEmpty {
                    emptyView
                } else {
                    queueList
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.accentGlow)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        player.queue.removeAll()
                    } label: {
                        Text("Clear")
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Queue List
    private var queueList: some View {
        ScrollViewReader { proxy in
            List {
                // Now Playing
                if player.currentIndex < player.queue.count {
                    Section {
                        nowPlayingRow
                    } header: {
                        Text("Now Playing")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Up Next
                if player.currentIndex < player.queue.count - 1 {
                    Section {
                        ForEach(Array(player.queue.dropFirst(player.currentIndex + 1).enumerated()), id: \.element.id) { offset, item in
                            queueRow(item: item, index: player.currentIndex + 1 + offset)
                        }
                        .onMove { from, to in
                            moveItems(from: from, to: to)
                        }
                        .onDelete { indexSet in
                            deleteItems(at: indexSet)
                        }
                    } header: {
                        Text("Up Next")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    // MARK: - Now Playing Row
    private var nowPlayingRow: some View {
        HStack(spacing: 12) {
            // Waveform indicator
            WaveformVisualizerView()
                .frame(width: 48, height: 48)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(player.queue[player.currentIndex].track.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentGlow)
                    .lineLimit(1)
                
                Text(player.queue[player.currentIndex].track.artistName)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Queue Row
    private func queueRow(item: QueueItem, index: Int) -> some View {
        Button {
            Task {
                if let idx = player.queue.firstIndex(where: { $0.id == item.id }) {
                    await player.playNow(player.queue.map { $0.track }, startIndex: idx)
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Album art
                BlurredAsyncImage(url: item.track.albumCover, cornerRadius: 6)
                    .frame(width: 48, height: 48)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.track.title)
                        .font(.body)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(item.track.artistName)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Duration
                Text(item.track.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.textTertiary)
                
                // Drag handle
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet")
                .font(.system(size: 64))
                .foregroundStyle(Color.textTertiary)
            
            Text("Queue is empty")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            
            Text("Add songs to see them here")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
    }
    
    // MARK: - Actions
    private func moveItems(from source: IndexSet, to destination: Int) {
        var newQueue = Array(player.queue.dropFirst(player.currentIndex + 1))
        newQueue.move(fromOffsets: source, toOffset: destination)
        
        // Rebuild queue
        let current = Array(player.queue.prefix(player.currentIndex + 1))
        player.queue = current + newQueue
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let startIndex = player.currentIndex + 1
        let actualOffsets = IndexSet(offsets.map { $0 + startIndex })
        player.queue.remove(atOffsets: actualOffsets)
    }
}
