import SwiftUI
import CoreLocation
import Combine

struct TonightSkyView: View {
    @StateObject private var locationManager = TonightSkyLocationManager()
    private let now = Date()

    private var insight: TonightSkyInsight {
        TonightSkyInsightEngine.makeInsight(
            for: Date(),
            latitude: locationManager.location?.coordinate.latitude
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                quickStatsStrip
                locationCard
                moonPhaseCard
                constellationsCard
                bestViewingCard
            }
            .padding(16)
        }
        .navigationTitle("Tonight Sky")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            ZStack {
                Image("img_08")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.58), Color.black.opacity(0.36), Color.black.opacity(0.62)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            locationManager.start()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .center, spacing: 7) {
            Text("Tonight Sky")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(now.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            Text("Modern astronomy snapshot for your night sky.")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)

            Text(insight.summary)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 10)
    }

    private var quickStatsStrip: some View {
        HStack(spacing: 10) {
            statTile(
                title: "Moon",
                value: "\(insight.illuminationPercent)%",
                icon: "moon.fill"
            )

            statTile(
                title: "Best Hour",
                value: shortViewingWindow,
                icon: "clock"
            )

            statTile(
                title: "Sky",
                value: insight.hemisphereLabel == "Global Forecast" ? "Global" : "Local",
                icon: "location"
            )
        }
    }

    private func statTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .center, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .default))
            }
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .center)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(12)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Sky Location", systemImage: "location.fill")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                Spacer()
                Text(insight.hemisphereLabel)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
            }

            Text(locationManager.statusText)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.92))

            if locationManager.shouldShowRequestButton {
                Button {
                    locationManager.requestPermission()
                } label: {
                    Text("Enable Location for Better Accuracy")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var moonPhaseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Moon Phase", systemImage: "moon.stars.fill")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(.white)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(insight.moonEmoji)
                    .font(.system(size: 32))
                Text(insight.moonPhaseName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Illumination")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Text("\(insight.illuminationPercent)%")
                        .font(.system(size: 13, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                }

                ProgressView(value: Double(insight.illuminationPercent), total: 100)
                    .tint(.white)
            }

            Text(insight.moonAdvice)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(16)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var constellationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Top 3 Constellations Tonight", systemImage: "sparkles")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                ForEach(insight.topConstellations, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.14))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.26), lineWidth: 1)
                        )
                }
            }

            Text("Best seen away from city lights with clear skies.")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var bestViewingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Best Viewing Window", systemImage: "clock.fill")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(.white)

            Text(insight.bestViewingHour)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                Text("Visibility")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(insight.visibilityScore)/100")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
            }

            Text(insight.summary)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var shortViewingWindow: String {
        if insight.bestViewingHour.contains("9:00") { return "9-11 PM" }
        if insight.bestViewingHour.contains("10:00") { return "10-12" }
        return "12-2 AM"
    }
}

private struct TonightSkyInsight {
    let moonPhaseName: String
    let moonEmoji: String
    let illuminationPercent: Int
    let topConstellations: [String]
    let bestViewingHour: String
    let visibilityScore: Int
    let moonAdvice: String
    let summary: String
    let hemisphereLabel: String
}

private enum TonightSkyInsightEngine {
    static func makeInsight(for date: Date, latitude: Double?) -> TonightSkyInsight {
        let phase = moonPhaseFraction(for: date)
        let illumination = Int(round((1 - cos(2 * Double.pi * phase)) * 50))
        let phaseName = moonPhaseName(for: phase)
        let moonAdvice = moonAdvice(for: illumination)

        let hemisphere = hemisphereLabel(for: latitude)
        let constellations = topConstellations(for: date, latitude: latitude)
        let viewingHour = bestViewingHour(for: illumination)
        let score = max(40, min(95, 100 - Int(Double(illumination) * 0.45)))

        return TonightSkyInsight(
            moonPhaseName: phaseName,
            moonEmoji: moonEmoji(for: phase),
            illuminationPercent: illumination,
            topConstellations: constellations,
            bestViewingHour: viewingHour,
            visibilityScore: score,
            moonAdvice: moonAdvice,
            summary: "Low horizon haze and darker skies will improve constellation contrast tonight.",
            hemisphereLabel: hemisphere
        )
    }

