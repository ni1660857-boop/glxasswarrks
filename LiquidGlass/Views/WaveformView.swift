import SwiftUI

// MARK: - Waveform View

struct WaveformView: View {
    let levels: [CGFloat]
    let color: Color
    
    init(levels: [CGFloat] = [], color: Color = .accentGlow) {
        self.levels = levels.isEmpty ? Array(repeating: 0.3, count: 30) : levels
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: max(4, levels[index] * 40))
            }
        }
    }
}

// MARK: - Animated Waveform

struct AnimatedWaveformView: View {
    @State private var levels: [CGFloat] = Array(repeating: 0.3, count: 40)
    @State private var isAnimating = false
    let isPlaying: Bool
    let color: Color
    
    init(isPlaying: Bool, color: Color = .accentGlow) {
        self.isPlaying = isPlaying
        self.color = color
    }
    
    var body: some View {
        WaveformView(levels: levels, color: color)
            .onChange(of: isPlaying) { newValue in
                isAnimating = newValue
                if newValue {
                    startAnimation()
                }
            }
            .onAppear {
                if isPlaying {
                    isAnimating = true
                    startAnimation()
                }
            }
    }
    
    private func startAnimation() {
        guard isAnimating else { return }
        
        withAnimation(.easeInOut(duration: 0.15)) {
            levels = levels.map { _ in CGFloat.random(in: 0.15...1.0) }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if isAnimating && isPlaying {
                startAnimation()
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    levels = Array(repeating: 0.2, count: levels.count)
                }
            }
        }
    }
}

// MARK: - Circle Waveform

struct CircleWaveformView: View {
    @State private var levels: [CGFloat] = Array(repeating: 0.5, count: 64)
    let isPlaying: Bool
    let diameter: CGFloat
    let color: Color
    
    init(isPlaying: Bool, diameter: CGFloat = 200, color: Color = .accentGlow) {
        self.isPlaying = isPlaying
        self.diameter = diameter
        self.color = color
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<levels.count, id: \.self) { index in
                let angle = Double(index) / Double(levels.count) * 360
                let length = 10 + levels[index] * 30
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.3)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: length)
                    .offset(y: -diameter / 2 - length / 2 + 10)
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            if isPlaying { startAnimation() }
        }
        .onChange(of: isPlaying) { newValue in
            if newValue { startAnimation() }
        }
    }
    
    private func startAnimation() {
        guard isPlaying else { return }
        
        withAnimation(.linear(duration: 0.1)) {
            levels = levels.map { _ in CGFloat.random(in: 0.2...1.0) }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if isPlaying {
                startAnimation()
            }
        }
    }
}

// MARK: - Level Meter

struct LevelMeterView: View {
    let level: CGFloat
    let peakLevel: CGFloat
    let segments: Int
    
    init(level: CGFloat = 0.5, peakLevel: CGFloat = 0.8, segments: Int = 20) {
        self.level = level
        self.peakLevel = peakLevel
        self.segments = segments
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                let threshold = CGFloat(index) / CGFloat(segments)
                let isActive = level > threshold
                let isPeak = abs(peakLevel - threshold) < 0.05
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(segmentColor(index: index, isActive: isActive, isPeak: isPeak))
                    .frame(width: 6, height: 20)
            }
        }
    }
    
    private func segmentColor(index: Int, isActive: Bool, isPeak: Bool) -> Color {
        if isPeak {
            return .white
        }
        
        if !isActive {
            return Color.white.opacity(0.1)
        }
        
        let position = CGFloat(index) / CGFloat(segments)
        
        if position > 0.85 {
            return .red
        } else if position > 0.7 {
            return .orange
        } else {
            return Color.accentGlow
        }
    }
}
