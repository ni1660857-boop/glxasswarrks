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
                // Blurred album art background
                if let url = player.currentTrack?.albumCover {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .blur(radius: 60)
                            .overlay(Color.black.opacity(0.4))
                    } placeholder: {
                        Color.surfacePrimary
                    }
                } else {
                    Color.surfacePrimary
                }
                
                // Content
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    Spacer()
                    
                    // Album Art
                    albumArtView(geometry: geometry)
                    
                    Spacer()
                    
                    // Track Info
                    trackInfoView
                    
                    // Progress
                    progressView
                        .padding(.top, 24)
                    
                    // Controls
                    controlsView
                        .padding(.top, 24)
                    
                    // Extra Controls
                    extraControlsView
                        .padding(.top, 16)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
        .onChange(of: player.currentTime) { newValue in
            if !isSliding {
                sliderValue = newValue
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("PLAYING FROM")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
                
                Text(player.currentTrack?.album ?? "Library")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Button {
                // More options
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 60)
    }
    
    // MARK: - Album Art
    private func albumArtView(geometry: GeometryProxy) -> some View {
        let size = min(geometry.size.width - 48, 340)
        
        return ZStack {
            // Shadow/glow
            if let url = player.currentTrack?.albumCover {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .blur(radius: 40)
                        .opacity(0.6)
                        .offset(y: 20)
                } placeholder: {
                    Color.clear
                }
            }
            
            // Main artwork
            BlurredAsyncImage(url: player.currentTrack?.albumCover, cornerRadius: 16)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.4), radius: 30, y: 20)
        }
    }
    
    // MARK: - Track Info
    private var trackInfoView: some View {
        VStack(spacing: 8) {
            // Quality badge
            if let streamInfo = player.streamInfo {
                QualityBadge(quality: streamInfo.qualityBadge, isHighlighted: true)
            }
            
            // Title
            Text(player.currentTrack?.title ?? "Not Playing")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            // Artist
            Text(player.currentTrack?.artistName ?? "")
                .font(.body)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.top, 24)
    }
    
    // MARK: - Progress
    private var progressView: some View {
        VStack(spacing: 8) {
            GlassSlider(
                value: Binding(
                    get: { sliderValue },
                    set: { sliderValue = $0 }
                ),
                range: 0...max(1, player.duration),
                onEditingChanged: { editing in
                    isSliding = editing
                    if !editing {
                        player.seek(to: sliderValue)
                    }
                }
            )
            
            HStack {
                Text(formatTime(sliderValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.textSecondary)
                
                Spacer()
                
                Text(formatTime(player.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
    
    // MARK: - Controls
    private var controlsView: some View {
        HStack(spacing: 24) {
            // Shuffle
            GlassButton(icon: "shuffle", size: 44, isActive: player.shuffleEnabled) {
                player.shuffleEnabled.toggle()
            }
            
            // Previous
            GlassButton(icon: "backward.fill", size: 56) {
                Task { await player.previous() }
            }
            
            // Play/Pause
            PlayButton(isPlaying: player.isPlaying, size: 80) {
                player.togglePlayPause()
            }
            
            // Next
            GlassButton(icon: "forward.fill", size: 56) {
                Task { await player.next() }
            }
            
            // Repeat
            GlassButton(
                icon: player.repeatMode == .one ? "repeat.1" : "repeat",
                size: 44,
                isActive: player.repeatMode != .off
            ) {
                cycleRepeatMode()
            }
        }
    }
    
    // MARK: - Extra Controls
    private var extraControlsView: some View {
        HStack(spacing: 40) {
            // AirPlay
            Button {
                // AirPlay picker
            } label: {
                Image(systemName: "airplayaudio")
                    .font(.title3)
                    .foregroundStyle(Color.textSecondary)
            }
            
            // Queue
            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(Color.textSecondary)
            }
            
            // Volume
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                
                Slider(value: $player.volume, in: 0...1)
                    .tint(Color.accentGlow)
                    .frame(width: 100)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }
    
    // MARK: - Helpers
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
