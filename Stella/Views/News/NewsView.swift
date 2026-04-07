import SwiftUI
import Combine
import SafariServices

struct NewsView: View {
    @StateObject private var viewModel = AstronomyNewsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                introCard

                if viewModel.isLoading {
                    ProgressView("Loading astronomy news...")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.42))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                }

                if let errorMessage = viewModel.errorMessage {
                    errorCard(errorMessage)
                }

                ForEach(viewModel.articles) { article in
                    articleCard(article)
                }
            }
            .padding(16)
        }
        .navigationTitle("Astronomy News")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.95), Color(red: 0.06, green: 0.1, blue: 0.2), Color.black.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 260, height: 260)
                    .blur(radius: 36)
                    .offset(x: -120, y: -220)

                Circle()
                    .fill(Color.cyan.opacity(0.12))
                    .frame(width: 220, height: 220)
                    .blur(radius: 38)
                    .offset(x: 130, y: 280)
            }
        }
        .task {
            await viewModel.loadNews()
        }
    }

    private var introCard: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Astronomy News")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Live space headlines from trusted astronomy sources.")
                .font(.system(size: 15, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.96))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 10)
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("News Unavailable", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.92))

            Button {
                Task {
                    await viewModel.loadNews(forceRefresh: true)
                }
            } label: {
                Text("Try Again")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }

    private func articleCard(_ article: NASANewsArticle) -> some View {
        NavigationLink {
            NewsArticleWebView(article: article)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(article.title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(article.newsSite)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(article.formattedDate)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text(article.excerpt)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.93))
                    .lineLimit(4)

                HStack(spacing: 6) {
                    Text("Read Full Story")
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.18))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct NewsArticleWebView: View {
    let article: NASANewsArticle

    var body: some View {
        SafariView(url: article.linkURL)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(article.newsSite)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = .white
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
    }
}

@MainActor
private final class AstronomyNewsViewModel: ObservableObject {
    @Published private(set) var articles: [NASANewsArticle] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func loadNews(forceRefresh: Bool = false) async {
        if isLoading { return }
        if !forceRefresh && !articles.isEmpty { return }

        isLoading = true
        errorMessage = nil

        do {
            let urlString = "https://api.spaceflightnewsapi.net/v4/articles/?limit=18"
            guard let url = URL(string: urlString) else {
                throw URLError(.badURL)
            }

            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let responsePayload = try JSONDecoder().decode(SpaceflightNewsResponse.self, from: data)

            articles = responsePayload.results.map {
                NASANewsArticle(
                    id: $0.id,
                    title: $0.title,
                    excerpt: $0.summary.cleanedHTML,
                    date: $0.publishedAt.parsedISODate,
                    link: $0.url,
                    newsSite: $0.newsSite
                )
            }
        } catch {
            errorMessage = "Couldn't load astronomy news right now. Please try again."
        }

        isLoading = false
    }
}

private struct NASANewsArticle: Identifiable {
    let id: Int
    let title: String
    let excerpt: String
    let date: Date
    let link: String
    let newsSite: String

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var linkURL: URL {
        URL(string: link) ?? URL(string: "https://api.spaceflightnewsapi.net/")!
    }
}

private struct SpaceflightNewsResponse: Decodable {
    let results: [SpaceflightNewsItem]
}

private struct SpaceflightNewsItem: Decodable {
    let id: Int
    let title: String
    let url: String
    let summary: String
    let publishedAt: String
    let newsSite: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case summary
        case publishedAt = "published_at"
        case newsSite = "news_site"
    }
}

private extension String {
    var cleanedHTML: String {
        var value = self
        value = value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: "&nbsp;", with: " ")
        value = value.replacingOccurrences(of: "&#8217;", with: "'")
        value = value.replacingOccurrences(of: "&#8211;", with: "-")
        value = value.replacingOccurrences(of: "&#8220;", with: "\"")
        value = value.replacingOccurrences(of: "&#8221;", with: "\"")
        value = value.replacingOccurrences(of: "&amp;", with: "&")
        value = value.replacingOccurrences(of: "\\n", with: " ")

        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var parsedISODate: Date {
        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatterWithFraction.date(from: self) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self) ?? Date()
    }
}

#Preview {
    NavigationStack {
        NewsView()
    }
}
