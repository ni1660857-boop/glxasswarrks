import Foundation
import AVFoundation
import MediaPlayer
import Combine

// MARK: - Audio Player

@MainActor
public final class AudioPlayer: NSObject, ObservableObject {
    public static let shared = AudioPlayer()
    
    // MARK: - Published State
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var duration: TimeInterval = 0
    @Published public private(set) var isBuffering: Bool = false
    @Published public private(set) var bufferProgress: Double = 0
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var streamInfo: StreamInfo?
    @Published public private(set) var error: Error?
    @Published public var queue: [QueueItem] = []
    @Published public private(set) var currentIndex: Int = 0
    @Published public var volume: Float = 1.0 { didSet { player?.volume = volume } }
    @Published public var repeatMode: RepeatMode = .off
    @Published public var shuffleEnabled: Bool = false
    
    public enum RepeatMode { case off, all, one }
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private let hifiAPI = HiFiAPI.shared
    
    // MARK: - Audio Session
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommands()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in 
            Task { @MainActor in self?.play() }
            return .success 
        }
        center.pauseCommand.addTarget { [weak self] _ in 
            Task { @MainActor in self?.pause() }
            return .success 
        }
        center.nextTrackCommand.addTarget { [weak self] _ in 
            Task { @MainActor in await self?.next() }
            return .success 
        }
        center.previousTrackCommand.addTarget { [weak self] _ in 
            Task { @MainActor in await self?.previous() }
            return .success 
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent { 
                Task { @MainActor in self?.seek(to: e.positionTime) }
            }
            return .success
        }
    }
    
    // MARK: - Playback Control
    public func play(track: Track) async {
        currentTrack = track
        isBuffering = true
        error = nil
        
        do {
            let stream = try await hifiAPI.resolveStream(track: track)
            streamInfo = stream
            await playStream(stream)
        } catch {
            self.error = error
            isBuffering = false
        }
    }
    
    private func playStream(_ stream: StreamInfo) async {
        cleanupPlayer()
        
        let asset = AVURLAsset(url: stream.url)
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume
        
        // Observe status
        playerItem?.publisher(for: \.status).sink { [weak self] status in
            guard let self = self else { return }
            switch status {
            case .readyToPlay:
                self.isBuffering = false
                self.duration = self.playerItem?.duration.seconds ?? 0
                self.player?.play()
                self.isPlaying = true
                self.updateNowPlayingInfo()
            case .failed:
                self.error = self.playerItem?.error
                self.isBuffering = false
            default: break
            }
        }.store(in: &cancellables)
        
        // Time observer
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                self?.updateNowPlayingInfo()
            }
        }
        
        // End notification
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in Task { await self?.handlePlaybackEnd() } }
            .store(in: &cancellables)
    }
    
    public func play() { player?.play(); isPlaying = true }
    public func pause() { player?.pause(); isPlaying = false }
    public func togglePlayPause() { isPlaying ? pause() : play() }
    
    public func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
    
    public func next() async {
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex + 1) % queue.count
        let track = queue[currentIndex].track
        await play(track: track)
    }
    
    public func previous() async {
        if currentTime > 3 { seek(to: 0); return }
        guard !queue.isEmpty else { return }
        currentIndex = currentIndex > 0 ? currentIndex - 1 : queue.count - 1
        let track = queue[currentIndex].track
        await play(track: track)
    }
    
    public func addToQueue(_ track: Track) {
        queue.append(QueueItem(track: track))
    }
    
    public func playNow(_ tracks: [Track], startIndex: Int = 0) async {
        queue = tracks.map { QueueItem(track: $0) }
        currentIndex = startIndex
        if !queue.isEmpty {
            let track = queue[currentIndex].track
            await play(track: track)
        }
    }
    
    private func handlePlaybackEnd() async {
        switch repeatMode {
        case .one: seek(to: 0); play()
        case .all, .off: await next()
        }
    }
    
    private func cleanupPlayer() {
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        cancellables.removeAll()
        player?.pause()
        player = nil
        playerItem = nil
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artistName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let album = track.album { info[MPMediaItemPropertyAlbumTitle] = album }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
