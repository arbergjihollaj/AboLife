import SwiftUI

struct AboLifeCard<Content: View>: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @Environment(\.colorSchemeContrast) private var contrast
    private let content: Content
    private let minHeight: CGFloat?
    private let isProminent: Bool
    private var cornerRadius: CGFloat {
        designStyle.design == .bento ? 22 : designStyle.design == .fieldnotes ? 6 : 20
    }

    init(minHeight: CGFloat? = nil, isProminent: Bool = false, @ViewBuilder content: () -> Content) {
        self.minHeight = minHeight
        self.isProminent = isProminent
        self.content = content()
    }

    var body: some View {
        content
            .padding(isProminent ? AboLifeSpacing.page : AboLifeSpacing.section)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(designStyle.colors.cardBackground.opacity(designStyle.design == .spatial ? 0.82 : 1))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(
                            contrast == .increased
                                ? designStyle.colors.glassStroke : designStyle.colors.glassStrokeMuted,
                            lineWidth: contrast == .increased ? 1.5 : 1)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct AboLifeGlassCapsule<Content: View>: View {
    @Environment(\.aboLifeStyle) private var designStyle
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(designStyle.colors.quietFill)
                    .strokeBorder(designStyle.colors.glassStrokeMuted)
            }
    }
}
