import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayer
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    
    // Inject dependencies to ensure loading
    @StateObject private var hifiAPI = HiFiAPI.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Global Background
            GlassTheme.black.ignoresSafeArea()
            
            // Tab content
            // Content Area
            ZStack {
                if selectedTab == 0 {
                    SearchView()
                        .transition(.opacity)
                } else if selectedTab == 1 {
                    LibraryView()
                        .transition(.opacity)
                } else if selectedTab == 2 {
                    DownloadsView()
                        .transition(.opacity)
                } else if selectedTab == 3 {
                    ModuleManagerView()
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            
            
            // UI Overlay
            VStack(spacing: 0) {
                Spacer()
                
                // Mini player
                if player.currentTrack != nil {
                    MiniPlayerView(isExpanded: $showNowPlaying)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
                
                // Custom tab bar
                customTabBar
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environmentObject(player)
                .oledBackground()
        }
        .task {
            // Ensure modules are loaded on app start
            await hifiAPI.registry.loadModules()
        }
        .alert("Playback Error", isPresented: Binding(
            get: { player.error != nil },
            set: { if !$0 { player.error = nil } }
        )) {
            Button("OK", role: .cancel) { player.error = nil }
        } message: {
            if let error = player.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "magnifyingglass",
                label: "Search",
                isSelected: selectedTab == 0
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 0
                }
            }
            
            TabBarButton(
                icon: "square.stack.3d.up",
                label: "Library",
                isSelected: selectedTab == 1
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 1
                }
            }
            
            TabBarButton(
                icon: "arrow.down.circle",
                label: "Downloads",
                isSelected: selectedTab == 2
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 2
                }
            }
            
            TabBarButton(
                icon: "puzzlepiece.extension",
                label: "Modules",
                isSelected: selectedTab == 3
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 3
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: 20)
                        Rectangle()
                    }
                }
                .ignoresSafeArea()
        )
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isSelected {
                        GlassTheme.cyan
                            .frame(width: 40, height: 4)
                            .blur(radius: 4)
                            .offset(y: -20)
                            .opacity(0.8)
                    }
                    
                    Image(systemName: isSelected ? icon + ".fill" : icon)
                        .font(.system(size: 22, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : GlassTheme.gray)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                
                Text(label)
                    .font(GlassTheme.font(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .white : GlassTheme.gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayer.shared)
}
