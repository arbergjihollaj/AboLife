import SwiftUI

struct FloatingQuickAddBar: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let actions: [QuickAddAction]
    let onActivate: (QuickAddKind) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            dockContent

            ScrollView(.horizontal, showsIndicators: false) {
                dockContent
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(designStyle.colors.elevatedCardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(designStyle.colors.glassStroke)
                }
        }
    }

    private var dockContent: some View {
        HStack(spacing: 8) {
            ForEach(actions) { action in
                Button {
                    onActivate(action.kind)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
                .buttonStyle(AboLifeActionStyle())
                .accessibilityIdentifier("quickadd.\(action.kind.rawValue)")
                .tint(designStyle.colors.primaryText)
            }

            Rectangle()
                .fill(designStyle.colors.glassStrokeMuted)
                .frame(width: 1, height: 20)
                .accessibilityHidden(true)

            Button {
                onActivate(.general)
            } label: {
                Label("Eintragen", systemImage: "plus")
            }
            .buttonStyle(AboLifeActionStyle(isProminent: true))
        }
        .font(AboLifeTypography.cardTitle)
        .controlSize(.large)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct FloatingQuickAddBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AboLifePremiumBackground()
            FloatingQuickAddBar(actions: QuickAddAction.bottomDockActions) { _ in }
                .padding()
        }
        .frame(width: 720, height: 180)
    }
}
