import SwiftUI
import FirebaseFirestore
import CoreLocation
import Combine

struct DashboardView: View {
    private let lessonsByCategory = Dictionary(grouping: LessonTopic.sampleLessons, by: \ .category)
    @State private var selectedTab: DashboardTab = .learning
    @State private var lessonImageURLsByName: [String: String] = [:]
    @StateObject private var locationManager = DashboardLocationManager()
    @State private var weatherSnapshot: DashboardWeatherSnapshot?
    @State private var isWeatherLoading = false
    @State private var weatherErrorMessage: String?
    @State private var lastWeatherCoordinateKey: String?

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

                    weatherCard
                        .padding(.horizontal, 16)

                    learningContent
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .background {
                ZStack {
                    Image("img_11")
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
                loadLessonImagesFromFirestore()
                locationManager.start()
            }
            .onReceive(locationManager.$location) { location in
                guard let location else { return }
                fetchWeather(for: location)
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
        let candidates = lesson.imageLookupNames + [lesson.title]

        for candidate in candidates {
            let candidateKey = normalizedLessonKey(candidate)
            if let url = lessonImageURLsByName[candidateKey] {
                return url
            }
        }

        for candidate in candidates {
            let candidateKey = normalizedLessonKey(candidate)
            if let looseMatch = lessonImageURLsByName.first(where: { key, _ in
                key.contains(candidateKey) || candidateKey.contains(key)
            }) {
                return looseMatch.value
            }
        }

        return nil
    }

    private func normalizedLessonKey(_ raw: String) -> String {
        raw
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    private var weatherCard: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Local Sky")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            if let weatherSnapshot {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: weatherSnapshot.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.1), in: Circle())

                    VStack(alignment: .center, spacing: 2) {
                        Text("\(weatherSnapshot.temperatureC)°")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)

                        Text(weatherSnapshot.summary)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                    }
                }

                HStack(spacing: 8) {
                    metricChip(label: "Cloud", value: "\(weatherSnapshot.cloudCover)%")
                    metricChip(label: "Wind", value: "\(weatherSnapshot.windSpeedKmh) km/h")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else if isWeatherLoading {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Fetching weather...")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else if let weatherErrorMessage {
                Text(weatherErrorMessage)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(.white.opacity(0.84))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }

            Text(locationManager.statusText)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            if locationManager.shouldShowRequestButton {
                Button {
                    locationManager.requestPermission()
                } label: {
                    Text("Enable Location")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.94))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func metricChip(label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: Capsule())
    }

    private func fetchWeather(for location: CLLocation) {
        let coordinateKey = String(format: "%.2f,%.2f", location.coordinate.latitude, location.coordinate.longitude)
        guard coordinateKey != lastWeatherCoordinateKey else { return }

        lastWeatherCoordinateKey = coordinateKey
        isWeatherLoading = true
        weatherErrorMessage = nil

        Task {
            do {
                let latitude = location.coordinate.latitude
                let longitude = location.coordinate.longitude
                let endpoint = String(
                    format: "https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current=temperature_2m,weather_code,cloud_cover,wind_speed_10m&timezone=auto",
                    latitude,
                    longitude
                )

                guard let url = URL(string: endpoint) else {
                    await MainActor.run {
                        isWeatherLoading = false
                        weatherErrorMessage = "Could not build weather request URL."
                    }
                    return
                }

                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    await MainActor.run {
                        isWeatherLoading = false
                        weatherErrorMessage = "Weather service is currently unavailable."
                    }
                    return
                }

                let decoded = try JSONDecoder().decode(OpenMeteoCurrentResponse.self, from: data)
                let snapshot = DashboardWeatherSnapshot(
                    temperatureC: Int(decoded.current.temperature_2m.rounded()),
                    weatherCode: decoded.current.weather_code,
                    cloudCover: Int(decoded.current.cloud_cover.rounded()),
                    windSpeedKmh: Int(decoded.current.wind_speed_10m.rounded())
                )

                await MainActor.run {
                    weatherSnapshot = snapshot
                    isWeatherLoading = false
                    weatherErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    isWeatherLoading = false
                    weatherErrorMessage = "Unable to fetch live weather right now."
                }
            }
        }
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

private struct OpenMeteoCurrentResponse: Decodable {
    let current: OpenMeteoCurrent
}

private struct OpenMeteoCurrent: Decodable {
    let temperature_2m: Double
    let weather_code: Int
    let cloud_cover: Double
    let wind_speed_10m: Double
}

private struct DashboardWeatherSnapshot {
    let temperatureC: Int
    let weatherCode: Int
    let cloudCover: Int
    let windSpeedKmh: Int

