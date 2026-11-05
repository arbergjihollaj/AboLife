import SwiftUI

struct NewsArticleCard: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let article: NewsArticle
    let isRead: Bool
    let isSaved: Bool
    let toggleRead: () -> Void
    let toggleSaved: () -> Void
    var body: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: AboLifeSpacing.medium) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(article.source) · \(article.category)").font(AboLifeTypography.caption)
                    Spacer(minLength: 8)
                    Text(isRead ? "Gelesen" : "Ungelesen").font(AboLifeTypography.micro)
                }.foregroundStyle(designStyle.colors.secondaryText)
                Link(article.title, destination: article.url).font(AboLifeTypography.sectionTitle)
                    .foregroundStyle(designStyle.colors.primaryText).fixedSize(horizontal: false, vertical: true)
                Text(
                    article.publishedAt.map { $0.formatted(date: .abbreviated, time: .shortened) }
                        ?? "Veröffentlichungsdatum nicht übermittelt"
                )
                .font(AboLifeTypography.caption).foregroundStyle(designStyle.colors.secondaryText)
                ViewThatFits(in: .horizontal) {
                    HStack {
                        actions; Spacer(); originalLink
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        actions; originalLink
                    }
                }.font(AboLifeTypography.caption)
            }
        }
    }
    private var actions: some View {
        HStack(spacing: 12) {
            Button(
                isRead ? "Wieder ungelesen" : "Als gelesen markieren",
                systemImage: isRead ? "checkmark.circle.fill" : "checkmark.circle", action: toggleRead)
            Button(
                isSaved ? "Gemerkt" : "Merken", systemImage: isSaved ? "bookmark.fill" : "bookmark", action: toggleSaved
            )
        }.buttonStyle(.borderless)
    }
    private var originalLink: some View {
        Link(destination: article.url) { Label("Originalartikel", systemImage: "arrow.up.right") }
            .accessibilityLabel("Originalartikel bei \(article.source) öffnen")
    }
}
