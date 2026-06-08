import SwiftUI
import UIKit

/// Simple mowing-weather strip at the top of the Planning tab. Each day is split
/// into morning (AM) and afternoon (PM), color-coded by chance of rain:
///   • Green  — under 5%   (good to mow)
///   • Yellow — 5%–14%     (caution)
///   • Red    — 15%+       (rain likely)
/// Tuesday & Thursday (the main mowing days) are highlighted. Uses the device's
/// current location; reloading is driven by the Planning tab's top reload button
/// via `refreshTick`, and the strip scrolls strictly left↔right.
struct WeatherForecastView: View {
    var refreshTick: Int = 0

    @StateObject private var locator = LocationProvider()
    @Environment(\.openURL) private var openURL

    @State private var days: [MowingDay] = []
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
                legend
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

    // MARK: - Header / summary / legend

    private var header: some View {
        HStack {
            Label("Mowing Weather", systemImage: "cloud.sun.fill")
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

    /// Go/no-go line for the next mowing day (Tue/Thu), recommending AM vs PM.
    @ViewBuilder
    private var mowingSummary: some View {
        if let next = days.first(where: { $0.isMowingDay }) {
            let amOK = isOK(next.morning.rainChance)
            let pmOK = isOK(next.afternoon.rainChance)
            HStack(spacing: 6) {
                Image(systemName: (amOK || pmOK) ? "scissors" : "exclamationmark.triangle.fill")
                    .foregroundStyle((amOK || pmOK) ? Color.lawnGreen : Color.orange)
                Text(mowingText(next, amOK: amOK, pmOK: pmOK)).font(.subheadline)
            }
            .padding(.horizontal)
        }
    }

    private func mowingText(_ d: MowingDay, amOK: Bool, pmOK: Bool) -> String {
        let am = d.morning.rainChance.map { "\($0)%" } ?? "—"
        let pm = d.afternoon.rainChance.map { "\($0)%" } ?? "—"
        switch (amOK, pmOK) {
        case (true, true):   return "\(d.name) (mowing day): clear enough — good to mow."
        case (true, false):  return "\(d.name) (mowing day): mow in the morning (PM \(pm) rain)."
        case (false, true):  return "\(d.name) (mowing day): better in the afternoon (AM \(am) rain)."
        case (false, false): return "\(d.name) (mowing day): rain likely (AM \(am), PM \(pm)) — may need to reschedule."
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendDot(mowColor(0), "Go")
            legendDot(mowColor(10), "Caution")
            legendDot(mowColor(20), "Rain")
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }

    // MARK: - Day card

    private func dayCard(_ d: MowingDay) -> some View {
        VStack(spacing: 5) {
            Text(d.weekdayShort)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(d.isMowingDay ? Color.lawnGreen : .primary)
            Text(d.dateLabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            segment("AM", d.morning)
            segment("PM", d.afternoon)
        }
        .frame(width: 78)
        .padding(8)
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

    private func segment(_ label: String, _ seg: DaySegment) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 9, weight: .bold))
            if let t = seg.high { Text("\(t)°").font(.system(size: 11, weight: .semibold)) }
            Text(seg.rainChance.map { "\($0)%" } ?? "—").font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(mowColor(seg.rainChance))
        .foregroundStyle(textColor(seg.rainChance))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Color rules

    /// Green < 5%, Yellow 5–14%, Red 15%+, gray when there's no data.
    private func mowColor(_ pop: Int?) -> Color {
        guard let p = pop else { return Color(.systemGray3) }
        switch p {
        case ..<5:  return Color(red: 0.20, green: 0.62, blue: 0.28)
        case ..<15: return Color(red: 0.95, green: 0.76, blue: 0.10)
        default:    return Color(red: 0.82, green: 0.24, blue: 0.18)
        }
    }

    private func textColor(_ pop: Int?) -> Color {
        guard let p = pop else { return .secondary }
        return (5..<15).contains(p) ? .black : .white   // black on yellow, white on green/red
    }

    /// "OK to mow" = green or yellow (under 15% rain).
    private func isOK(_ pop: Int?) -> Bool {
        guard let p = pop else { return false }
        return p < 15
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
