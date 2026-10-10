import SwiftUI

/// Shown for the brief moment while `RootView` warms up the dictionary database and fuzzy-match
/// index. Both are cold and slow on a fresh install, long enough that the first tap would
/// otherwise land mid-warmup and feel unresponsive — a 3-dot bounce (not a single subtle pulse)
/// so it reads clearly as "loading" even if it's only on screen briefly. If warmup is taking
/// long enough to actually notice (> 2s — a fresh install, not just a cold launch), a hint fades
/// in explaining why, so it doesn't just look stuck.
struct LaunchSplashView: View {
    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings
    @State private var isBouncing = false
    @State private var showHint = false

    private var strings: Strings { settings.strings }

    var body: some View {
        VStack(spacing: 20) {
            Text(strings.appTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.ink)
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(theme.tint)
                        .frame(width: 12, height: 12)
                        .offset(y: isBouncing ? -8 : 0)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.45).repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: isBouncing
                        )
                }
            }
            Text(strings.firstLaunchHint)
                .font(.system(size: 13))
                .foregroundStyle(theme.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 4)
                .opacity(showHint ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .onAppear {
            isBouncing = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeIn(duration: 0.4)) { showHint = true }
            }
        }
    }
}
