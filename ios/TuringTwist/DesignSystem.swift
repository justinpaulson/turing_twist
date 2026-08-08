import SwiftUI

enum Newsprint {
    static let ink = Color.black
    static let paper = Color.white
    static let gray = Color(white: 0.93)
    static let midGray = Color(white: 0.78)

    static func headline(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .serif)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct HalftoneBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 10
            for x in stride(from: 4.0, through: size.width, by: spacing) {
                for y in stride(from: 4.0, through: size.height, by: spacing) {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                        with: .color(.black.opacity(0.08))
                    )
                }
            }
        }
        .background(Newsprint.paper)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct Masthead: View {
    var compact = false

    var body: some View {
        VStack(spacing: 8) {
            Text("TURING TWIST")
                .font(Newsprint.headline(compact ? 28 : 44))
                .tracking(compact ? 2 : 4)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Rectangle().frame(height: 2)
            Text("THE AI DECEPTION GAME")
                .font(Newsprint.mono(compact ? 10 : 12, weight: .bold))
                .tracking(2)
            Text("VOL. 1  |  EST. 2025")
                .font(Newsprint.mono(9))
        }
        .padding(compact ? 14 : 22)
        .frame(maxWidth: .infinity)
        .background(Newsprint.paper)
        .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeadline: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Newsprint.headline(25))
                .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().frame(height: 4)
        }
    }
}

struct BoxHeader: View {
    let title: String
    var inverted = true

    var body: some View {
        Text(title.uppercased())
            .font(Newsprint.mono(15, weight: .bold))
            .tracking(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .foregroundStyle(inverted ? Newsprint.paper : Newsprint.ink)
            .background(inverted ? Newsprint.ink : Newsprint.paper)
    }
}

struct NewsprintCardModifier: ViewModifier {
    var padding: CGFloat
    var lineWidth: CGFloat
    var background: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background)
            .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: lineWidth))
    }
}

extension View {
    func newsprintCard(
        padding: CGFloat = 16,
        lineWidth: CGFloat = 4,
        background: Color = Newsprint.paper
    ) -> some View {
        modifier(NewsprintCardModifier(padding: padding, lineWidth: lineWidth, background: background))
    }
}

struct PixelButtonStyle: ButtonStyle {
    var filled = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Newsprint.mono(compact ? 13 : 15, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.6)
            .multilineTextAlignment(.center)
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 10 : 14)
            .frame(maxWidth: compact ? nil : .infinity)
            .foregroundStyle(foreground(configuration))
            .background {
                Rectangle()
                    .fill(background(configuration))
                    .shadow(
                        color: configuration.isPressed ? .clear : Newsprint.ink,
                        radius: 0,
                        x: configuration.isPressed ? 0 : 3,
                        y: configuration.isPressed ? 0 : 3
                    )
            }
            .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
            .offset(x: configuration.isPressed ? 0 : -1, y: configuration.isPressed ? 0 : -1)
    }

    private func foreground(_ configuration: Configuration) -> Color {
        (filled != configuration.isPressed) ? Newsprint.paper : Newsprint.ink
    }

    private func background(_ configuration: Configuration) -> Color {
        (filled != configuration.isPressed) ? Newsprint.ink : Newsprint.paper
    }
}

struct NewsprintTextField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Newsprint.mono(16))
            .autocorrectionDisabled()
            .padding(13)
            .background(Newsprint.paper)
            .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 3))
    }
}

extension View {
    func newsprintField() -> some View { modifier(NewsprintTextField()) }
}

struct CharacterAvatar: View {
    let name: String?
    var size: CGFloat = 64
    var inverted = true

    var body: some View {
        Group {
            if let name {
                Image(name)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Text("?")
                    .font(Newsprint.mono(size * 0.55, weight: .black))
            }
        }
        .padding(size * 0.08)
        .frame(width: size, height: size)
        .background(inverted ? Newsprint.ink : Newsprint.paper)
        .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 3))
        .accessibilityHidden(true)
    }
}

struct ProfileLinkButton: View {
    let user: User?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(initial)
                    .font(Newsprint.headline(27))
                    .foregroundStyle(Newsprint.paper)
                    .frame(width: 44, height: 44)
                    .background(Newsprint.ink)

                Text("PROFILE")
                    .font(Newsprint.mono(8, weight: .black))
                    .tracking(0.5)
            }
            .padding(6)
            .background {
                Rectangle()
                    .fill(Newsprint.paper)
                    .shadow(color: Newsprint.ink, radius: 0, x: 3, y: 3)
            }
            .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit profile")
    }

    private var initial: String {
        if let first = user?.displayName?.first(where: { !$0.isWhitespace }) {
            return String(first).uppercased()
        }
        if let first = user?.emailAddress.first {
            return String(first).uppercased()
        }
        return "?"
    }
}

struct NewsprintBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
        }
        .buttonStyle(NewsprintBackButtonStyle())
        .accessibilityLabel("Back")
    }
}

private struct NewsprintBackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .black))
            .foregroundStyle(configuration.isPressed ? Newsprint.ink : Newsprint.paper)
            .frame(width: 44, height: 44)
            .background {
                Rectangle()
                    .fill(configuration.isPressed ? Newsprint.paper : Newsprint.ink)
                    .shadow(
                        color: configuration.isPressed ? .clear : Newsprint.ink,
                        radius: 0,
                        x: configuration.isPressed ? 0 : 3,
                        y: configuration.isPressed ? 0 : 3
                    )
            }
            .overlay(Rectangle().stroke(Newsprint.ink, lineWidth: 4))
            .offset(x: configuration.isPressed ? 0 : -1, y: configuration.isPressed ? 0 : -1)
    }
}

struct LoadingView: View {
    @State private var blockVisible = true

    var body: some View {
        HStack(spacing: 7) {
            Text("LOADING")
            Text("█").opacity(blockVisible ? 1 : 0)
        }
        .font(Newsprint.mono(18, weight: .bold))
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                blockVisible.toggle()
            }
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text("⚠ \(message)")
            .font(Newsprint.mono(13, weight: .bold))
            .foregroundStyle(Newsprint.paper)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(Newsprint.ink)
            .accessibilityLabel("Error: \(message)")
    }
}

struct PageContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            HalftoneBackground()
            ScrollView {
                content()
                    .frame(maxWidth: 920)
                    .padding(16)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