    var summary: String {
        switch weatherCode {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55, 56, 57: return "Drizzle"
        case 61, 63, 65, 66, 67: return "Rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Variable conditions"
        }
    }

    var symbolName: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 80, 81, 82: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

private final class DashboardLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var shouldShowRequestButton: Bool {
        authorizationStatus == .notDetermined || authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var statusText: String {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let location {
                return String(format: "Using latitude %.2f, longitude %.2f", location.coordinate.latitude, location.coordinate.longitude)
            }
            return "Determining your location for local weather..."
        case .notDetermined:
            return "Enable location to show live weather for your sky conditions."
        case .denied, .restricted:
            return "Location is off. Turn it on to personalize weather visibility."
        @unknown default:
            return "Location status unavailable right now."
        }
    }

    func start() {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func requestPermission() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.location = locations.last
            manager.stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Dashboard location error: \(error.localizedDescription)")
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
                Image("img_10")
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
            id: "mercury",
            title: "Mercury",
            imageLookupNames: ["Mercury"],
            subtitle: "The smallest and innermost planet.",
            summary: "Mercury is a rocky world with extreme temperature swings and a heavily cratered surface shaped by impacts.",
            facts: [
                "A Mercurian year is just 88 Earth days.",
                "Mercury has almost no atmosphere to trap heat.",
                "It has no natural moons."
            ],
            icon: "circle.fill",
            cardImageName: "img_07",
            tint: Color.gray,
            arModelFileName: "mercury.usdz",
            category: .planets
        ),
        LessonTopic(
            id: "venus",
            title: "Venus",
            imageLookupNames: ["Venus"],
            subtitle: "Earth-size planet with a runaway greenhouse climate.",
            summary: "Venus is wrapped in thick carbon dioxide clouds and has the hottest surface of any planet in our solar system.",
            facts: [
                "Venus rotates in the opposite direction of most planets.",
                "Its surface temperature is around 465 C on average.",
                "A Venus day is longer than its year."
            ],
            icon: "sun.haze.fill",
            cardImageName: "img_08",
            tint: Color.yellow,
            arModelFileName: "venus.usdz",
            category: .planets
        ),
        LessonTopic(
            id: "jupiter",
            title: "Jupiter",
            imageLookupNames: ["Jupiter", "Jupitar"],
            subtitle: "The largest planet and a giant storm world.",
            summary: "Jupiter is a gas giant with strong magnetic fields, many moons, and the famous Great Red Spot storm.",
            facts: [
                "Jupiter has at least 90 known moons.",
                "Its Great Red Spot is a long-lived giant storm.",
                "It is more than 11 times wider than Earth."
            ],
            icon: "hurricane",
            cardImageName: "img_09",
            tint: Color.orange,
            arModelFileName: "jupiter.usdz",
            category: .planets
        ),
        LessonTopic(
            id: "saturn",
            title: "Saturn",
            imageLookupNames: ["Saturn"],
            subtitle: "The ringed giant with icy ring particles.",
            summary: "Saturn is a gas giant known for its bright ring system made of ice and rock fragments orbiting the planet.",
            facts: [
                "Saturn's rings are mostly water ice.",
                "A day on Saturn is about 10.7 Earth hours.",
                "Saturn has dozens of known moons, including Titan."
            ],
            icon: "circle.dashed",
            cardImageName: "img_10",
            tint: Color.brown,
            arModelFileName: "saturn.usdz",
            category: .planets
        ),
        LessonTopic(
            id: "uranus",
            title: "Uranus",
            imageLookupNames: ["Uranus"],
            subtitle: "An ice giant that spins on its side.",
            summary: "Uranus has a unique sideways tilt, faint rings, and a cold atmosphere rich in hydrogen, helium, and methane.",
            facts: [
                "Uranus rotates with an axial tilt of about 98 degrees.",
                "Methane gives Uranus its blue-green color.",
                "It takes 84 Earth years to orbit the Sun."
            ],
            icon: "wind",
            cardImageName: "img_01",
            tint: Color.cyan,
            arModelFileName: "uranus.usdz",
            category: .planets
        ),
        LessonTopic(
            id: "neptune",
            title: "Neptune",
            imageLookupNames: ["Neptune"],
            subtitle: "Distant ice giant with powerful winds.",
            summary: "Neptune is the farthest known major planet and features dynamic weather with some of the fastest winds in the solar system.",
            facts: [
                "Neptune's winds can exceed 2,000 km/h.",
                "It has a large moon called Triton.",
                "Neptune takes 165 Earth years to orbit the Sun."
            ],
            icon: "aqi.medium",
            cardImageName: "img_02",
            tint: Color.blue,
            arModelFileName: "neptune.usdz",
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
            id: "hubble",
            title: "Hubble Telescope",
            imageLookupNames: ["Hubble", "Hubble Telescope", "Hubble Space Telescope"],
            subtitle: "Legendary space observatory above Earth's atmosphere.",
            summary: "The Hubble Space Telescope has captured deep-space images that reshaped astronomy and measured cosmic expansion.",
            facts: [
                "Hubble launched in 1990 aboard Space Shuttle Discovery.",
                "It orbits Earth about every 95 minutes.",
                "Its observations helped refine the age of the universe."
            ],
            icon: "telescope",
            cardImageName: "img_07",
            tint: Color.teal,
            arModelFileName: "hubble.usdz",
            category: .manMadeMissions
        ),
        LessonTopic(
            id: "curiosity",
            title: "Curiosity Rover",
            imageLookupNames: ["Curiosity", "Curiosity Rover"],
            subtitle: "Mars rover exploring Gale Crater.",
            summary: "Curiosity studies Martian geology and climate, searching for signs that ancient Mars could have supported microbial life.",
            facts: [
                "Curiosity landed on Mars in 2012.",
                "It is powered by a radioisotope generator.",
                "Its onboard lab analyzes rocks and atmospheric samples."
            ],
            icon: "car.side.fill",
            cardImageName: "img_08",
            tint: Color.orange,
            arModelFileName: "curiosity.usdz",
            category: .manMadeMissions
        ),
        LessonTopic(
            id: "explorer-1",
            title: "Explorer 1",
            imageLookupNames: ["Explorer 1", "Explorer-1"],
            subtitle: "America's first satellite and a space age milestone.",
            summary: "Explorer 1 was the first U.S. satellite and helped discover the Van Allen radiation belts around Earth.",
            facts: [
                "Explorer 1 launched in January 1958.",
                "It carried scientific instruments designed by James Van Allen's team.",
                "Its findings changed how we understand Earth's near-space environment."
            ],
            icon: "dot.radiowaves.left.and.right",
            cardImageName: "img_09",
            tint: Color.indigo,
            arModelFileName: "explorer1.usdz",
            category: .manMadeMissions
        ),
        LessonTopic(
            id: "itokawa",
            title: "Asteroid Itokawa",
            imageLookupNames: ["Itokawa", "Asteroid Itokawa"],
            subtitle: "Small near-Earth asteroid visited by Hayabusa.",
            summary: "Itokawa is an irregular rubble-pile asteroid that provided key insight into asteroid structure and sample-return missions.",
            facts: [
                "Itokawa is about 500 meters long.",
                "Japan's Hayabusa mission returned samples from Itokawa.",
                "Its shape looks like two rocky lobes joined together."
            ],
            icon: "aqi.low",
            cardImageName: "img_10",
            tint: Color.gray,
            arModelFileName: "itokawa.usdz",
            category: .celestialObjects
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
