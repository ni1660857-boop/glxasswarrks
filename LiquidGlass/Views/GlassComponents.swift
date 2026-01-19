import SwiftUI

// MARK: - Liquid Glass Design System

/// Premium glassmorphism design tokens and components

// MARK: - Color Palette
extension Color {
    static let glassBackground = Color.white.opacity(0.08)
    static let glassBorder = Color.white.opacity(0.15)
    static let glassHighlight = Color.white.opacity(0.25)
    static let accentGlow = Color(hue: 0.55, saturation: 0.7, brightness: 0.95)
    static let accentSecondary = Color(hue: 0.85, saturation: 0.6, brightness: 0.95)
    static let surfacePrimary = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let surfaceSecondary = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
}

// MARK: - Glass Card Modifier
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var blur: CGFloat = 20
    var opacity: CGFloat = 0.08
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(opacity))
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Button
struct GlassButton: View {
    let icon: String
    let size: CGFloat
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(isActive ? Color.accentGlow.opacity(0.3) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(isActive ? Color.accentGlow : .white)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Play Button (Large)
struct PlayButton: View {
    let isPlaying: Bool
    let size: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentGlow.opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: size * 0.3,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size * 1.3, height: size * 1.3)
                    .blur(radius: 10)
                
                // Glass circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentGlow.opacity(0.5), Color.accentSecondary.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: isPlaying ? 0 : size * 0.03)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Quality Badge
struct QualityBadge: View {
    let quality: String
    var isHighlighted: Bool = false
    
    var body: some View {
        Text(quality)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(isHighlighted ? Color.accentGlow : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isHighlighted ? Color.accentGlow.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(isHighlighted ? Color.accentGlow.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Glass Slider
struct GlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void = { _ in }
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 6)
                
                // Progress
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentGlow, Color.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: progressWidth(in: geometry.size.width), height: 6)
                
                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: isDragging ? 18 : 14, height: isDragging ? 18 : 14)
                    .shadow(color: Color.accentGlow.opacity(0.5), radius: 8)
                    .offset(x: thumbOffset(in: geometry.size.width))
                    .animation(.spring(response: 0.3), value: isDragging)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        let newValue = gesture.location.x / geometry.size.width
                        value = range.lowerBound + (range.upperBound - range.lowerBound) * min(max(0, newValue), 1)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 20)
    }
    
    private func progressWidth(in width: CGFloat) -> CGFloat {
        let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return max(0, min(width, width * progress))
    }
    
    private func thumbOffset(in width: CGFloat) -> CGFloat {
        let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return max(0, min(width - 14, width * progress - 7))
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.1), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: phase)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Async Image with Blur
struct BlurredAsyncImage: View {
    let url: URL?
    var cornerRadius: CGFloat = 12
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Rectangle()
                    .fill(Color.surfaceSecondary)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundStyle(Color.textTertiary)
                    )
            case .empty:
                Rectangle()
                    .fill(Color.surfaceSecondary)
                    .shimmer()
            @unknown default:
                Rectangle()
                    .fill(Color.surfaceSecondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Tab Bar Icon
struct TabBarIcon: View {
    let icon: String
    let label: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isSelected ? icon + ".fill" : icon)
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? Color.accentGlow : Color.textSecondary)
                .shadow(color: isSelected ? Color.accentGlow.opacity(0.5) : .clear, radius: 8)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentGlow : Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading Indicator
struct GlassLoadingIndicator: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                LinearGradient(
                    colors: [Color.accentGlow, Color.accentGlow.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 30, height: 30)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Glass Theme
public enum GlassTheme {
    public static let black = Color(red: 0, green: 0, blue: 0) // True OLED Black
    public static let darkGray = Color(red: 0.1, green: 0.1, blue: 0.1)
    public static let cyan = Color(red: 0.0, green: 1.0, blue: 1.0)
    public static let pink = Color(red: 1.0, green: 0.0, blue: 0.5)
    
    // Semantic aliases
    public static let background = black
    public static let textPrimary = Color.white
    
    // Convenience for standard glass colors used in components
    public static let white = Color.white
    public static let gray = Color.gray
    
    public static var liquidGradient: LinearGradient {
        LinearGradient(
            colors: [cyan.opacity(0.3), pink.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    public static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - View Modifiers
struct OLEDBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            GlassTheme.black.ignoresSafeArea()
            content
        }
    }
}

extension View {
    func oledBackground() -> some View {
        modifier(OLEDBackground())
    }
}
