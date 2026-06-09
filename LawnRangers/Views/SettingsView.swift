import SwiftUI

/// Settings — paste your Google Sheets Web App URL here to connect the backend.
/// Until a URL is entered, entries are saved locally only.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString: String = BackendConfig.webAppURLString
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://script.google.com/macros/s/…/exec", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.callout)
                } header: {
                    Text("Google Sheets Web App URL")
                } footer: {
                    Text("The app ships with a built-in backend URL, so this is optional. Enter a URL here only to override the default on this device; leave blank to use the built-in one.")
                }

                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        if BackendConfig.isConfigured {
                            Label(
                                BackendConfig.isUsingDefault ? "Connected (built-in)" : "Connected (custom)",
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(.green)
                        } else {
                            Label("Local only", systemImage: "iphone")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            Text("Test connection")
                            Spacer()
                            if isTesting { ProgressView() }
                        }
                    }
                    .disabled(isTesting)
                    if let testResult {
                        Text(testResult)
                            .font(.footnote)
                            .foregroundStyle(testResult.hasPrefix("Connected") ? .green : .red)
                    }
                } header: {
                    Text("Connection test")
                } footer: {
                    Text("Checks whether the URL above (or the built-in one if blank) actually responds. Does not save it.")
                }

                Section {
                    Toggle("Log errors to sheet", isOn: Binding(
                        get: { DebugConfig.errorLoggingEnabled },
                        set: { DebugConfig.errorLoggingEnabled = $0 }
                    ))
                } header: {
                    Text("Debug")
                } footer: {
                    Text("When on, app errors are written to an \"Errors\" tab in the Google Sheet to help diagnose problems in the field.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        BackendConfig.overrideURLString = urlString
                        dismiss()
                    }
                }
            }
        }
    }

    /// Tests the typed URL (or the built-in default if blank) without saving it.
    private func testConnection() async {
        isTesting = true
        testResult = nil
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let effective = trimmed.isEmpty ? BackendConfig.defaultWebAppURLString : trimmed
        guard var comps = URLComponents(string: effective) else {
            testResult = "That doesn't look like a valid URL."
            isTesting = false
            return
        }
        comps.queryItems = [URLQueryItem(name: "action", value: "entries")]
        guard let url = comps.url else {
            testResult = "That doesn't look like a valid URL."
            isTesting = false
            return
        }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                testResult = "Server responded with an error (\(http.statusCode))."
            } else {
                testResult = "Connected — the backend responded."
            }
        } catch {
            testResult = "Failed: \(error.localizedDescription)"
        }
        isTesting = false
    }
}

#Preview {
    SettingsView()
}
