import AVFoundation
import SwiftUI

struct SettingsView: View {
    var open: (AppRoute) -> Void

    @Environment(\.appTheme) private var theme
    @Environment(AppSettings.self) private var settings

    private var strings: Strings { settings.strings }
    private var isZh: Bool { settings.uiLanguage == .zh }

    var body: some View {
        Form {
            Section(strings.appearance) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(strings.theme).font(.system(size: 17))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(ThemePalette.allCases) { palette in
                                ThemeSwatch(palette: palette, isSelected: settings.theme == palette) {
                                    settings.theme = palette
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 4)

                SegmentedPill(items: AppearanceMode.allCases, selection: Binding(
                    get: { settings.appearance }, set: { settings.appearance = $0 }
                )) { mode in
                    Text(label(for: mode))
                }
            }

            Section(strings.navigationHand) {
                SegmentedPill(items: NavigationHand.allCases, selection: Binding(
                    get: { settings.navigationHand }, set: { settings.navigationHand = $0 }
                )) { hand in
                    Text(hand == .left ? strings.leftHanded : strings.rightHanded)
                }
            }

            AppIconSection()

            Section {
                Toggle(isZh ? "iCloud 同步" : "iCloud Sync", isOn: Binding(
                    get: { settings.iCloudSyncEnabled }, set: { settings.iCloudSyncEnabled = $0 }
                ))
            } footer: {
                Text(isZh
                    ? "通过 iCloud 在你的设备间同步收藏和收藏夹。更改在重新启动应用后生效。"
                    : "Sync bookmarks and folders across your devices with iCloud. Changes take effect the next time the app launches.")
            }

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

            if Pronouncer.isVoiceAvailable {
                Section(strings.speechSpeed) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "tortoise").font(.system(size: 15)).foregroundStyle(theme.ink2)
                            Slider(
                                value: Binding(
                                    get: { settings.speechRateMultiplier },
                                    set: { settings.speechRateMultiplier = $0 }
                                ),
                                in: AppSettings.speechRateMultiplierRange,
                                step: 0.1
                            )
                            Image(systemName: "hare").font(.system(size: 17)).foregroundStyle(theme.ink2)
                            CircleIconButton(systemImage: "speaker.wave.2", isOn: Pronouncer.shared.isSpeaking, fillWhenOn: true) {
                                Pronouncer.shared.speak("en god venn av meg", rate: settings.speechRate, voiceIdentifier: settings.speechVoiceIdentifier)
                            }
                        }
                        Text(String(format: "%.1fx", settings.speechRateMultiplier))
                            .font(.system(size: 13))
                            .foregroundStyle(theme.ink2)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Picker(strings.speechVoice, selection: Binding(
                        get: { settings.speechVoiceIdentifier },
                        set: { settings.speechVoiceIdentifier = $0 }
                    )) {
                        Text(strings.automaticVoice).tag(String?.none)
                        ForEach(Pronouncer.availableVoices, id: \.identifier) { voice in
                            Text(voiceLabel(voice)).tag(Optional(voice.identifier))
                        }
                    }
                } footer: {
                    Text(strings.speechVoiceFooter)
                }
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
                    Text(strings.version)
                    Spacer()
                    Text(appVersion).foregroundStyle(theme.ink2)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.grp)
        .navigationTitle(strings.settings)
    }

    /// Marketing version and build from the app's Info.plist (MARKETING_VERSION / CURRENT_PROJECT_VERSION).
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func voiceLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: "\(voice.name) · \(strings.voicePremium)"
        case .enhanced: "\(voice.name) · \(strings.voiceEnhanced)"
        default: voice.name
        }
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
