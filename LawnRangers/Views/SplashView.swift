import SwiftUI

/// Brand splash screen — "Lawn Rangers": a lasso reining in the grass.
struct SplashView: View {
    var body: some View {
        ZStack {
            // Sky-to-lawn green gradient.
            LinearGradient(
                colors: [Color.lawnGreen.opacity(0.85), Color.lawnGreen],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lasso")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Lawn Rangers")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding()

            // Grass along the bottom — the unruly stuff the lasso tames.
            VStack {
                Spacer()
                GrassView()
                    .frame(height: 120)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

/// A row of hand-drawn grass blades.
struct GrassView: View {
    var body: some View {
        Canvas { context, size in
            let count = 22
            let spacing = size.width / CGFloat(count - 1)
            for i in 0..<count {
                let x = CGFloat(i) * spacing
                let h = size.height * (0.45 + 0.55 * abs(sin(Double(i) * 1.27)))
                let lean = CGFloat(sin(Double(i) * 0.9)) * 16
                var blade = Path()
                blade.move(to: CGPoint(x: x - 7, y: size.height))
                blade.addQuadCurve(
                    to: CGPoint(x: x + lean, y: size.height - h),
                    control: CGPoint(x: x - 2, y: size.height - h * 0.5)
                )
                blade.addQuadCurve(
                    to: CGPoint(x: x + 7, y: size.height),
                    control: CGPoint(x: x + 2, y: size.height - h * 0.5)
                )
                blade.closeSubpath()

                let shade = i % 2 == 0
                    ? Color(red: 0.10, green: 0.38, blue: 0.13)
                    : Color(red: 0.17, green: 0.52, blue: 0.20)
                context.fill(blade, with: .color(shade))
            }
        }
    }
}

extension Color {
    /// The brand green used across the app.
    static let lawnGreen = Color(red: 46 / 255, green: 125 / 255, blue: 50 / 255)
}

#Preview {
    SplashView()
}
