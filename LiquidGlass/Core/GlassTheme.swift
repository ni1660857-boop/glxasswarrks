import SwiftUI

// MARK: - Design System

public enum GlassTheme {
    
    // MARK: - Colors
    public static let black = Color(red: 0, green: 0, blue: 0) // True OLED Black
    public static let darkGray = Color(red: 0.1, green: 0.1, blue: 0.1)
    public static let white = Color.white
    public static let gray = Color.gray
    
    public static let cyan = Color(red: 0.0, green: 1.0, blue: 1.0) // Cyberpunk/Tidal Cyan
    public static let pink = Color(red: 1.0, green: 0.0, blue: 0.5) // Neon Pink
    
    // Gradient for "Liquid" effect
    public static let liquidGradient = LinearGradient(
        colors: [cyan.opacity(0.3), pink.opacity(0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Spacing
    public static let padding: CGFloat = 20
    public static let cornerRadius: CGFloat = 24
    
    // MARK: - Fonts
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

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(GlassTheme.padding)
            .background(.thinMaterial) // SwiftUI Material for Glass
            .environment(\.colorScheme, .dark) // Force dark mode for glass
            .clipShape(RoundedRectangle(cornerRadius: GlassTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cornerRadius)
                    .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: GlassTheme.cyan.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Extensions

public extension View {
    func oledBackground() -> some View {
        modifier(OLEDBackground())
    }
    
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}
