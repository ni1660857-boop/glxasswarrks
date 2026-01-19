import Foundation
import Combine
import AVFoundation

// MARK: - Player View Model

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var currentTrack: Track?
    @Published var streamInfo: StreamInfo?
    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var error: Error?
    
    @Published var queue: [QueueItem] = []
    @Published var currentIndex = 0
    @Published var repeatMode: AudioPlayer.RepeatMode = .off
    @Published var shuffleEnabled = false
    @Published var volume: Float = 1.0
    
    private let player = AudioPlayer.shared
    private let hifiAPI = HiFiAPI.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        bindToPlayer()
    }
    
    private func bindToPlayer() {
        player.$currentTrack.assign(to: &$currentTrack)
        player.$streamInfo.assign(to: &$streamInfo)
        player.$isPlaying.assign(to: &$isPlaying)
        player.$isBuffering.assign(to: &$isBuffering)
        player.$currentTime.assign(to: &$currentTime)
        player.$duration.assign(to: &$duration)
        player.$error.assign(to: &$error)
        player.$queue.assign(to: &$queue)
        player.$currentIndex.assign(to: &$currentIndex)
        player.$repeatMode.assign(to: &$repeatMode)
        player.$shuffleEnabled.assign(to: &$shuffleEnabled)
        player.$volume.assign(to: &$volume)
    }
    
    // MARK: - Playback Controls
    
    func play() { player.play() }
    func pause() { player.pause() }
    func togglePlayPause() { player.togglePlayPause() }
    
    func seek(to time: TimeInterval) {
        player.seek(to: time)
    }
    
    func next() async {
        await player.next()
    }
    
    func previous() async {
        await player.previous()
    }
    
    func playTrack(_ track: Track) async {
        await player.play(track: track)
    }
    
    func playTracks(_ tracks: [Track], startIndex: Int = 0) async {
        await player.playNow(tracks, startIndex: startIndex)
    }
    
    func addToQueue(_ track: Track) {
        player.addToQueue(track)
    }
    
    // MARK: - Settings
    
    func setVolume(_ volume: Float) {
        player.volume = volume
    }
    
    func toggleShuffle() {
        player.shuffleEnabled.toggle()
    }
    
    func cycleRepeatMode() {
        switch player.repeatMode {
        case .off: player.repeatMode = .all
        case .all: player.repeatMode = .one
        case .one: player.repeatMode = .off
        }
    }
}
