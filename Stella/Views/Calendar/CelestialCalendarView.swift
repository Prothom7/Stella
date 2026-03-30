import SwiftUI
import FirebaseFirestore

struct CelestialCalendarView: View {
    private let year = Calendar.current.component(.year, from: Date())
    @State private var sections: [CelestialEventSection] = CelestialEventSection.sampleYearlyEvents
    @State private var selectedMonthIndex = Calendar.current.component(.month, from: Date())
    @State private var isLoading = true
    @State private var didTryRemoteLoad = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                introCard

                if isLoading {
                    ProgressView("Loading yearly events...")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.45))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                }

                Text("Swipe left or right to move month-by-month")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.72))

                TabView(selection: $selectedMonthIndex) {
                    ForEach(monthSections) { section in
                        MonthCalendarPage(section: section, year: year)
                            .tag(section.monthIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 610)
            }
            .padding(16)
        }
        .onAppear {
            guard !didTryRemoteLoad else { return }
            didTryRemoteLoad = true
            loadEventsFromFirestore()
        }
        .navigationTitle("Celestial Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            ZStack {
                Image("img_01")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.5), Color.black.opacity(0.3), Color.black.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }

    private var monthSections: [CelestialEventSection] {
        let sectionsByMonth = Dictionary(uniqueKeysWithValues: sections.map { ($0.monthIndex, $0) })

        return (1...12).map { monthIndex in
            sectionsByMonth[monthIndex] ?? CelestialEventSection(
                month: CelestialEvent.monthName(from: monthIndex),
                icon: CelestialEvent.defaultIcon(for: monthIndex),
                events: []
            )
        }
    }

    private var introCard: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("\(year) Sky Highlights")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Track meteor showers, eclipses, and major conjunctions throughout the year.")
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 14, x: 0, y: 10)
    }

    private func loadEventsFromFirestore() {
        isLoading = true

        let db = Firestore.firestore()
        db.collection("celestial_events")
            .whereField("year", isEqualTo: year)
            .getDocuments { snapshot, error in
                if let error {
                    sections = CelestialEventSection.sampleYearlyEvents
                    isLoading = false
                    print("Firestore celestial_events fetch failed: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    sections = CelestialEventSection.sampleYearlyEvents
                    isLoading = false
                    return
                }

                let events = documents.compactMap { document in
                    CelestialEvent.from(documentID: document.documentID, data: document.data())
                }

                if events.isEmpty {
                    sections = CelestialEventSection.sampleYearlyEvents
                    isLoading = false
                    return
                }

                sections = CelestialEventSection.sections(from: events)
                isLoading = false
            }
    }

    private func eventRow(_ event: CelestialEvent) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(event.date)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.14), in: Capsule())

                Text(event.title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
            }

            Text(event.detail)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.84))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MonthCalendarPage: View {
    let section: CelestialEventSection
    let year: Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private var eventsByDay: [Int: [CelestialEvent]] {
        Dictionary(grouping: section.events) { $0.daySort }
    }

    private var monthDays: [CalendarDayCell] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = section.monthIndex
        components.day = 1

        guard let firstDate = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDate) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDate)
        let leadingBlankCells = max(0, firstWeekday - 1)

        var cells: [CalendarDayCell] = []
        cells.append(contentsOf: Array(repeating: CalendarDayCell(day: nil), count: leadingBlankCells))

        for day in dayRange {
            let dayEvents = eventsByDay[day] ?? []
            cells.append(CalendarDayCell(day: day, events: dayEvents))
        }

        while cells.count % 7 != 0 {
            cells.append(CalendarDayCell(day: nil))
        }

        return cells
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .foregroundStyle(.white)
                Text(section.month)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(year)")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.15), in: Capsule())
            }

            VStack(spacing: 8) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(monthDays) { cell in
                        dayCellView(cell)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )

            if !section.events.isEmpty {
                VStack(spacing: 10) {
                    ForEach(section.events) { event in
                        NavigationLink {
                            CelestialEventDetailView(event: event, year: year)
                        } label: {
                            eventRow(event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)
    }

    private func dayCellView(_ cell: CalendarDayCell) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cell.hasEvents ? Color.white.opacity(0.2) : Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(cell.hasEvents ? 0.24 : 0.1), lineWidth: 0.8)
                )

            if let day = cell.day {
                VStack(spacing: 3) {
                    Text("\(day)")
                        .font(.system(size: 13, weight: cell.hasEvents ? .semibold : .regular, design: .default))
                        .foregroundStyle(.white)

                    if cell.hasEvents {
                        Circle()
                            .fill(.white)
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .frame(height: 36)
    }

    private func eventRow(_ event: CelestialEvent) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(event.date)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.14), in: Capsule())

                Text(event.title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
            }

            Text(event.detail)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.84))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct CelestialEventDetailView: View {
    let event: CelestialEvent
    let year: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Image(systemName: event.icon)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(event.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("\(event.date), \(year)")
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.42))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("About This Event")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(event.detail)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.9))

                    Divider().overlay(.white.opacity(0.2))

                    Text("Viewing Tips")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    tipRow(icon: "moon.stars", text: "Use a dark-sky location away from city lights.")
                    tipRow(icon: "clock", text: "Check local weather and view during the event peak window.")
                    tipRow(icon: "camera", text: "Use night mode or a tripod for clearer observations and photos.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
            }
            .padding(16)
        }
        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            ZStack {
                Image("img_01")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.5), Color.black.opacity(0.3), Color.black.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(.white.opacity(0.88))
        }
    }
}

