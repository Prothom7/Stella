import SwiftUI
import FirebaseAuth

struct DashboardView: View {
    private let lessons = LessonTopic.sampleLessons

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Learning Dashboard")
                            .font(.system(size: 33, weight: .bold, design: .rounded))
                        Text("Explore planets, stars, NASA missions, and space stations in AR.")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    ForEach(lessons) { lesson in
                        NavigationLink(value: lesson) {
                            LessonCard(lesson: lesson)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.97, blue: 1.0), Color(red: 0.9, green: 0.94, blue: 0.99)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationDestination(for: LessonTopic.self) { lesson in
                LessonDetailView(lesson: lesson)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        try? Auth.auth().signOut()
                    }
                    .font(.system(size: 14, weight: .semibold, design: .default))
                }
            }
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
                        .foregroundStyle(lesson.tint)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(lesson.title)
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                Text(lesson.subtitle)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
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
        }
        .navigationTitle("Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(red: 0.97, green: 0.98, blue: 1.0).ignoresSafeArea())
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
            arModelFileName: "earth.usdz"
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
            arModelFileName: "mars.usdz"
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
            arModelFileName: "sun.usdz"
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
            arModelFileName: "ISS_stationary.usdz"
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
            arModelFileName: "ISS_stationary.usdz"
        )
    ]
}

#Preview {
    DashboardView()
}
