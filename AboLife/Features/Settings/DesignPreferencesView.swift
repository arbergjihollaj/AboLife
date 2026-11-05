import SwiftUI
import UniformTypeIdentifiers

struct DesignPreferencesView: View {
    @EnvironmentObject private var design: AboLifeDesignStore
    @Environment(\.aboLifeStyle) private var style
    @State private var draggedWidget: DashboardWidget?

    var body: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 18) {
                Label("Dein Design", systemImage: "paintpalette")
                    .font(AboLifeTypography.sectionTitle)
                Picker("Design", selection: $design.design) {
                    ForEach(AboLifeDesign.allCases) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.design")
                Text(design.design.subtitle)
                    .foregroundStyle(.secondary)
                Picker("Akzentfarbe", selection: $design.accent) {
                    ForEach(AboLifeAccent.allCases) { Text($0.title).tag($0) }
                }
                Text(
                    "Design und Anordnung werden sofort auf diesem Mac gespeichert. Deine Einträge und die KI-Verbindung bleiben erhalten."
                )
                .font(.caption).foregroundStyle(.secondary)
                if design.design == .bento { widgetEditor }
            }
        }
        .tint(style.colors.action)
    }

    private var widgetEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text("Dashboard anordnen").font(AboLifeTypography.cardTitle)
            Text("Widgets ziehen oder mit den Pfeilen verschieben. Die anderen Widgets rücken nach.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(design.widgets.enumerated()), id: \.element.id) { index, widget in
                HStack(spacing: 12) {
                    Image(systemName: "line.3.horizontal").accessibilityHidden(true)
                    Text(widget.title)
                    Spacer()
                    Button {
                        design.move(widget, offset: -1)
                    } label: {
                        Label("\(widget.title) nach oben", systemImage: "arrow.up")
                    }.labelStyle(.iconOnly).disabled(index == 0)
                    Button {
                        design.move(widget, offset: 1)
                    } label: {
                        Label("\(widget.title) nach unten", systemImage: "arrow.down")
                    }.labelStyle(.iconOnly).disabled(index == design.widgets.count - 1)
                }
                .padding(12)
                .background(style.colors.quietFill, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
                .onDrag {
                    draggedWidget = widget
                    return NSItemProvider(object: widget.rawValue as NSString)
                }
                .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                    guard !providers.isEmpty, let source = draggedWidget else { return false }
                    design.move(source, to: widget)
                    draggedWidget = nil
                    return true
                }
            }
        }
    }
}