private struct CalendarDayCell: Identifiable {
    let id = UUID()
    let day: Int?
    let events: [CelestialEvent]

    init(day: Int?, events: [CelestialEvent] = []) {
        self.day = day
        self.events = events
    }

    var hasEvents: Bool {
        !events.isEmpty
    }
}

private struct CelestialEventSection {
    let month: String
    let icon: String
    let events: [CelestialEvent]

    var monthIndex: Int {
        events.first?.monthIndex ?? CelestialEvent.monthIndex(from: month) ?? 1
    }

    static func sections(from events: [CelestialEvent]) -> [CelestialEventSection] {
        let grouped = Dictionary(grouping: events) { $0.monthIndex }

        return grouped
            .keys
            .sorted()
            .compactMap { monthIndex in
                guard let monthEvents = grouped[monthIndex], !monthEvents.isEmpty else {
                    return nil
                }

                let sortedEvents = monthEvents.sorted {
                    if $0.daySort == $1.daySort {
                        return $0.title < $1.title
                    }
                    return $0.daySort < $1.daySort
                }

                let monthTitle = CelestialEvent.monthName(from: monthIndex)
                let icon = sortedEvents.first?.icon ?? CelestialEvent.defaultIcon(for: monthIndex)

                return CelestialEventSection(month: monthTitle, icon: icon, events: sortedEvents)
            }
    }

    static let sampleYearlyEvents: [CelestialEventSection] = [
        CelestialEventSection(
            month: "January",
            icon: "sparkles",
            events: [
                CelestialEvent(id: "sample-jan-1", monthIndex: 1, daySort: 3, date: "Jan 3-4", title: "Quadrantids Meteor Shower", detail: "Fast meteors with a short but intense peak before dawn.", month: "January", icon: "sparkles"),
                CelestialEvent(id: "sample-jan-2", monthIndex: 1, daySort: 10, date: "Jan 10", title: "Moon and Jupiter Pairing", detail: "A bright close approach in the evening sky.", month: "January", icon: "sparkles")
            ]
        ),
        CelestialEventSection(
            month: "March",
            icon: "moonphase.waning.crescent",
            events: [
                CelestialEvent(id: "sample-mar-1", monthIndex: 3, daySort: 14, date: "Mar 14", title: "Total Lunar Eclipse", detail: "Earth's shadow gives the Moon a copper-red color.", month: "March", icon: "moonphase.waning.crescent"),
                CelestialEvent(id: "sample-mar-2", monthIndex: 3, daySort: 20, date: "Mar 20", title: "March Equinox", detail: "Start of spring in the northern hemisphere.", month: "March", icon: "moonphase.waning.crescent")
            ]
        ),
        CelestialEventSection(
            month: "April",
            icon: "sparkle.magnifyingglass",
            events: [
                CelestialEvent(id: "sample-apr-1", monthIndex: 4, daySort: 21, date: "Apr 21-22", title: "Lyrids Meteor Shower", detail: "Moderate shower known for occasional bright fireballs.", month: "April", icon: "sparkle.magnifyingglass")
            ]
        ),
        CelestialEventSection(
            month: "May",
            icon: "moon.stars",
            events: [
                CelestialEvent(id: "sample-may-1", monthIndex: 5, daySort: 5, date: "May 5-6", title: "Eta Aquariids", detail: "Meteor shower from Halley's Comet debris, best before sunrise.", month: "May", icon: "moon.stars")
            ]
        ),
        CelestialEventSection(
            month: "August",
            icon: "sparkles.tv",
            events: [
                CelestialEvent(id: "sample-aug-1", monthIndex: 8, daySort: 12, date: "Aug 12-13", title: "Perseids Meteor Shower", detail: "One of the year's best meteor showers under dark skies.", month: "August", icon: "sparkles.tv")
            ]
        ),
        CelestialEventSection(
            month: "September",
            icon: "sun.max",
            events: [
                CelestialEvent(id: "sample-sep-1", monthIndex: 9, daySort: 22, date: "Sep 22", title: "September Equinox", detail: "Day and night are nearly equal in length worldwide.", month: "September", icon: "sun.max")
            ]
        ),
        CelestialEventSection(
            month: "October",
            icon: "sparkles.rectangle.stack",
            events: [
                CelestialEvent(id: "sample-oct-1", monthIndex: 10, daySort: 21, date: "Oct 21-22", title: "Orionids Meteor Shower", detail: "Swift meteors radiating from Orion before dawn.", month: "October", icon: "sparkles.rectangle.stack")
            ]
        ),
        CelestialEventSection(
            month: "November",
            icon: "telescope",
            events: [
                CelestialEvent(id: "sample-nov-1", monthIndex: 11, daySort: 17, date: "Nov 17-18", title: "Leonids Meteor Shower", detail: "Usually modest, but occasionally produces storms.", month: "November", icon: "telescope")
            ]
        ),
        CelestialEventSection(
            month: "December",
            icon: "snowflake",
            events: [
                CelestialEvent(id: "sample-dec-1", monthIndex: 12, daySort: 13, date: "Dec 13-14", title: "Geminids Meteor Shower", detail: "Reliable and bright meteors, often the best annual display.", month: "December", icon: "snowflake"),
                CelestialEvent(id: "sample-dec-2", monthIndex: 12, daySort: 21, date: "Dec 21", title: "December Solstice", detail: "Longest night in the northern hemisphere.", month: "December", icon: "snowflake")
            ]
        )
    ]
}

