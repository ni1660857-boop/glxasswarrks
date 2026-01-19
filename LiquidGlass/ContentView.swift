import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayer
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabView(selection: $selectedTab) {
                SearchView()
                    .tag(0)
                
                LibraryView()
                    .tag(1)
                
                DownloadsView()
                    .tag(2)
                
                ModuleManagerView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack(spacing: 0) {
                // Mini player
                if player.currentTrack != nil {
                    MiniPlayerView(isExpanded: $showNowPlaying)
                        .padding(.bottom, 8)
                }
                
                // Custom tab bar
                customTabBar
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environmentObject(player)
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
                selectedTab = 0
            }
            
            TabBarButton(
                icon: "square.stack",
                label: "Library",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            
            TabBarButton(
                icon: "arrow.down.circle",
                label: "Downloads",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
            
            TabBarButton(
                icon: "puzzlepiece.extension",
                label: "Modules",
                isSelected: selectedTab == 3
            ) {
                selectedTab = 3
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.surfacePrimary.opacity(0.8))
                )
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1),
                    alignment: .top
                )
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
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentGlow.opacity(0.15))
                            .frame(width: 56, height: 32)
                    }
                    
                    Image(systemName: isSelected ? icon + ".fill" : icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Color.accentGlow : Color.textSecondary)
                        .frame(width: 56, height: 32)
                }
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentGlow : Color.textSecondary)
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
