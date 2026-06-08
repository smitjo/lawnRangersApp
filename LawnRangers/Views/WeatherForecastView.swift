import SwiftUI
import UIKit

/// 7-day NWS forecast strip shown at the top of the Planning tab. Uses the
/// device's current location, focuses on rain (chance + condition) and the daily
/// high, and calls out the main mowing days (Tue/Thu) with a highlight, a
/// scissors badge, and a go/no-go summary.
struct WeatherForecastView: View {
    @StateObject private var locator = LocationProvider()
    @Environment(\.openURL) private var openURL

    @State private var days: [DayForecast] = []
    @State private var location: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var combinedError: String? { errorMessage ?? locator.errorMessage }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if locator.isDenied && days.isEmpty {
                deniedNote
            } else if days.isEmpty, let err = combinedError {
                errorRow(err)
            } else if days.isEmpty {
                ProgressView("Locating…")
                    .frame(maxWidth: .infinity).frame(height: 110)
            } else {
                mowingSummary
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(days) { dayCard($0) }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .task {
            locator.request()
            if locator.coordinate != nil && days.isEmpty { await load() }
        }
        .onChange(of: locator.coordinate?.latitude) { _, lat in
            if lat != nil { Task { await load() } }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Label("7-Day Forecast", systemImage: "cloud.sun.fill")
                .font(.headline)
            Spacer()
            if !location.isEmpty {
                Text(location).font(.caption).foregroundStyle(.secondary)
            }
            Button {
                locator.request()
                Task { await load() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(isLoading)
        }
        .padding(.horizontal)
    }

    /// Go/no-go line for the next mowing day (Tue/Thu).
    @ViewBuilder
    private var mowingSummary: some View {
        if let next = days.first(where: { $0.isMowingDay }) {
            let chance = next.rainChance ?? 0
            HStack(spacing: 6) {
                Image(systemName: chance >= 50 ? "exclamationmark.triangle.fill" : "scissors")
                    .foregroundStyle(chance >= 50 ? .orange : .lawnGreen)
                Text(mowingText(next)).font(.subheadline)
            }
            .padding(.horizontal)
        }
    }

    private func mowingText(_ d: DayForecast) -> String {
        let chance = d.rainChance ?? 0
        let temp = "\(d.high)°\(d.unit)"
        if chance >= 50 {
            return "\(d.name) (mowing day): \(chance)% rain, \(temp) — may need to reschedule."
        } else if chance >= 20 {
            return "\(d.name) (mowing day): \(chance)% rain, \(temp) — keep an eye on it."
        } else {
            return "\(d.name) (mowing day): \(temp), low rain chance — good to mow."
        }
    }

    private func dayCard(_ d: DayForecast) -> some View {
        VStack(spacing: 6) {
            Text(d.weekdayShort).font(.subheadline.bold())
            Image(systemName: d.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.title2)
                .frame(height: 26)
            Text("\(d.high)°").font(.headline)
            HStack(spacing: 2) {
                Image(systemName: "drop.fill").font(.system(size: 9))
                Text("\(d.rainChance ?? 0)%").font(.caption2)
            }
            .foregroundStyle((d.rainChance ?? 0) >= 50 ? Color.blue : .secondary)
        }
        .frame(width: 62)
        .padding(.vertical, 10)
        .background(d.isMowingDay ? Color.lawnGreen.opacity(0.18) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(d.isMowingDay ? Color.lawnGreen : .clear, lineWidth: 1.5)
        )
        .overlay(alignment: .topTrailing) {
            if d.isMowingDay {
                Image(systemName: "scissors")
                    .font(.system(size: 9))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Color.lawnGreen, in: Circle())
                    .offset(x: 5, y: -5)
            }
        }
    }

    private var deniedNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.slash").foregroundStyle(.secondary)
            Text("Location is off — enable it to see local weather.")
                .font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.footnote)
        }
        .padding(.horizontal)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.exclamationmark").foregroundStyle(.secondary)
            Text(message).font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
                locator.request()
                Task { await load() }
            }
            .font(.footnote)
        }
        .padding(.horizontal)
    }

    // MARK: - Load

    private func load() async {
        guard let c = locator.coordinate else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await WeatherService.fetchForecast(
                latitude: c.latitude,
                longitude: c.longitude
            )
            location = result.location
            days = result.days
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    WeatherForecastView()
}
