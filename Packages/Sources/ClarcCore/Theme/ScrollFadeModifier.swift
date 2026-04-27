import SwiftUI

public struct ScrollFadeModifier: ViewModifier {
    let fadeWidth: CGFloat
    let backgroundColor: Color

    public init(fadeWidth: CGFloat = 24, backgroundColor: Color = ClaudeTheme.surfaceElevated) {
        self.fadeWidth = fadeWidth
        self.backgroundColor = backgroundColor
    }

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                LinearGradient(
                    colors: [backgroundColor, backgroundColor.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [backgroundColor.opacity(0), backgroundColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: fadeWidth)
                .allowsHitTesting(false)
            }
    }
}

extension View {
    public func scrollFadeEdges(
        fadeWidth: CGFloat = 24,
        backgroundColor: Color = ClaudeTheme.surfaceElevated
    ) -> some View {
        modifier(ScrollFadeModifier(fadeWidth: fadeWidth, backgroundColor: backgroundColor))
    }
}
