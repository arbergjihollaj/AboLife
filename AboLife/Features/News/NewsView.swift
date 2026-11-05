import SwiftUI

struct NewsView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @StateObject private var store: NewsStore
    @State private var refreshToken = 0
    @State private var visibleLimit = 50
    private var onAI: (([NewsArticle]) -> Void)?
    init(database: AppDatabase?, onAI: (([NewsArticle]) -> Void)? = nil) {
        _store = StateObject(wrappedValue: NewsStore(database: database))
        self.onAI = onAI
    }
    private var refreshKey: String {
        store.preferences.enabledSources.sorted().joined(separator: ",") + "/\(refreshToken)"
    }
    var body: some View {
        let visible = store.visible
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AboLifeSpacing.section) {
                header(articles: visible)
                filters
                if let message = store.message {
                    AboLifeNotice(title: "Nachrichtenstatus", message: message, systemImage: "wifi.exclamationmark")
                }
                if store.isLoading { ProgressView("Meldungen laden …").controlSize(.small) }
                if !store.isLoading && visible.isEmpty { emptyState }
                ForEach(visible.prefix(visibleLimit)) { article in
                    NewsArticleCard(
                        article: article, isRead: store.preferences.read.contains(article.id),
                        isSaved: store.preferences.saved.contains(article.id),
                        toggleRead: { store.toggleRead(article) }, toggleSaved: { store.toggleSaved(article) })
                }
                if visible.count > visibleLimit {
                    Button("Weitere Meldungen anzeigen (\(visible.count - visibleLimit))") { visibleLimit += 50 }
                        .buttonStyle(.bordered)
                }
                Text(
                    "Privater RSS-Reader · Originalartikel öffnen bei der Quelle. Die Merkliste filtert die geladenen Meldungen."
                )
                .font(AboLifeTypography.caption).foregroundStyle(designStyle.colors.secondaryText)
            }.aboLifePage()
        }
        .background { AboLifePremiumBackground() }
        .task(id: refreshKey) { await store.refresh(force: true) }
        .onChange(of: store.preferences.enabledSources) { _, _ in store.savePreferences() }
        .onChange(of: store.preferences.excludedWords) { _, _ in store.savePreferences() }
    }
    private func header(articles: [NewsArticle]) -> some View {
        VStack(alignment: .leading, spacing: AboLifeSpacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nachrichten").font(AboLifeTypography.dashboardTitle)
                    Text(
                        store.loadedAt.map {
                            "Stand \($0.formatted(date: .abbreviated, time: .shortened)) · \(articles.count) Meldungen"
                        } ?? "Welt, Technik, Wissen und Sport"
                    )
                    .font(AboLifeTypography.body).foregroundStyle(designStyle.colors.secondaryText)
                }
                Spacer(minLength: 8)
                Button("Nachrichten aktualisieren", systemImage: "arrow.clockwise") { refreshToken += 1 }
                    .labelStyle(.iconOnly).buttonStyle(.bordered).disabled(store.isLoading)
            }
            if let onAI {
                Button("Mit AboLife AI einordnen", systemImage: "bubble.left.and.text.bubble.right") { onAI(articles) }
                    .buttonStyle(.bordered).disabled(store.isLoading || articles.isEmpty)
            }
        }.foregroundStyle(designStyle.colors.primaryText)
    }
    private var filters: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: AboLifeSpacing.medium) {
                TextField("Schlagzeilen suchen", text: $store.search).textFieldStyle(.roundedBorder).accessibilityLabel(
                    "Schlagzeilen suchen")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) {
                        categoryPicker; readFilters
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        categoryPicker; readFilters
                    }
                }
                DisclosureGroup("Quellen & Ausschlusswörter") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(NewsSource.defaults) { source in
                            Toggle(
                                source.title,
                                isOn: Binding(
                                    get: { store.preferences.enabledSources.contains(source.id) },
                                    set: { enabled in
                                        if enabled {
                                            store.preferences.enabledSources.insert(source.id)
                                        } else {
                                            store.preferences.enabledSources.remove(source.id)
                                        }
                                    }))
                        }
                        TextField("Wörter mit Komma trennen", text: $store.preferences.excludedWords).textFieldStyle(
                            .roundedBorder)
                    }.padding(.top, 12).disabled(!store.preferencesAvailable)
                }
            }
        }
    }
    private var categoryPicker: some View {
        Picker("Thema", selection: $store.category) {
            ForEach(["Alle", "Welt", "Technik", "Wissen", "Sport"], id: \.self) { Text($0) }
        }.frame(maxWidth: 240)
    }
    private var readFilters: some View {
        HStack(spacing: 16) {
            Toggle("Merkliste", isOn: $store.onlySaved)
            Toggle("Ungelesen", isOn: $store.hideRead)
        }.fixedSize()
    }
    private var emptyState: some View {
        ContentUnavailableView(
            store.preferences.enabledSources.isEmpty ? "Keine Quelle ausgewählt" : "Keine passenden Meldungen",
            systemImage: "newspaper",
            description: Text(
                store.preferences.enabledSources.isEmpty
                    ? "Aktiviere unter „Quellen & Ausschlusswörter“ mindestens eine Nachrichtenquelle."
                    : "Passe Suche, Thema oder Lesefilter an. Die Merkliste berücksichtigt die aktuell geladenen Meldungen."
            ))
    }
}
