import SwiftUI

/// The pill-shaped "EN"/"中文" translation toggle on the entry screen: filled when on.
struct TranslationChip: View {
    var title: String
    var isOn: Bool
    var action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 13)
                .frame(height: 30)
                .foregroundStyle(isOn ? theme.onTint : theme.ink)
                .background(isOn ? theme.tint : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(isOn ? Color.clear : theme.sep2, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }
}

/// A small circular icon button, used for the entry screen's speak/bookmark actions.
struct CircleIconButton: View {
    var systemImage: String
    var isOn: Bool
    var fillWhenOn: Bool = false
    var action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn && fillWhenOn ? systemImage + ".fill" : systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 40, height: 40)
                .foregroundStyle(isOn ? theme.onTint : theme.tint)
                .background(isOn ? theme.tint : theme.fill)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// The small "BM"/"NN" pill shown next to a headword throughout the app.
struct DictBadge: View {
    var dict: Dict
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(dict == .bm ? "BM" : "NN")
            .font(.system(size: 11, weight: .bold))
            .tracking(0.4)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(dict == .bm ? theme.bmBg : theme.nnBg)
            .foregroundStyle(dict == .bm ? theme.bm : theme.nn)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

/// A rounded, pill-shaped segmented control matching the design's `segStyle`: a filled track
/// with a raised, shadowed capsule behind the selected segment.
///
/// The selected segment's text uses `selectedTint(item) ?? theme.ink` and the unselected
/// segments use the dimmer `theme.ink2`, rather than every segment sharing one color —
/// selection used to be signaled only by the card-background swap, which is barely visible in
/// low-contrast themes (e.g. the "White" palette's dark variant sets both `bg` and `grp` to
/// pure black, so the selected segment's `card` fill is only a few percent lighter). Passing
/// `selectedTint` lets a specific pair of segments (Bokmål/Nynorsk) get their own accent color
/// on top of that, for an even clearer cue; other uses (Light/Dark/System, Left/Right-handed)
/// just rely on the ink/ink2 contrast.
struct SegmentedPill<Value: Hashable, Content: View>: View {
    var items: [Value]
    @Binding var selection: Value
    var selectedTint: (Value) -> Color? = { _ in nil }
    var label: (Value) -> Content

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection == item
                Button {
                    selection = item
                } label: {
                    label(item)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? (selectedTint(item) ?? theme.ink) : theme.ink2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(theme.card)
                                    .shadow(color: .black.opacity(0.12), radius: 4, y: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .frame(height: 32)
        .background(theme.fill)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
