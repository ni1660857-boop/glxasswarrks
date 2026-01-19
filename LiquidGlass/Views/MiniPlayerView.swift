import SwiftUI

// MARK: - Mini Player View

struct MiniPlayerView: View {
    @EnvironmentObject var player: AudioPlayer
    @Binding var isExpanded: Bool
    
    var body: some View {
        if let track = player.currentTrack {
            Button {
                isExpanded = true
            } label: {
                HStack(spacing: 12) {
                    // Album art
                    BlurredAsyncImage(url: track.albumCover, cornerRadius: 8)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                    
                    // Track info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        Text(track.artistName)
                            .font(.system(size: 13))
                            .foregroundStyle(GlassTheme.gray)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 16) {
                        Button {
                            player.togglePlayPause()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        }
                        
                        Button {
                            Task { await player.next() }
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(GlassTheme.gray)
                        }
                    }
                    .padding(.trailing, 8)
                }
                .padding(10)
                .background(
                    GlassTheme.glass.opacity(0.9)
                )
                .background(
                    ZStack {
                        if let url = track.albumCover {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { Color.black }
                        } else { Color.black }
                    }
                    .blur(radius: 40)
                    .opacity(0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 15, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}

// MARK: - Waveform View (Standalone)

struct WaveformVisualizerView: View {
    @EnvironmentObject var player: AudioPlayer
    @State private var levels: [CGFloat] = Array(repeating: 0.3, count: 50)
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentGlow, Color.accentSecondary],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: 4 + levels[index] * 36)
            }
        }
        .frame(height: 44)
        .onReceive(timer) { _ in
            if player.isPlaying {
                withAnimation(.easeOut(duration: 0.1)) {
                    levels = levels.map { _ in CGFloat.random(in: 0.1...1.0) }
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    levels = levels.map { _ in 0.2 }
                }
            }
        }
    }
}
