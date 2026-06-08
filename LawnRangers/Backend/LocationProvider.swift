import CoreLocation

/// Thin wrapper around CLLocationManager that asks for "when in use" permission
/// and publishes the device's current coordinate. Used by the Planning tab's
/// weather forecast so it follows wherever you are.
@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer   // town-level is plenty for NWS
        authorization = manager.authorizationStatus
    }

    /// Ask for permission (first run) or fetch a fresh fix if already allowed.
    func request() {
        let status = manager.authorizationStatus
        authorization = status
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location is off — enable it in Settings to see local weather."
        @unknown default:
            break
        }
    }

    var isDenied: Bool { authorization == .denied || authorization == .restricted }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorization = self.manager.authorizationStatus
            if self.authorization == .authorizedWhenInUse || self.authorization == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let c = loc.coordinate
        Task { @MainActor in
            self.coordinate = c
            self.errorMessage = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.errorMessage = message }
    }
}
