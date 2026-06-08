import Foundation

/// Settings for the NWS weather forecast on the Planning tab.
/// The location now comes from the device (see `LocationProvider`); NWS is
/// US-only and grid-based (~2.5 km), which the current coordinate satisfies.
enum WeatherConfig {
    /// Main mowing days, as Calendar weekday numbers (Sun = 1 … Sat = 7).
    /// Tuesday = 3, Thursday = 5.
    static let mowingWeekdays: Set<Int> = [3, 5]
}
