import SwiftUI

struct AboLifeCard<Content: View>: View {
    private let content: Content
    private let minHeight: CGFloat?
    private let isProminent: Bool
    private var cornerRadius: CGFloat {
        isProminent ? 22 : 18
    }

    init(minHeight: CGFloat? = nil, isProminent: Bool = false, @ViewBuilder content: () -> Content) {
        self.minHeight = minHeight
        self.isProminent = isProminent
        self.content = content()
    }

    var body: some View {
        content
            .padding(isProminent ? 20 : 15)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background {
                AboLifeLiquidGlassSurface(
                    shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                    tint: isProminent ? AboLifeColors.review.opacity(0.12) : nil,
                    isProminent: isProminent
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: AboLifeColors.shadow.opacity(isProminent ? 0.34 : 0.20), radius: isProminent ? 18 : 10, x: 0, y: isProminent ? 12 : 7)
    }
}

struct AboLifeGlassCapsule<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                AboLifeLiquidGlassSurface(
                    shape: Capsule(),
                    tint: AboLifeColors.review.opacity(0.06),
                    isProminent: false
                )
            }
    }
}

struct AboLifeGlassEffectGroup<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
    }
}

struct AboLifeLiquidGlassSurface<S: InsettableShape>: View {
    let shape: S
    var tint: Color? = nil
    var isProminent = false
    var isInteractive = false

    var body: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape
                    .fill(Color.white.opacity(isProminent ? 0.010 : 0.006))
            }
            .overlay {
                shape
                    .fill(AboLifeColors.glassSurfaceGradient)
                    .opacity(isProminent ? 0.46 : 0.32)
                    .blendMode(.screen)
            }
            .overlay(alignment: .topLeading) {
                shape
                    .fill(AboLifeColors.liquidSpecularGradient)
                    .opacity(isProminent ? 0.38 : 0.24)
                    .blendMode(.screen)
            }
            .overlay(alignment: .bottomTrailing) {
                shape
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(isProminent ? 0.026 : 0.014),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 12,
                            endRadius: isProminent ? 300 : 190
                        )
                    )
                    .blendMode(.screen)
            }
            .overlay {
                shape
                    .strokeBorder(AboLifeColors.glassStroke, lineWidth: isProminent ? 0.95 : 0.65)
            }
            .overlay {
                shape
                    .inset(by: 1)
                    .strokeBorder(AboLifeColors.liquidGlassEdgeGradient, lineWidth: isProminent ? 0.9 : 0.6)
            }
    }
}
