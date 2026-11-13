import SwiftUI

enum ScreenOCRDesign {
    static let cornerRadius: CGFloat = 12
    static let popoverWidth: CGFloat = 360
    static let accent = Color(red: 0, green: 0.478, blue: 1.0)
    static let accentSecondary = Color(red: 0, green: 0.388, blue: 0.855)

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct ScreenOCRCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: ScreenOCRDesign.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ScreenOCRDesign.cornerRadius)
                    .strokeBorder(.quaternary.opacity(0.6), lineWidth: 1)
            )
    }
}

extension View {
    func screenOCRCard() -> some View {
        modifier(ScreenOCRCardModifier())
    }
}

struct SourceBadge: View {
    let source: OCRHistoryEntry.Source

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source == .captured ? "viewfinder" : "doc.on.doc")
            Text(source == .captured ? "Captured" : "Copied")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            source == .captured
                ? AnyShapeStyle(ScreenOCRDesign.brandGradient.opacity(0.85))
                : AnyShapeStyle(Color.secondary.opacity(0.15))
        )
        .foregroundStyle(source == .captured ? Color.white : Color.primary)
        .clipShape(Capsule())
    }
}

struct StepNumberBadge: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(ScreenOCRDesign.brandGradient, in: Circle())
    }
}

struct HoverRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HoverRowLabel(configuration: configuration)
    }

    private struct HoverRowLabel: View {
        let configuration: Configuration
        @State private var hovered = false

        var body: some View {
            configuration.label
                .background(rowBackground(isPressed: configuration.isPressed))
                .onHover { hovered = $0 }
        }

        @ViewBuilder
        private func rowBackground(isPressed: Bool) -> some View {
            let active = isPressed || hovered
            RoundedRectangle(cornerRadius: 8)
                .fill(active ? Color.primary.opacity(0.08) : Color.clear)
                .padding(.horizontal, 6)
        }
    }
}

struct WelcomeProgressBar: View {
    let page: Int
    let pageCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? ScreenOCRDesign.accent.opacity(0.95) : Color.secondary.opacity(0.18))
                    .frame(height: 4)
            }
        }
    }
}
