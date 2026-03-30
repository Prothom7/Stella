import SwiftUI
import FirebaseAuth

struct DashboardView: View {
    private let lessonsByCategory = Dictionary(grouping: LessonTopic.sampleLessons, by: \ .category)
    @State private var selectedTab: DashboardTab = .learning

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Text("Stella-board")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text("Choose a lesson, learn the science, then open it in immersive AR.")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 20)

                    topNavBar

                    Group {
                        switch selectedTab {
                        case .learning:
                            learningContent
                        case .calendar:
                            quickAccessCard(
                                icon: "calendar.badge.clock",
                                title: "Celestial Calendar",
                                subtitle: "Track major astronomical events and set reminders.",
                                buttonTitle: "Open Calendar"
                            ) {
                                CelestialCalendarView()
                            }
                        case .finder:
                            quickAccessCard(
                                icon: "sparkles.square.filled.on.square",
                                title: "Constellation Finder",
                                subtitle: "Detect constellations from sky or image and overlay them.",
                                buttonTitle: "Open Finder"
                            ) {
                                ConstellationFinderView()
                            }
                        case .profile:
                            quickAccessCard(
                                icon: "person.crop.circle",
                                title: "Profile",
                                subtitle: "Manage your account and sign out securely.",
                                buttonTitle: "Open Profile"
                            ) {
                                ProfileView()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
                .padding(.bottom, 24)
            }
            .background {
                ZStack {
                    Image("img_05")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()

                    LinearGradient(
                        colors: [Color.black.opacity(0.5), Color.black.opacity(0.3), Color.black.opacity(0.56)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
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
        HStack(spacing: 10) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .bold))
                        Text(tab.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selectedTab == tab ? Color.white.opacity(0.26) : Color.black.opacity(0.24))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(selectedTab == tab ? 0.42 : 0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.26), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private var learningContent: some View {
        VStack(spacing: 18) {
            NavigationLink {
                CelestialCalendarView()
            } label: {
                featureRow(
                    icon: "calendar.badge.clock",
                    title: "Celestial Calendar",
                    subtitle: "Major astronomical events for the year"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ConstellationFinderView()
            } label: {
                featureRow(
                    icon: "sparkles.square.filled.on.square",
                    title: "Constellation Finder",
                    subtitle: "Use AR overlay to match constellations in the sky"
                )
            }
            .buttonStyle(.plain)

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
                                LessonCard(lesson: lesson)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func quickAccessCard<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        buttonTitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)

            NavigationLink {
                destination()
            } label: {
                Text(buttonTitle)
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.2), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(14)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }
}

private enum DashboardTab: CaseIterable {
    case learning
    case calendar
    case finder
    case profile

    var title: String {
        switch self {
        case .learning: return "Learning"
        case .calendar: return "Calendar"
        case .finder: return "Finder"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .learning: return "book.closed"
        case .calendar: return "calendar"
        case .finder: return "sparkles"
        case .profile: return "person"
        }
    }
}

private struct LessonCard: View {
    let lesson: LessonTopic

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(lesson.tint.opacity(0.18))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: lesson.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(lesson.title)
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                Text(lesson.subtitle)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 14, x: 0, y: 10)
    }
}

private struct LessonDetailView: View {
    let lesson: LessonTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: lesson.icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(lesson.tint)
                        .frame(width: 52, height: 52)
                        .background(lesson.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lesson.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(lesson.subtitle)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(lesson.summary)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.95))

                Text("Key Facts")
                    .font(.system(size: 19, weight: .semibold, design: .default))
                    .padding(.top, 8)

                ForEach(lesson.facts, id: \.self) { fact in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "smallcircle.filled.circle")
                            .font(.system(size: 10))
                            .padding(.top, 5)
                        Text(fact)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundStyle(.white.opacity(0.94))
                    }
                }

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
                .padding(.top, 8)
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            )
            .padding(16)
        }
        .navigationTitle("Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            ZStack {
                Image("img_01")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                Color.black.opacity(0.42).ignoresSafeArea()
            }
        }
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
    let subtitle: String
    let summary: String
    let facts: [String]
    let icon: String
    let tint: Color
    let arModelFileName: String
    let category: LessonCategory

    static let sampleLessons: [LessonTopic] = [
        LessonTopic(
            id: "earth",
            title: "Earth",
            subtitle: "Our home planet and life support system.",
            summary: "Earth is the only known world to host life and has diverse ecosystems, oceans, and a protective atmosphere.",
            facts: [
                "Earth is about 4.54 billion years old.",
                "Roughly 71% of Earth is covered by water.",
                "Earth has one natural satellite: the Moon."
            ],
            icon: "globe.americas.fill",
            tint: Color.blue,
            arModelFileName: "earth.usdz",
            category: .planets
        ),
        LessonTopic(
            id: "mars",
            title: "Mars",
            subtitle: "The red planet and a future exploration target.",
            summary: "Mars has the largest volcano in the solar system and evidence of ancient rivers and lakes.",
            facts: [
                "A day on Mars is 24.6 hours.",
                "Mars has two moons: Phobos and Deimos.",
                "Olympus Mons is the tallest known volcano in the solar system."
            ],
            icon: "circle.hexagongrid.fill",
            tint: Color.red,
            arModelFileName: "mars.usdz",
            category: .planets
        ),
        LessonTopic(
            id: "sun",
            title: "The Sun",
            subtitle: "The star that powers our solar system.",
            summary: "The Sun is a medium-sized star whose gravity holds the solar system together and drives Earth's climate.",
            facts: [
                "The Sun accounts for about 99.8% of the solar system's mass.",
                "Sunlight takes about 8 minutes to reach Earth.",
                "It is mostly made of hydrogen and helium."
            ],
            icon: "sun.max.fill",
            tint: Color.orange,
            arModelFileName: "sun.usdz",
            category: .stars
        ),
        LessonTopic(
            id: "moon",
            title: "The Moon",
            subtitle: "Earth's natural satellite and nearest neighbor.",
            summary: "The Moon influences ocean tides and records billions of years of solar system history on its cratered surface.",
            facts: [
                "The Moon is about 384,400 km from Earth on average.",
                "It is tidally locked, so we mostly see one side.",
                "Its gravity is about one-sixth of Earth's."
            ],
            icon: "moon.stars.fill",
            tint: Color.cyan,
            arModelFileName: "moon.usdz",
            category: .celestialObjects
        ),
        LessonTopic(
            id: "iss",
            title: "ISS",
            subtitle: "International Space Station research laboratory.",
            summary: "The ISS is a modular space station where astronauts conduct research in microgravity and test deep-space technologies.",
            facts: [
                "The ISS orbits Earth about every 90 minutes.",
                "It has been continuously occupied since 2000.",
                "It travels at roughly 28,000 km/h."
            ],
            icon: "antenna.radiowaves.left.and.right",
            tint: Color.indigo,
            arModelFileName: "ISS_stationary.usdz",
            category: .manMadeMissions
        ),
        LessonTopic(
            id: "nasa-missions",
            title: "NASA Missions",
            subtitle: "Explore major missions and discoveries.",
            summary: "NASA missions have transformed our understanding of Earth, our solar system, and deep space through probes, rovers, and telescopes.",
            facts: [
                "Apollo 11 landed humans on the Moon in 1969.",
                "Voyager probes are in interstellar space.",
                "The James Webb Space Telescope studies the early universe."
            ],
            icon: "rocket.fill",
            tint: Color.purple,
            arModelFileName: "ISS_stationary.usdz",
            category: .manMadeMissions
        )
    ]
}

#Preview {
    DashboardView()
}
