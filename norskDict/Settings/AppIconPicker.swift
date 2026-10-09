import SwiftUI

/// The Settings section for picking a Home Screen icon, grouped by style (Simple/Cute/Modern)
/// with a horizontal scroll row per group — one of the 9 icons from the Claude Design handoff.
struct AppIconSection: View {
    @State private var manager = AppIconManager()
    @Environment(AppSettings.self) private var settings

    private var strings: Strings { settings.strings }

    var body: some View {
        Section(strings.appIcon) {
            ForEach(AppIconOption.Style.allCases, id: \.self) { style in
                VStack(alignment: .leading, spacing: 10) {
                    Text(style.label(ui: settings.uiLanguage))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(AppIconOption.allCases.filter { $0.style == style }) { icon in
                                IconTile(icon: icon, isSelected: manager.current == icon) {
                                    Task { await manager.set(icon) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .disabled(!manager.isSupported)
    }
}

private struct IconTile: View {
    let icon: AppIconOption
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(icon.previewImageName)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 13.4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? theme.tint : .clear, lineWidth: 2.5)
                            .padding(-4)
                    )
                Text(icon.displayName(ui: settings.uiLanguage))
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.ink : theme.ink2)
                    .lineLimit(1)
                    .frame(width: 72)
            }
            .padding(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.displayName(ui: settings.uiLanguage))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
