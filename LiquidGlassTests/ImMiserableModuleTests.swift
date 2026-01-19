import XCTest
@testable import LiquidGlass

final class ImMiserableModuleTests: XCTestCase {
    
    var module: ImMiserableModule!
    
    override func setUp() async throws {
        module = ImMiserableModule()
    }
    
    // MARK: - Module Identity Tests
    
    func testModuleId() async {
        let id = await module.id
        XCTAssertEqual(id, "im-miserable")
    }
    
    func testModuleName() async {
        let name = await module.name
        XCTAssertEqual(name, "Im Miserable")
    }
    
    func testModuleVersion() async {
        let version = await module.version
        XCTAssertEqual(version, "1.0.0")
    }
    
    func testModuleAllowedDomains() async {
        let domains = await module.allowedDomains
        XCTAssertTrue(domains.contains("tidal.kinoplus.online"))
        XCTAssertTrue(domains.contains("resources.tidal.com"))
    }
    
    func testModuleLabels() async {
        let labels = await module.labels
        XCTAssertTrue(labels.contains("High Quality"))
        XCTAssertTrue(labels.contains("Lossless"))
    }
    
    func testModuleNoAuthRequired() async {
        let requiresAuth = await module.requiresAuth
        XCTAssertFalse(requiresAuth)
    }
    
    // MARK: - Search Tests
    
    func testSearchReturnsResults() async throws {
        // Skip if no network
        guard await hasNetworkConnection() else {
            throw XCTSkip("No network connection")
        }
        
        let results = try await module.searchTracks(query: "daft punk", limit: 5)
        
        XCTAssertFalse(results.tracks.isEmpty, "Search should return tracks")
        XCTAssertLessThanOrEqual(results.tracks.count, 5)
        
        // Verify track structure
        if let track = results.tracks.first {
            XCTAssertFalse(track.id.isEmpty)
            XCTAssertFalse(track.title.isEmpty)
            XCTAssertFalse(track.artistName.isEmpty)
            XCTAssertEqual(track.moduleId, "im-miserable")
        }
    }
    
    func testSearchEmptyQuery() async throws {
        let results = try await module.searchTracks(query: "", limit: 10)
        // Behavior depends on API, but should not crash
        XCTAssertNotNil(results)
    }
    
    // MARK: - Stream Tests
    
    func testGetStreamReturnsValidURL() async throws {
        guard await hasNetworkConnection() else {
            throw XCTSkip("No network connection")
        }
        
        // First search for a track
        let results = try await module.searchTracks(query: "test", limit: 1)
        guard let track = results.tracks.first else {
            throw XCTSkip("No tracks found for testing")
        }
        
        let stream = try await module.getTrackStream(
            trackId: track.id,
            preferredQuality: .lossless
        )
        
        XCTAssertNotNil(stream.url)
        XCTAssertEqual(stream.url.scheme, "https")
        XCTAssertEqual(stream.trackId, track.id)
    }
    
    // MARK: - Error Handling Tests
    
    func testStreamNotFoundThrows() async {
        do {
            _ = try await module.getTrackStream(
                trackId: "invalid-track-id-12345",
                preferredQuality: .lossless
            )
            XCTFail("Should throw an error for invalid track ID")
        } catch {
            // Expected error
            XCTAssertTrue(error is ModuleError || error is DecodingError)
        }
    }
    
    func testAlbumNotImplemented() async {
        do {
            _ = try await module.getAlbum(albumId: "test-album")
            XCTFail("Should throw albumNotFound")
        } catch let error as ModuleError {
            if case .albumNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func hasNetworkConnection() async -> Bool {
        do {
            let url = URL(string: "https://tidal.kinoplus.online")!
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
