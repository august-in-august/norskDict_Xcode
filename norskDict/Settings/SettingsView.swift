import SwiftUI

struct SettingsView: View {
    var open: (AppRoute) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings

    private var strings: Strings { settings.strings }

    var body: some View {
        Form {
            Section(strings.appearance) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(strings.theme).font(.system(size: 17))
                    HStack {
                        ForEach(ThemePalette.allCases) { palette in
                            ThemeSwatch(palette: palette, isSelected: settings.theme == palette) {
                                settings.theme = palette
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                SegmentedPill(items: AppearanceMode.allCases, selection: Binding(
                    get: { settings.appearance }, set: { settings.appearance = $0 }
                )) { mode in
                    Text(label(for: mode))
                }
            }

            AppIconSection()

            Section {
                Toggle(strings.englishName, isOn: Binding(get: { settings.showEnglish }, set: { settings.showEnglish = $0 }))
                Toggle(strings.chineseName, isOn: Binding(get: { settings.showChinese }, set: { settings.showChinese = $0 }))
            } header: {
                Text(strings.translationsHeader)
            } footer: {
                Text(strings.translationsFooter)
            }

            Section(strings.interfaceLanguage) {
                Button {
                    settings.uiLanguage = .en
                } label: {
                    HStack {
                        Text("English").foregroundStyle(theme.ink)
                        Spacer()
                        if settings.uiLanguage == .en { Image(systemName: "checkmark").foregroundStyle(theme.tint) }
                    }
                }
                Button {
                    settings.uiLanguage = .zh
                } label: {
                    HStack {
                        Text("简体中文").foregroundStyle(theme.ink)
                        Spacer()
                        if settings.uiLanguage == .zh { Image(systemName: "checkmark").foregroundStyle(theme.tint) }
                    }
                }
            }

            Section(strings.textSize) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("A").font(.system(size: 13))
                        Slider(
                            value: Binding(
                                get: { Double(settings.textSizeIndex) },
                                set: { settings.textSizeIndex = Int($0.rounded()) }
                            ),
                            in: 0...Double(AppSettings.textScales.count - 1),
                            step: 1
                        )
                        Text("A").font(.system(size: 22))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("en god venn av meg").italic().font(.system(size: 17 * settings.textScale))
                        Text(strings.sampleTranslation)
                            .font(.system(size: 14 * settings.textScale))
                            .foregroundStyle(theme.ink2)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(strings.about) {
                Button { open(.sources) } label: {
                    HStack {
                        Text(strings.sources).foregroundStyle(theme.ink)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.ink3)
                    }
                }
                HStack {
                    Text(strings.articles)
                    Spacer()
                    Text("\(DictionaryDatabase.shared.totalArticleCount())").foregroundStyle(theme.ink2)
                }
                HStack {
                    Text(strings.version)
                    Spacer()
                    Text("1.0").foregroundStyle(theme.ink2)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.grp)
        .navigationTitle(strings.settings)
    }

    private func label(for mode: AppearanceMode) -> String {
        switch mode {
        case .system: strings.system
        case .light: strings.light
        case .dark: strings.dark
        }
    }
}

/// A theme swatch: a circle split diagonally into its light and dark background colors,
/// matching the design's `linear-gradient(135deg, light 50%, dark 50%)` swatches.
private struct ThemeSwatch: View {
    var palette: ThemePalette
    var isSelected: Bool
    var action: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: palette.light.bg, location: 0),
                            .init(color: palette.light.bg, location: 0.5),
                            .init(color: palette.dark.bg, location: 0.5),
                            .init(color: palette.dark.bg, location: 1),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(isSelected ? theme.tint : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1))
                Text(palette.displayName(ui: settings.uiLanguage))
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.ink : theme.ink2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
