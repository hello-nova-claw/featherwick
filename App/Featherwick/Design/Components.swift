import SwiftUI

// Components from the UI system. One primary button per screen; separation comes from white space
// and dashed stitches, not boxes. No pills: controls have a 10pt radius.

/// Ink fill, paper label. Only one per screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.action)
            .foregroundStyle(isEnabled ? palette.paper : palette.inkMuted)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: Radius.control)
                    .fill(isEnabled ? palette.ink.opacity(configuration.isPressed ? 0.85 : 1) : .clear)
                if !isEnabled {
                    RoundedRectangle(cornerRadius: Radius.control)
                        .strokeBorder(palette.unknown, style: Stitch.unknown)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Paper fill, hairline outline, ink label.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.action)
            .foregroundStyle(isEnabled ? palette.ink : palette.inkMuted)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: Radius.control)
                    .strokeBorder(
                        isEnabled ? palette.hairline : palette.unknown,
                        style: isEnabled ? StrokeStyle(lineWidth: 1) : Stitch.unknown)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet text actions: Rename, Family tree, Later. 44pt hit area: the whole frame takes the tap, not
/// only the letters.
struct TextActionStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.sans(15))
            .foregroundStyle(palette.inkSoft)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { .init() }
}
extension ButtonStyle where Self == TextActionStyle {
    static var textAction: TextActionStyle { .init() }
}

/// "×" at the top right of every sheet.
struct CloseButton: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    var action: (() -> Void)?

    var body: some View {
        Button {
            if let action { action() } else { dismiss() }
        } label: {
            Text("×").font(Typeface.sansLight(26)).foregroundStyle(palette.inkMuted)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Close")
    }
}

/// The small context line and close button at the top of a sheet.
struct SheetHeader: View {
    @Environment(\.palette) private var palette
    let context: String
    var onClose: (() -> Void)?

    var body: some View {
        HStack {
            Text(context).font(Typeface.label).foregroundStyle(palette.inkMuted)
            Spacer()
            CloseButton(action: onClose)
        }
    }
}

/// A sheet's page: paper background, side padding, scrolling content.
struct SheetPage<Content: View>: View {
    @Environment(\.palette) private var palette
    let context: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                SheetHeader(context: context)
                content
            }
            .padding(.horizontal, Space.sheetSide)
            .padding(.bottom, Space.sheetBottom)
            .padding(.top, Space.s)
        }
        .foregroundStyle(palette.ink)
        .background(palette.paper)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(palette.paper)
    }
}

/// A display name with a dashed underline drawn behind it, so descenders cross the line.
struct UnderlinedName: View {
    @Environment(\.palette) private var palette
    let text: String
    var font: Font = Typeface.displayName
    var size: CGFloat = 54

    var body: some View {
        Text(text)
            .font(font)
            .background(alignment: .bottom) {
                HLine()
                    .stroke(palette.ink.opacity(0.5), style: Stitch.underline)
                    .frame(height: 2)
                    .offset(y: -size * 0.16)
            }
    }
}

/// Plain-word tabs. Selected: ink, medium, dashed underline. Unselected: muted. Each tab takes taps over
/// its full 44pt height, not only on its letters.
struct WordTabs<Tab: Hashable>: View {
    @Environment(\.palette) private var palette
    let tabs: [(Tab, String)]
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: Space.l) {
            ForEach(tabs, id: \.0) { tab, title in
                let selected = tab == selection
                Button {
                    selection = tab
                } label: {
                    Text(title)
                        .font(selected ? Typeface.action : Typeface.body)
                        .foregroundStyle(selected ? palette.ink : palette.inkMuted)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) {
                            if selected {
                                HLine().stroke(palette.ink.opacity(0.75), style: Stitch.underline)
                                    .frame(height: 2).offset(y: -8)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// A labelled fact: small label above, value below (bird card grid).
struct Fact<Value: View>: View {
    @Environment(\.palette) private var palette
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(label).font(Typeface.label).foregroundStyle(palette.inkMuted)
            value
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// "● 3 eggs waiting": a dot to draw the eye, words to carry the meaning.
struct Notice: Hashable {
    enum Kind: Hashable { case collect, decision, story }
    let kind: Kind
    let text: String

    /// The dot colour for each kind. The words carry the meaning; the colour only draws the eye.
    static func colour(_ kind: Kind, in palette: Palette) -> Color {
        switch kind {
        case .collect: Pigment.brownNotice
        case .decision: Pigment.buffNotice
        case .story: palette.ink
        }
    }

    /// The kind that most wants the player: a choice first, then something to collect, then news.
    static func mostPressing(_ notices: [Notice]) -> Kind? {
        let kinds = notices.map(\.kind)
        return [Kind.decision, .collect, .story].first { kinds.contains($0) }
    }
}

struct NoticeLine: View {
    @Environment(\.palette) private var palette
    let notice: Notice

    var body: some View {
        HStack(spacing: Space.xs) {
            Circle().fill(Notice.colour(notice.kind, in: palette)).frame(width: 8, height: 8)
            Text(notice.text).font(Typeface.caption).foregroundStyle(palette.inkSoft)
        }
    }
}

/// A price button: coin dot + number, secondary style. Disabled says why.
struct PriceButton: View {
    @Environment(\.palette) private var palette
    let price: Int
    let canAfford: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if canAfford {
                HStack(spacing: Space.xs) {
                    CoinDisc()
                    Text("\(price)").font(Typeface.number).monospacedDigit()
                }
            } else {
                Text("Not enough coins").font(Typeface.label)
            }
        }
        .buttonStyle(.secondary)
        .frame(width: canAfford ? 88 : 132)
        .disabled(!canAfford)
        .accessibilityLabel(canAfford ? "Buy for \(price) coins" : "Not enough coins, costs \(price)")
    }
}
