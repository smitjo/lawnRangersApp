import SwiftUI
import UIKit

/// 7-day NWS forecast strip shown at the top of the Planning tab. Uses the
/// device's current location, focuses on rain (chance + condition) and the daily
/// high, and calls out the main mowing days (Tue/Thu).
///
/// Reloading is driven entirely by the Planning tab's top reload button via
/// `refreshTick` — the strip itself has no pull-to-refresh and scrolls strictly
/// left↔right.
struct WeatherForecastView: View {
    /// Bumped by the Planning tab's reload button to trigger a refresh.
    var refreshTick: Int = 0

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
                    .frame(maxWidth: .infinity).frame(height: 120)
            } else {
                mowingSummary
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(days) { dayCard($0) }
                    }
                    .padding(.horizontal)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)   // left/right only
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
        .onChange(of: refreshTick) { _, _ in
            locator.request()
            Task { await load() }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Label("7-Day Forecast", systemImage: "cloud.sun.fill")
                .font(.headline)
            Spacer()
            if isLoading {
                ProgressView().controlSize(.small)
            } else if !location.isEmpty {
                Text(location).font(.caption).foregroundStyle(.secondary)
            }
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

    // MARK: - Day card

    private func dayCard(_ d: DayForecast) -> some View {
        let chance = d.rainChance ?? 0
        return VStack(spacing: 5) {
            Text(d.weekdayShort)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(d.isMowingDay ? Color.lawnGreen : .primary)
            Text(d.dateLabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Image(systemName: d.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.title)
                .frame(height: 30)
            Text("\(d.high)°\(d.unit)")
                .font(.title3.weight(.semibold))
            rainPill(chance)
        }
        .frame(width: 68, height: 134)
        .background(d.isMowingDay ? Color.lawnGreen.opacity(0.15) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(d.isMowingDay ? Color.lawnGreen : .clear, lineWidth: 1.5)
        )
        .overlay(alignment: .top) {
            if d.isMowingDay {
                Text("MOW")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.lawnGreen, in: Capsule())
                    .offset(y: -7)
            }
        }
    }

    private func rainPill(_ chance: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "drop.fill").font(.system(size: 9))
            Text("\(chance)%").font(.caption2.weight(.medium))
        }
        .foregroundStyle(chance >= 50 ? .white : (chance >= 20 ? Color.blue : .secondary))
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(chance >= 50 ? Color.blue : .clear, in: Capsule())
    }

    // MARK: - States

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
