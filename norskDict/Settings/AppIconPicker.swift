import SwiftUI

/// The Settings section for picking a Home Screen icon: a single horizontally-scrollable row
/// of all 9 icons from the Claude Design handoff, each just a preview tile and its name.
struct AppIconSection: View {
    @State private var manager = AppIconManager()
    @Environment(AppSettings.self) private var settings

    private var strings: Strings { settings.strings }

    var body: some View {
        Section(strings.appIcon) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(AppIconOption.allCases) { icon in
                        IconTile(icon: icon, isSelected: manager.current == icon) {
                            Task { await manager.set(icon) }
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.trailing, 10)
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
                    .minimumScaleFactor(0.8)
                    .frame(width: 80)
            }
            .padding(4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.displayName(ui: settings.uiLanguage))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