    private static func moonPhaseFraction(for date: Date) -> Double {
        let reference = Date(timeIntervalSince1970: 947182440) // 2000-01-06 18:14 UTC new moon
        let synodicMonth = 29.53058867
        let days = date.timeIntervalSince(reference) / 86400
        var fraction = days / synodicMonth
        fraction.formTruncatingRemainder(dividingBy: 1)
        if fraction < 0 { fraction += 1 }
        return fraction
    }

    private static func moonPhaseName(for fraction: Double) -> String {
        switch fraction {
        case 0.00..<0.03, 0.97...1.0:
            return "New Moon"
        case 0.03..<0.22:
            return "Waxing Crescent"
        case 0.22..<0.28:
            return "First Quarter"
        case 0.28..<0.47:
            return "Waxing Gibbous"
        case 0.47..<0.53:
            return "Full Moon"
        case 0.53..<0.72:
            return "Waning Gibbous"
        case 0.72..<0.78:
            return "Last Quarter"
        default:
            return "Waning Crescent"
        }
    }

    private static func moonEmoji(for fraction: Double) -> String {
        switch fraction {
        case 0.00..<0.03, 0.97...1.0:
            return "🌑"
        case 0.03..<0.22:
            return "🌒"
        case 0.22..<0.28:
            return "🌓"
        case 0.28..<0.47:
            return "🌔"
        case 0.47..<0.53:
            return "🌕"
        case 0.53..<0.72:
            return "🌖"
        case 0.72..<0.78:
            return "🌗"
        default:
            return "🌘"
        }
    }

    private static func moonAdvice(for illumination: Int) -> String {
        if illumination < 25 {
            return "Great dark-sky conditions for faint constellations and nebulae."
        }
        if illumination < 60 {
            return "Balanced moonlight. Bright stars and major patterns should be easy to spot."
        }
        return "Brighter moonlight tonight. Focus on high-contrast constellations and planets."
    }

    private static func bestViewingHour(for illumination: Int) -> String {
        if illumination < 30 {
            return "9:00 PM - 11:00 PM"
        }
        if illumination < 70 {
            return "10:00 PM - 12:00 AM"
        }
        return "12:00 AM - 2:00 AM"
    }

    private static func hemisphereLabel(for latitude: Double?) -> String {
        guard let latitude else {
            return "Global Forecast"
        }
        return latitude >= 0 ? "Northern Hemisphere" : "Southern Hemisphere"
    }

    private static func topConstellations(for date: Date, latitude: Double?) -> [String] {
        let month = Calendar.current.component(.month, from: date)
        let isNorthernHemisphere = (latitude ?? 23.8) >= 0

        if isNorthernHemisphere {
            switch month {
            case 12, 1, 2:
                return ["Orion", "Taurus", "Gemini"]
            case 3, 4, 5:
                return ["Leo", "Bootes", "Virgo"]
            case 6, 7, 8:
                return ["Scorpius", "Cygnus", "Lyra"]
            default:
                return ["Pegasus", "Andromeda", "Cassiopeia"]
            }
        } else {
            switch month {
            case 12, 1, 2:
                return ["Crux", "Carina", "Centaurus"]
            case 3, 4, 5:
                return ["Pavo", "Tucana", "Grus"]
            case 6, 7, 8:
                return ["Orion", "Canis Major", "Puppis"]
            default:
                return ["Scorpius", "Sagittarius", "Ara"]
            }
        }
    }
}

private final class TonightSkyLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
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
            return "Determining your location for a better sky forecast..."
        case .notDetermined:
            return "Enable location to personalize constellations for your hemisphere."
        case .denied, .restricted:
            return "Location is off. Showing a global sky forecast instead."
        @unknown default:
            return "Location status unavailable. Showing a global sky forecast."
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
        print("Location error: \(error.localizedDescription)")
    }
}

#Preview {
    NavigationStack {
        TonightSkyView()
    }
}
