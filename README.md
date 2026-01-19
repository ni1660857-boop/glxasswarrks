# LiquidGlass - High-Fidelity Music Player

<p align="center">
  <img src="docs/logo.png" width="120" alt="LiquidGlass Logo">
</p>

A premium, modular music player for iOS with a stunning "Liquid Glass" design and support for high-fidelity lossless audio streaming.

## ✨ Features

### 🎨 Liquid Glass Design
- Translucent glassmorphism UI with depth and blur effects
- Specular highlights and smooth spring animations
- Premium gradient accents and quality badges
- Responsive waveform visualizations

### 🔌 Modular Architecture
- Plugin system for multiple music sources
- **I'm Miserable** module enabled by default (KINOPLUS TIDAL instance)
- Spotify metadata integration ready
- Sandboxed modules with domain allowlisting

### 🎵 HiFi Audio
- Lossless streaming (FLAC, ALAC, MQA)
- Quality badges showing bit depth and sample rate
- Support for up to 24-bit/192kHz Hi-Res audio
- Intelligent quality negotiation

### 📱 Native iOS Experience
- Background audio playback
- AirPlay support
- Control Center / Lock Screen controls
- Queue management with drag-to-reorder

## 📸 Screenshots

| Now Playing | Search | Library | Modules |
|-------------|--------|---------|---------|
| ![Now Playing](docs/now-playing.png) | ![Search](docs/search.png) | ![Library](docs/library.png) | ![Modules](docs/modules.png) |

## 🏗️ Architecture

```
LiquidGlass/
├── Core/
│   ├── Models.swift          # Data models (Track, Album, Artist, StreamInfo)
│   ├── MusicModule.swift     # Module protocol (Swift actors)
│   ├── ModuleRegistry.swift  # Module lifecycle management
│   ├── HiFiAPI.swift         # High-level API abstraction
│   ├── AudioPlayer.swift     # AVFoundation playback
│   └── SecurityManager.swift # Domain allowlist & module signing
├── Modules/
│   └── ImMiserableModule.swift  # Default music source
├── Views/
│   ├── GlassComponents.swift    # Design system components
│   ├── NowPlayingView.swift     # Full-screen player
│   ├── SearchView.swift         # Search interface
│   ├── LibraryView.swift        # Library & playlists
│   ├── DownloadsView.swift      # Offline downloads
│   └── ModuleManagerView.swift  # Module settings
├── ViewModels/
└── Services/
    ├── SpotifyMetadataService.swift
    ├── NetworkLogger.swift
    └── CacheManager.swift
```

### Core Protocols

```swift
public protocol MusicModule: Actor {
    var id: String { get }
    var name: String { get }
    var allowedDomains: [String] { get }
    
    func searchTracks(query: String, limit: Int) async throws -> SearchResults
    func getTrackStream(trackId: String, preferredQuality: AudioQuality) async throws -> StreamInfo
    func getAlbum(albumId: String) async throws -> Album
}
```

## 🔒 Security

- **Module Signing**: All remote modules must be signed and verified
- **Domain Allowlist**: Modules can only access pre-approved domains
- **Policy Enforcement**: Violations are logged and blocked
- **Rate Limiting**: Per-module rate limit tracking
- **HTTPS Only**: All network requests require TLS

## 🚀 Building

### Prerequisites
- Xcode 15.0+
- iOS 16.0+ deployment target
- macOS Sonoma (for local development)

### Build locally
```bash
xcodebuild build \
  -project LiquidGlass/LiquidGlass.xcodeproj \
  -scheme LiquidGlass \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO
```

### Build via GitHub Actions
1. Fork this repository
2. Push to trigger the build workflow
3. Download the unsigned IPA from Actions artifacts
4. Sign using AltStore, Sideloadly, or TrollStore

## 📦 Installation

Since this is an **unsigned IPA**, you'll need to sign it yourself:

### Option 1: AltStore
1. Install [AltStore](https://altstore.io) on your device
2. Import the `.ipa` file
3. AltStore will sign and install automatically

### Option 2: Sideloadly
1. Download [Sideloadly](https://sideloadly.io)
2. Connect your device
3. Drop the `.ipa` file and sign with your Apple ID

### Option 3: TrollStore (Jailbroken)
1. If you have TrollStore installed
2. Open the `.ipa` directly to install

## 🧪 Testing

```bash
# Run unit tests
xcodebuild test \
  -project LiquidGlass/LiquidGlass.xcodeproj \
  -scheme LiquidGlass \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## 📖 Module Development

Create your own music source module:

```swift
public actor MyMusicModule: MusicModule {
    public let id = "my-module"
    public let name = "My Music Source"
    public let version = "1.0.0"
    public let allowedDomains = ["api.myservice.com"]
    public var isEnabled = true
    
    public func searchTracks(query: String, limit: Int) async throws -> SearchResults {
        // Implement search
    }
    
    public func getTrackStream(trackId: String, preferredQuality: AudioQuality) async throws -> StreamInfo {
        // Resolve stream URL
    }
}
```

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Credits

- [KINOPLUS](https://tidal.kinoplus.online) - I'm Miserable module backend
- SwiftUI - Apple's declarative UI framework
- AVFoundation - Audio playback engine

---

<p align="center">
  Made with 💜 and Swift
</p>
