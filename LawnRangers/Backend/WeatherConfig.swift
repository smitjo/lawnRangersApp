import Foundation

/// Location + settings for the NWS weather forecast on the Planning tab.
///
/// NWS is US-only and grid-based (~2.5 km resolution), so an approximate
/// town-center coordinate for your service area is plenty. Set these to where
/// the Lawn Rangers mow. (Later this could come from CoreLocation or move to
/// Apple WeatherKit — see todo.md.)
enum WeatherConfig {
    // TODO: set to the Lawn Rangers service area (lat, lon). 0,0 = not set yet,
    // which makes the forecast view show a short "set your location" note.
    static let latitude: Double = 0.0
    static let longitude: Double = 0.0

    static var isConfigured: Bool { latitude != 0 || longitude != 0 }

    /// Main mowing days, as Calendar weekday numbers (Sun = 1 … Sat = 7).
    /// Tuesday = 3, Thursday = 5.
    static let mowingWeekdays: Set<Int> = [3, 5]
}
