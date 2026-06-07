import SwiftUI

struct HomeView: View {
    @State private var lawns: [SheetLawn] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showingLogLawn = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Lawn Rangers")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSettings = true } label: {
                            Image(systemName: "gearshape").accessibilityLabel("Settings")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { Task { await load() } } label: {
                            Image(systemName: "arrow.clockwise").accessibilityLabel("Refresh")
                        }
                        .disabled(isLoading)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingLogLawn = true } label: {
                            Image(systemName: "plus").accessibilityLabel("Log a lawn")
                        }
                    }
                }
                .sheet(isPresented: $showingLogLawn) { LogLawnView() }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .task { if lawns.isEmpty { await load() } }
                .refreshable { await load() }
                .onChange(of: showingLogLawn) { _, isShowing in
                    // A form was just dismissed — give the sheet a moment to record, then refresh.
                    if !isShowing {
                        Task {
                            try? await Task.sleep(for: .seconds(1.2))
                            await load()
                        }
                    }
                }
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        if isLoading && lawns.isEmpty {
            ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, lawns.isEmpty {
            ContentUnavailableView {
                Label("Couldn’t load", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") { Task { await load() } }
            }
        } else if lawns.isEmpty {
            ContentUnavailableView {
                Label("No lawns yet", systemImage: "tray")
            } description: {
                Text("Tap the + button in the top-right to log a lawn.")
            }
        } else {
            lawnList
        }
    }

    /// Lawns ordered newest→oldest by their raw timestamp, independent of the
    /// order the rows happen to be stored in the sheet — so any filter or sort
    /// applied on the Google Sheet never changes the app's ordering.
    private var sortedLawns: [SheetLawn] {
        lawns.sorted { ($0.ts ?? 0) > ($1.ts ?? 0) }
    }

    private var lawnList: some View {
        List {
            ForEach(Array(sortedLawns.enumerated()), id: \.offset) { _, log in
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.whereLocation?.isEmpty == false ? log.whereLocation! : "Lawn")
                        .font(.headline)
                    HStack {
                        Text(log.date ?? "")
                        Spacer()
                        Text(log.howMuch ?? "")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Label("Customer: \(log.customerPaid ?? "")", systemImage: "person")
                        Label("Team: \(log.teammemberPaid ?? "")", systemImage: "person.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await EntriesService.fetch()
            lawns = result.lawns
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    HomeView()
}
