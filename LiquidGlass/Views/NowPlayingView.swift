import SwiftUI

// MARK: - Now Playing View
/// Full-screen player with glassmorphism design

struct NowPlayingView: View {
    @EnvironmentObject var player: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var showQueue = false
    @State private var sliderValue: Double = 0
    @State private var isSliding = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                if let url = player.currentTrack?.albumCover {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .blur(radius: 80)
                            .overlay(Color.black.opacity(0.6))
                    } placeholder: {
                        GlassTheme.black
                    }
                } else {
                    GlassTheme.black
                }
                
                // Content
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            Text("PLAYING FROM")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .tracking(1)
                            Text(player.currentTrack?.album ?? "Library")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Button { } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, geometry.safeAreaInsets.top + 16)
                    
                    Spacer(minLength: 20)
                    
                    // Album Art
                    let artSize = min(geometry.size.width - 64, 380)
                    ZStack {
                        // Shadow
                        if let url = player.currentTrack?.albumCover {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: artSize * 0.9, height: artSize * 0.9)
                                    .blur(radius: 40)
                                    .opacity(0.5)
                                    .offset(y: 30)
                            } placeholder: { Color.clear }
                        }
                        
                        BlurredAsyncImage(url: player.currentTrack?.albumCover, cornerRadius: 24)
                            .frame(width: artSize, height: artSize)
                            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    }
                    
                    Spacer(minLength: 32)
                    
                    // Track Info
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(player.currentTrack?.title ?? "Not Playing")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                Text(player.currentTrack?.artistName ?? "Select a song")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                            Spacer()
                            
                            if let streamInfo = player.streamInfo {
                                QualityBadge(quality: streamInfo.qualityBadge, isHighlighted: true)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Progress
                    VStack(spacing: 12) {
                        Slider(
                             value: Binding(
                                 get: { isSliding ? sliderValue : player.currentTime },
                                 set: { sliderValue = $0 }
                             ),
                             in: 0...max(1, player.duration)
                        ) { editing in
                             isSliding = editing
                             if !editing { player.seek(to: sliderValue) }
                        }
                        .tint(GlassTheme.cyan)
                        
                        HStack {
                            Text(formatTime(isSliding ? sliderValue : player.currentTime))
                            Spacer()
                            Text(formatTime(player.duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 32)
                    
                    // Controls
                    HStack(spacing: 32) {
                        GlassButton(icon: "shuffle", size: 40, isActive: player.shuffleEnabled) {
                            player.shuffleEnabled.toggle()
                        }
                        
                        GlassButton(icon: "backward.fill", size: 56) {
                            Task { await player.previous() }
                        }
                        
                        PlayButton(isPlaying: player.isPlaying, size: 88) {
                            player.togglePlayPause()
                        }
                        
                        GlassButton(icon: "forward.fill", size: 56) {
                            Task { await player.next() }
                        }
                        
                        GlassButton(
                            icon: player.repeatMode == .one ? "repeat.1" : "repeat",
                            size: 40,
                            isActive: player.repeatMode != .off
                        ) {
                            cycleRepeatMode()
                        }
                    }
                    .padding(.top, 40)
                    
                    Spacer(minLength: 40)
                    
                    // Bottom Controls
                    HStack(spacing: 40) {
                        Button { } label: {
                            Image(systemName: "airplayaudio")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        Button { showQueue = true } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func cycleRepeatMode() {
        switch player.repeatMode {
        case .off: player.repeatMode = .all
        case .all: player.repeatMode = .one
        case .one: player.repeatMode = .off
        }
    }
}
