import XCTest
@testable import LiquidGlass

final class ModelsTests: XCTestCase {
    
    // MARK: - Track Tests
    
    func testTrackFormattedDuration() {
        let track = Track(
            id: "test-1",
            title: "Test Track",
            artistName: "Test Artist",
            duration: 185, // 3:05
            moduleId: "test-module"
        )
        
        XCTAssertEqual(track.formattedDuration, "3:05")
    }
    
    func testTrackFormattedDurationZero() {
        let track = Track(
            id: "test-2",
            title: "Test Track",
            artistName: "Test Artist",
            duration: 0,
            moduleId: "test-module"
        )
        
        XCTAssertEqual(track.formattedDuration, "0:00")
    }
    
    func testTrackFormattedDurationLong() {
        let track = Track(
            id: "test-3",
            title: "Test Track",
            artistName: "Test Artist",
            duration: 3723, // 62:03
            moduleId: "test-module"
        )
        
        XCTAssertEqual(track.formattedDuration, "62:03")
    }
    
    // MARK: - AudioQuality Tests
    
    func testAudioQualityPriority() {
        XCTAssertLessThan(AudioQuality.low.priority, AudioQuality.normal.priority)
        XCTAssertLessThan(AudioQuality.normal.priority, AudioQuality.high.priority)
        XCTAssertLessThan(AudioQuality.high.priority, AudioQuality.lossless.priority)
        XCTAssertLessThan(AudioQuality.lossless.priority, AudioQuality.hiRes.priority)
        XCTAssertLessThan(AudioQuality.hiRes.priority, AudioQuality.master.priority)
    }
    
    func testAudioQualityBadge() {
        XCTAssertEqual(AudioQuality.lossless.badge, "FLAC")
        XCTAssertEqual(AudioQuality.high.badge, "AAC 320")
        XCTAssertEqual(AudioQuality.master.badge, "Master")
    }
    
    // MARK: - StreamInfo Tests
    
    func testStreamInfoQualityBadgeLossless() {
        let stream = StreamInfo(
            url: URL(string: "https://example.com/stream.flac")!,
            codec: .flac,
            container: .flac,
            sampleRate: 96000,
            bitDepth: 24,
            quality: .hiRes,
            trackId: "test"
        )
        
        XCTAssertEqual(stream.qualityBadge, "24-bit/96kHz FLAC")
    }
    
    func testStreamInfoQualityBadgeLossy() {
        let stream = StreamInfo(
            url: URL(string: "https://example.com/stream.m4a")!,
            codec: .aac,
            container: .m4a,
            sampleRate: 44100,
            bitDepth: 16,
            bitrate: 320,
            quality: .high,
            trackId: "test"
        )
        
        XCTAssertEqual(stream.qualityBadge, "320kbps AAC")
    }
    
    func testStreamInfoNotExpired() {
        let stream = StreamInfo(
            url: URL(string: "https://example.com/stream.flac")!,
            expiry: Date().addingTimeInterval(3600),
            trackId: "test"
        )
        
        XCTAssertFalse(stream.isExpired)
    }
    
    func testStreamInfoExpired() {
        let stream = StreamInfo(
            url: URL(string: "https://example.com/stream.flac")!,
            expiry: Date().addingTimeInterval(-60),
            trackId: "test"
        )
        
        XCTAssertTrue(stream.isExpired)
    }
    
    func testStreamInfoNoExpiry() {
        let stream = StreamInfo(
            url: URL(string: "https://example.com/stream.flac")!,
            expiry: nil,
            trackId: "test"
        )
        
        XCTAssertFalse(stream.isExpired)
    }
    
    // MARK: - AudioCodec Tests
    
    func testAudioCodecLossless() {
        XCTAssertTrue(AudioCodec.flac.lossless)
        XCTAssertTrue(AudioCodec.alac.lossless)
        XCTAssertTrue(AudioCodec.mqa.lossless)
        XCTAssertFalse(AudioCodec.aac.lossless)
        XCTAssertFalse(AudioCodec.mp3.lossless)
    }
    
    // MARK: - SearchResults Tests
    
    func testSearchResultsEmpty() {
        let results = SearchResults.empty
        
        XCTAssertTrue(results.tracks.isEmpty)
        XCTAssertTrue(results.albums.isEmpty)
        XCTAssertTrue(results.artists.isEmpty)
        XCTAssertEqual(results.totalTracks, 0)
    }
    
    // MARK: - ModuleError Tests
    
    func testModuleErrorDescriptions() {
        XCTAssertNotNil(ModuleError.notAuthenticated.errorDescription)
        XCTAssertNotNil(ModuleError.streamNotAvailable.errorDescription)
        XCTAssertNotNil(ModuleError.rateLimited(retryAfter: 30).errorDescription)
        XCTAssertNotNil(ModuleError.securityViolation("test").errorDescription)
    }
}
