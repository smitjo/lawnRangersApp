import Foundation

/// One day's forecast, distilled from the NWS daytime period for the app's UI.
struct DayForecast: Identifiable {
    let id: Int            // NWS period number
    let weekdayShort: String   // "Tue"
    let dateLabel: String      // "Jun 10"
    let name: String           // "Tuesday" / "Today"
    let date: Date
    let isMowingDay: Bool       // Tuesday or Thursday
    let high: Int
    let unit: String            // "F"
    let rainChance: Int?        // percent, may be nil
    let shortForecast: String   // e.g. "Chance Rain Showers"
    let detailedForecast: String
    let symbol: String          // SF Symbol name
}

/// Fetches a 7-day forecast from the free National Weather Service API.
/// NWS requires a User-Agent header and covers the US only.
enum WeatherService {
    private static let userAgent = "LawnRangersApp/1.0 (lawn-rangers app; contact via app)"

    static func fetchForecast(latitude: Double, longitude: Double) async throws
        -> (location: String, days: [DayForecast]) {

        // 1) Resolve the point → its forecast endpoint + a friendly location name.
        guard let pointsURL = URL(string: "https://api.weather.gov/points/\(latitude),\(longitude)") else {
            throw URLError(.badURL)
        }
        let points: NWSPoints = try await get(pointsURL)
        guard let forecastURLString = points.properties.forecast,
              let forecastURL = URL(string: forecastURLString) else {
            throw NSError(domain: "Weather", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "No forecast for this location (NWS covers the US only)."])
        }
        let location = [points.properties.relativeLocation?.properties.city,
                        points.properties.relativeLocation?.properties.state]
            .compactMap { $0 }.joined(separator: ", ")

        // 2) Fetch the forecast and keep the daytime periods (the daily highs).
        let forecast: NWSForecast = try await get(forecastURL)
        let iso = ISO8601DateFormatter()
        let cal = Calendar.current
        let days = forecast.properties.periods
            .filter { $0.isDaytime }
            .prefix(7)
            .map { p -> DayForecast in
                let date = iso.date(from: p.startTime) ?? Date()
                let weekday = cal.component(.weekday, from: date)
                return DayForecast(
                    id: p.number,
                    weekdayShort: shortWeekday(date),
                    dateLabel: shortDate(date),
                    name: p.name,
                    date: date,
                    isMowingDay: WeatherConfig.mowingWeekdays.contains(weekday),
                    high: p.temperature,
                    unit: p.temperatureUnit,
                    rainChance: p.probabilityOfPrecipitation?.value,
                    shortForecast: p.shortForecast,
                    detailedForecast: p.detailedForecast ?? "",
                    symbol: symbol(for: p.shortForecast)
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
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    /// Maps an NWS shortForecast phrase to an SF Symbol.
    static func symbol(for text: String) -> String {
        let t = text.lowercased()
        if t.contains("thunder") { return "cloud.bolt.rain.fill" }
        if t.contains("snow") || t.contains("flurr") { return "cloud.snow.fill" }
        if t.contains("sleet") || t.contains("ice") || t.contains("freezing") { return "cloud.sleet.fill" }
        if t.contains("rain") || t.contains("shower") || t.contains("drizzle") { return "cloud.rain.fill" }
        if t.contains("fog") || t.contains("haze") { return "cloud.fog.fill" }
        if t.contains("partly") || t.contains("mostly sunny") { return "cloud.sun.fill" }
        if t.contains("cloud") || t.contains("overcast") { return "cloud.fill" }
        if t.contains("sunny") || t.contains("clear") { return "sun.max.fill" }
        return "cloud.fill"
    }
}

// MARK: - NWS API response shapes

private struct NWSPoints: Decodable {
    let properties: Props
    struct Props: Decodable {
        let forecast: String?
        let relativeLocation: RelativeLocation?
    }
    struct RelativeLocation: Decodable {
        let properties: LocProps
        struct LocProps: Decodable {
            let city: String?
            let state: String?
        }
    }
}

private struct NWSForecast: Decodable {
    let properties: Props
    struct Props: Decodable { let periods: [Period] }
    struct Period: Decodable {
        let number: Int
        let name: String
        let startTime: String
        let isDaytime: Bool
        let temperature: Int
        let temperatureUnit: String
        let probabilityOfPrecipitation: Precip?
        let shortForecast: String
        let detailedForecast: String?
        struct Precip: Decodable { let value: Int? }
    }
}
