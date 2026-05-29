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
}

#Preview {
    SettingsView()
}
