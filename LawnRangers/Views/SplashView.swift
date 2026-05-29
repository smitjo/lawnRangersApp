import SwiftUI

/// Brand splash screen — the app's main look: "Lawn Rangers" on green.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color.lawnGreen
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
                Text("Lawn Rangers")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding()
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
