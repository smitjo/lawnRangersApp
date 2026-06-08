import Foundation

/// Rain + temp for one half of a day (morning or afternoon).
struct DaySegment {
    /// Max chance of rain in the window. nil = no data (e.g. morning already past).
    let rainChance: Int?
    /// Representative high temp for the window, if available.
    let high: Int?
}

/// A day's mowing outlook, split into morning and afternoon.
struct MowingDay: Identifiable {
    let id: String
    let weekdayShort: String   // "Tue"
    let name: String           // "Tuesday"
    let dateLabel: String      // "Jun 10"
    let date: Date
    let isMowingDay: Bool      // Tuesday / Thursday
    let morning: DaySegment    // 6am–noon
    let afternoon: DaySegment  // noon–6pm
}

/// Fetches an hourly NWS forecast and rolls it up into per-day AM/PM segments.
/// NWS is free (no key), requires a User-Agent header, and covers the US only.
enum WeatherService {
    private static let userAgent = "LawnRangersApp/1.0 (lawn-rangers app; contact via app)"

    static func fetchForecast(latitude: Double, longitude: Double) async throws
        -> (location: String, days: [MowingDay]) {

        // 1) Resolve the point → its hourly forecast endpoint + a location name.
        guard let pointsURL = URL(string: "https://api.weather.gov/points/\(latitude),\(longitude)") else {
            throw URLError(.badURL)
        }
        let points: NWSPoints = try await get(pointsURL)
        guard let hourlyString = points.properties.forecastHourly,
              let hourlyURL = URL(string: hourlyString) else {
            throw NSError(domain: "Weather", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "No forecast for this location (NWS covers the US only)."])
        }
        let location = [points.properties.relativeLocation?.properties.city,
                        points.properties.relativeLocation?.properties.state]
            .compactMap { $0 }.joined(separator: ", ")

        // 2) Fetch hourly data and bucket each hour into AM (6–12) / PM (12–18).
        let hourly: NWSHourly = try await get(hourlyURL)
        let iso = ISO8601DateFormatter()
        let cal = Calendar.current

        struct Acc {
            var amHours = 0, amPOP = 0; var amT: [Int] = []
            var pmHours = 0, pmPOP = 0; var pmT: [Int] = []
        }
        var order: [Date] = []
        var acc: [Date: Acc] = [:]

        for h in hourly.properties.periods {
            guard let t = iso.date(from: h.startTime) else { continue }
            let hour = cal.component(.hour, from: t)
            let day = cal.startOfDay(for: t)
            let pop = h.probabilityOfPrecipitation?.value ?? 0
            if acc[day] == nil { acc[day] = Acc(); order.append(day) }
            if hour >= 6 && hour < 12 {
                acc[day]!.amHours += 1
                acc[day]!.amPOP = max(acc[day]!.amPOP, pop)
                acc[day]!.amT.append(h.temperature)
            } else if hour >= 12 && hour < 18 {
                acc[day]!.pmHours += 1
                acc[day]!.pmPOP = max(acc[day]!.pmPOP, pop)
                acc[day]!.pmT.append(h.temperature)
            }
        }

        let dayFmt = DateFormatter(); dayFmt.dateFormat = "EEEE"
        let days = order.prefix(7).map { day -> MowingDay in
            let a = acc[day]!
            let weekday = cal.component(.weekday, from: day)
            return MowingDay(
                id: iso.string(from: day),
                weekdayShort: shortWeekday(day),
                name: dayFmt.string(from: day),
                dateLabel: shortDate(day),
                date: day,
                isMowingDay: WeatherConfig.mowingWeekdays.contains(weekday),
                morning: DaySegment(rainChance: a.amHours > 0 ? a.amPOP : nil, high: a.amT.max()),
                afternoon: DaySegment(rainChance: a.pmHours > 0 ? a.pmPOP : nil, high: a.pmT.max())
            )
        }
        return (location, Array(days))
    }

    // MARK: - Helpers

    private static func get<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "Weather", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey:
                "Weather service error (\(http.statusCode))."])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func shortWeekday(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date)
    }

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date)
    }
}

// MARK: - NWS API response shapes

private struct NWSPoints: Decodable {
    let properties: Props
    struct Props: Decodable {
        let forecastHourly: String?
        let relativeLocation: RelativeLocation?
    }
    struct RelativeLocation: Decodable {
        let properties: LocProps
        struct LocProps: Decodable { let city: String?; let state: String? }
    }
}

private struct NWSHourly: Decodable {
    let properties: Props
    struct Props: Decodable { let periods: [Hour] }
    struct Hour: Decodable {
        let startTime: String
        let temperature: Int
        let probabilityOfPrecipitation: Precip?
        struct Precip: Decodable { let value: Int? }
    }
}
