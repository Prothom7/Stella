import SwiftUI
import FirebaseFirestore

struct DashboardView: View {
    private let lessonsByCategory = Dictionary(grouping: LessonTopic.sampleLessons, by: \ .category)
    @State private var selectedTab: DashboardTab = .learning
    @State private var lessonImageURLsByName: [String: String] = [:]
    @State private var didTryLoadLessonImages = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        Text("Stella-board")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("Choose a lesson, learn the science, then open it in immersive AR.")
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundStyle(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    topNavBar

                    learningContent
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .background {
                ZStack {
                    Image("img_10")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()

                    LinearGradient(
                        colors: [Color.black.opacity(0.55), Color.black.opacity(0.38), Color.black.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                guard !didTryLoadLessonImages else { return }
                didTryLoadLessonImages = true
                loadLessonImagesFromFirestore()
            }
            .navigationDestination(for: LessonTopic.self) { lesson in
                LessonDetailView(lesson: lesson)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                    }
                }
            }
        }
    }

    private var topNavBar: some View {
        HStack(spacing: 8) {
            tabButton(.learning)

            NavigationLink {
                TonightSkyView()
            } label: {
                tabPill(.tonight, selected: false)
            }
            .buttonStyle(.plain)

            NavigationLink {
                CelestialCalendarView()
            } label: {
                tabPill(.calendar, selected: false)
            }
            .buttonStyle(.plain)

            NavigationLink {
                NewsView()
            } label: {
                tabPill(.news, selected: false)
            }
            .buttonStyle(.plain)

            NavigationLink {
                ConstellationFinderView()
            } label: {
                tabPill(.finder, selected: false)
            }
            .buttonStyle(.plain)

            NavigationLink {
                ProfileView()
            } label: {
                tabPill(.profile, selected: false)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .zIndex(2)
    }

    private var learningContent: some View {
        VStack(spacing: 18) {
            ForEach(LessonCategory.allCases, id: \.self) { category in
                if let lessons = lessonsByCategory[category], !lessons.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .foregroundStyle(.white.opacity(0.95))
                            Text(category.title)
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 6)

                        ForEach(lessons) { lesson in
                            NavigationLink(value: lesson) {
                                LessonCard(
                                    lesson: lesson,
                                    remoteImageURL: remoteImageURL(for: lesson)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func tabButton(_ tab: DashboardTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            tabPill(tab, selected: selectedTab == tab)
        }
        .buttonStyle(.plain)
    }

    private func tabPill(_ tab: DashboardTab, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: tab.icon)
                .font(.system(size: 12, weight: .bold))
            Text(tab.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(selected ? Color.white.opacity(0.32) : Color.black.opacity(0.3))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(selected ? 0.5 : 0.28), lineWidth: 1.2)
        )
    }

    private func loadLessonImagesFromFirestore() {
        Firestore.firestore().collection("lesson_images").getDocuments { snapshot, error in
            guard error == nil, let documents = snapshot?.documents else { return }

            var mapped: [String: String] = [:]
            for document in documents {
                let data = document.data()
                let name = (data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let url = (data["URL"] as? String) ?? (data["url"] as? String) ?? ""

                guard !name.isEmpty, !url.isEmpty else { continue }
                mapped[normalizedLessonKey(name)] = url
            }

            DispatchQueue.main.async {
                lessonImageURLsByName = mapped
            }
        }
    }

    private func remoteImageURL(for lesson: LessonTopic) -> String? {
        for candidate in lesson.imageLookupNames {
            if let url = lessonImageURLsByName[normalizedLessonKey(candidate)] {
                return url
            }
        }
        return nil
    }

    private func normalizedLessonKey(_ raw: String) -> String {
        raw
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }
}

private enum DashboardTab: CaseIterable {
    case learning
    case tonight
    case calendar
    case news
    case finder
    case profile

    var title: String {
        switch self {
        case .learning: return "Learning"
        case .tonight: return "Tonight"
        case .calendar: return "Calendar"
        case .news: return "News"
        case .finder: return "Finder"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .learning: return "book.closed"
        case .tonight: return "moon.stars.fill"
        case .calendar: return "calendar"
        case .news: return "newspaper"
        case .finder: return "sparkles"
        case .profile: return "person"
        }
    }
}

private struct LessonCard: View {
    let lesson: LessonTopic
    let remoteImageURL: String?

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                cardImageView
                    .frame(maxWidth: .infinity)
                    .frame(height: 152)
                    .clipped()
                    .allowsHitTesting(false)

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: lesson.icon)
                            .font(.system(size: 12, weight: .bold))
                        Text(lesson.category.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.32), in: Capsule())

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 6) {
                Text(lesson.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(lesson.subtitle)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1.2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var cardImageView: some View {
        if let remoteImageURL,
           let url = URL(string: remoteImageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    Image(lesson.cardImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
        } else {
            Image(lesson.cardImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }
}

private struct LessonDetailView: View {
    let lesson: LessonTopic

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: lesson.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(lesson.tint)

                    Text(lesson.title)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(lesson.subtitle)
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                sectionCard {
                    Text(lesson.summary)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                sectionCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Key Facts")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        ForEach(lesson.facts, id: \.self) { fact in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "smallcircle.filled.circle")
                                    .font(.system(size: 10))
                                    .padding(.top, 5)
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(fact)
                                    .font(.system(size: 15, weight: .regular, design: .default))
                                    .foregroundStyle(.white.opacity(0.94))
                            }
                        }
                    }
                }

                sectionCard {
                    NavigationLink {
                        ARAstronomyView(modelFileName: lesson.arModelFileName, topicTitle: lesson.title)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arkit")
                            Text("View in 3D AR")
                                .font(.system(size: 17, weight: .semibold, design: .default))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(lesson.tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            ZStack {
                Image("img_09")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                LinearGradient(
                    colors: [Color.black.opacity(0.5), Color.black.opacity(0.34), Color.black.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.26), lineWidth: 1)
            )
    }
}

private enum LessonCategory: String, CaseIterable, Hashable {
    case planets
    case stars
    case celestialObjects
    case manMadeMissions

    var title: String {
        switch self {
        case .planets:
            return "Planets"
        case .stars:
            return "Stars"
        case .celestialObjects:
            return "Celestial Objects"
        case .manMadeMissions:
            return "Man-Made Missions"
        }
    }

    var icon: String {
        switch self {
        case .planets:
            return "globe.americas.fill"
        case .stars:
            return "star.fill"
        case .celestialObjects:
            return "sparkles"
        case .manMadeMissions:
            return "rocket.fill"
        }
    }
}

private struct LessonTopic: Hashable, Identifiable {
    let id: String
    let title: String
    let imageLookupNames: [String]
    let subtitle: String
    let summary: String
    let facts: [String]
    let icon: String
    let cardImageName: String
    let tint: Color
    let arModelFileName: String
    let category: LessonCategory

    static let sampleLessons: [LessonTopic] = [
        LessonTopic(
            id: "earth",
            title: "Earth",
            imageLookupNames: ["Earth"],
            subtitle: "Our home planet and life support system.",
            summary: "Earth is the only known world to host life and has diverse ecosystems, oceans, and a protective atmosphere.",
            facts: [
                "Earth is about 4.54 billion years old.",
                "Roughly 71% of Earth is covered by water.",
                "Earth has one natural satellite: the Moon."
            ],
            icon: "globe.americas.fill",
            cardImageName: "img_01",
            tint: Color.blue,
            arModelFileName: "earth.usdz",
            category: .planets
        ),
        LessonTopic(
            id: "mars",
            title: "Mars",
            imageLookupNames: ["Mars"],
            subtitle: "The red planet and a future exploration target.",
            summary: "Mars has the largest volcano in the solar system and evidence of ancient rivers and lakes.",
            facts: [
                "A day on Mars is 24.6 hours.",
                "Mars has two moons: Phobos and Deimos.",
                "Olympus Mons is the tallest known volcano in the solar system."
            ],
            icon: "circle.hexagongrid.fill",
            cardImageName: "img_02",
            tint: Color.red,
            arModelFileName: "mars.usdz",
            category: .planets
        ),
        LessonTopic(
            id: "sun",
            title: "The Sun",
            imageLookupNames: ["Sun", "The Sun"],
            subtitle: "The star that powers our solar system.",
            summary: "The Sun is a medium-sized star whose gravity holds the solar system together and drives Earth's climate.",
            facts: [
                "The Sun accounts for about 99.8% of the solar system's mass.",
                "Sunlight takes about 8 minutes to reach Earth.",
                "It is mostly made of hydrogen and helium."
            ],
            icon: "sun.max.fill",
            cardImageName: "img_03",
            tint: Color.orange,
            arModelFileName: "sun.usdz",
            category: .stars
        ),
        LessonTopic(
            id: "moon",
            title: "The Moon",
            imageLookupNames: ["Moon", "The Moon"],
            subtitle: "Earth's natural satellite and nearest neighbor.",
            summary: "The Moon influences ocean tides and records billions of years of solar system history on its cratered surface.",
            facts: [
                "The Moon is about 384,400 km from Earth on average.",
                "It is tidally locked, so we mostly see one side.",
                "Its gravity is about one-sixth of Earth's."
            ],
            icon: "moon.stars.fill",
            cardImageName: "img_04",
            tint: Color.cyan,
            arModelFileName: "moon.usdz",
            category: .celestialObjects
        ),
        LessonTopic(
            id: "iss",
            title: "ISS",
            imageLookupNames: ["ISS", "International Space Station"],
            subtitle: "International Space Station research laboratory.",
            summary: "The ISS is a modular space station where astronauts conduct research in microgravity and test deep-space technologies.",
            facts: [
                "The ISS orbits Earth about every 90 minutes.",
                "It has been continuously occupied since 2000.",
                "It travels at roughly 28,000 km/h."
            ],
            icon: "antenna.radiowaves.left.and.right",
            cardImageName: "img_05",
            tint: Color.indigo,
            arModelFileName: "ISS_stationary.usdz",
            category: .manMadeMissions
        ),
        LessonTopic(
            id: "nasa-missions",
            title: "NASA Missions",
            imageLookupNames: ["NASA Missions", "NASA Mission"],
            subtitle: "Explore major missions and discoveries.",
            summary: "NASA missions have transformed our understanding of Earth, our solar system, and deep space through probes, rovers, and telescopes.",
            facts: [
                "Apollo 11 landed humans on the Moon in 1969.",
                "Voyager probes are in interstellar space.",
                "The James Webb Space Telescope studies the early universe."
            ],
            icon: "rocket.fill",
            cardImageName: "img_06",
            tint: Color.purple,
            arModelFileName: "ISS_stationary.usdz",
            category: .manMadeMissions
        )
    ]
}

#Preview {
    DashboardView()
}