extension CelestialEventSection: Identifiable {
    var id: Int { monthIndex }
}

private struct CelestialEvent: Identifiable {
    let id: String
    let monthIndex: Int
    let daySort: Int
    let date: String
    let title: String
    let detail: String
    let month: String
    let icon: String

    static func from(documentID: String, data: [String: Any]) -> CelestialEvent? {
        let title = (data["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if title.isEmpty { return nil }

        let detail =
            (data["detail"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ??
            (data["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ??
            "No details available."

        let monthIndex = parseInt(data["monthIndex"]) ?? 1
        let monthName =
            ((data["month"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? monthName(from: monthIndex)

        let daySort = parseInt(data["day"]) ?? parseFirstDay(from: data["dateLabel"] as? String) ?? 1
        let dateLabel =
            (data["dateLabel"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ??
            "\(monthName.prefix(3)) \(daySort)"

        let icon =
            (data["icon"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? defaultIcon(for: monthIndex)

        return CelestialEvent(
            id: documentID,
            monthIndex: monthIndex,
            daySort: daySort,
            date: dateLabel,
            title: title,
            detail: detail,
            month: monthName,
            icon: icon
        )
    }

    static func monthName(from monthIndex: Int) -> String {
        switch monthIndex {
        case 1: return "January"
        case 2: return "February"
        case 3: return "March"
        case 4: return "April"
        case 5: return "May"
        case 6: return "June"
        case 7: return "July"
        case 8: return "August"
        case 9: return "September"
        case 10: return "October"
        case 11: return "November"
        case 12: return "December"
        default: return "Unknown"
        }
    }

    static func monthIndex(from monthName: String) -> Int? {
        switch monthName.lowercased() {
        case "january": return 1
        case "february": return 2
        case "march": return 3
        case "april": return 4
        case "may": return 5
        case "june": return 6
        case "july": return 7
        case "august": return 8
        case "september": return 9
        case "october": return 10
        case "november": return 11
        case "december": return 12
        default: return nil
        }
    }

    static func defaultIcon(for monthIndex: Int) -> String {
        switch monthIndex {
        case 1, 2: return "sparkles"
        case 3, 4: return "moonphase.waning.crescent"
        case 5, 6: return "sun.max"
        case 7, 8: return "sparkles.tv"
        case 9, 10: return "sparkles.rectangle.stack"
        case 11, 12: return "snowflake"
        default: return "sparkles"
        }
    }

    private static func parseInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }

        if let int64Value = value as? Int64 {
            return Int(int64Value)
        }

        if let doubleValue = value as? Double {
            return Int(doubleValue)
        }

        if let stringValue = value as? String {
            return Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }

    private static func parseFirstDay(from dateLabel: String?) -> Int? {
        guard let dateLabel else { return nil }

        let numbers = dateLabel
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }

        return numbers.first
    }
}

#Preview {
    NavigationStack {
        CelestialCalendarView()
    }
}
