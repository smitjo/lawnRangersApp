import SwiftUI
import MapKit
import CoreLocation

/// One mappable stop on the route.
struct RouteStop: Identifiable {
    let id: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

/// Maps the planned jobs (in their planned order) and hands the ordered stops to
/// Apple Maps for turn-by-turn directions. Addresses are geocoded with CLGeocoder
/// (no location permission needed).
struct RouteMapView: View {
    let items: [PlannedItem]
    @Environment(\.dismiss) private var dismiss

    @State private var stops: [RouteStop] = []
    @State private var isLoading = true
    @State private var skipped = 0

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Route")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { openInMaps() } label: {
                            Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        }
                        .disabled(stops.isEmpty)
                    }
                }
                .task { await geocodeStops() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Mapping addresses…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if stops.isEmpty {
            ContentUnavailableView {
                Label("No mappable stops", systemImage: "mappin.slash")
            } description: {
                Text("Add a street address to your planned jobs (tap one to edit, or fill the Address column in the sheet's Plan tab) to build a route.")
            }
        } else {
            VStack(spacing: 0) {
                Map {
                    ForEach(stops) { stop in
                        Marker(stop.name, coordinate: stop.coordinate)
                            .tint(.green)
                    }
                }
                .frame(maxHeight: .infinity)

                List {
                    Section {
                        ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .frame(width: 26, height: 26)
                                    .background(Color.lawnGreen, in: Circle())
                                    .foregroundStyle(.white)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stop.name).font(.headline)
                                    Text(stop.address).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } footer: {
                        Text(skipped > 0
                             ? "\(stops.count) stop\(stops.count == 1 ? "" : "s") · \(skipped) skipped (no/var address)."
                             : "\(stops.count) stop\(stops.count == 1 ? "" : "s"), in planned order.")
                    }
                }
                .frame(height: 230)
            }
        }
    }

    private func geocodeStops() async {
        isLoading = true
        var result: [RouteStop] = []
        var miss = 0
        let geocoder = CLGeocoder()
        for item in items {
            let addr = (item.address ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !addr.isEmpty else { continue }
            if let placemarks = try? await geocoder.geocodeAddressString(addr),
               let coord = placemarks.first?.location?.coordinate {
                result.append(RouteStop(id: item.id, name: item.customer, address: addr, coordinate: coord))
            } else {
                miss += 1
            }
        }
        stops = result
        skipped = miss
        isLoading = false
    }

    private func openInMaps() {
        guard !stops.isEmpty else { return }
        let mapItems = stops.map { stop -> MKMapItem in
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: stop.coordinate))
            mapItem.name = stop.name
            return mapItem
        }
        MKMapItem.openMaps(
            with: mapItems,
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        )
    }
}
