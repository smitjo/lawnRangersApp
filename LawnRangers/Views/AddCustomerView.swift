import SwiftUI

/// "Add a Customer" — creates a row in the sheet's Customers tab (name, standard
/// rate, address, mow interval). Same card layout as Log a Lawn; the backend
/// rejects duplicate names so the roster stays clean.
struct AddCustomerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var rate: String = ""
    @State private var address: String = ""
    @State private var phone: String = ""
    @State private var notes: String = ""
    @State private var mowEvery: String = ""

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Days between mows: a typed value, or 14 if left blank.
    private var resolvedMowEvery: Int {
        Int(mowEvery.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 14
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    // Name
                    fieldCard(icon: "person.crop.circle.badge.plus", title: "Customer name", required: true) {
                        inputField {
                            TextField("e.g. Johnson", text: $name)
                                .textInputAutocapitalization(.words)
                        }
                    }

                    // Standard rate
                    fieldCard(icon: "dollarsign.circle.fill", title: "Standard rate", required: false) {
                        inputField {
                            TextField("e.g. 45", text: $rate)
                                .keyboardType(.decimalPad)
                        }
                        Text("What “Standard” resolves to when logging a lawn. Can be filled in later.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Address
                    fieldCard(icon: "mappin.and.ellipse", title: "Address", required: false) {
                        inputField {
                            TextField("Street address", text: $address, axis: .vertical)
                                .textInputAutocapitalization(.words)
                                .lineLimit(2...4)
                        }
                        Text("Used by the Route map to plot this customer's stop.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Phone
                    fieldCard(icon: "phone.fill", title: "Phone", required: false) {
                        inputField {
                            TextField("Phone number", text: $phone)
                                .keyboardType(.phonePad)
                        }
                    }

                    // Notes
                    fieldCard(icon: "note.text", title: "Notes", required: false) {
                        inputField {
                            TextField("Gate code, dog, billing quirks…", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                        }
                    }

                    // Mow interval
                    fieldCard(icon: "calendar", title: "Mow every (days)", required: false) {
                        inputField {
                            TextField("14", text: $mowEvery)
                                .keyboardType(.numberPad)
                        }
                        Text("Days between mows — drives the Planning tab's due dates. Blank = 14.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .background(backdrop)
            .navigationTitle("Add a Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") { save() }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
        }
    }

    // MARK: - Styled building blocks (match LogLawnView)

    private var backdrop: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color.lawnGreen.opacity(0.10)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func fieldCard<Content: View>(
        icon: String,
        title: String,
        required: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.lawnGreen)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if required {
                    Text("Required")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func inputField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(fieldFill)
    }

    private var fieldFill: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.06))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.subheadline)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.85))
        )
    }

    // MARK: - Save

    private func save() {
        var payload: [String: Any] = [
            "type": "customerAdd",
            "customer": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "address": address.trimmingCharacters(in: .whitespacesAndNewlines),
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
            "notes": notes.trimmingCharacters(in: .whitespacesAndNewlines),
            "mowEvery": resolvedMowEvery,
        ]
        // Send the rate as a number so the sheet stores it numerically.
        let trimmedRate = rate.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = Double(trimmedRate) { payload["rate"] = r }

        // Only dismiss once the save is confirmed; on failure (e.g. a duplicate
        // name) keep the form open with the backend's error.
        Task {
            isSubmitting = true
            errorMessage = nil
            let result = await SheetSubmitter.submit(payload)
            isSubmitting = false
            switch result {
            case .success:
                dismiss()
            case .notConfigured:
                errorMessage = "No backend connected — add the Web App URL in Settings."
            case .failure(let error):
                let detail = (error as NSError).localizedDescription
                errorMessage = detail.contains("already exists")
                    ? detail
                    : "Couldn't save — check your connection and try again."
            }
        }
    }
}

#Preview {
    AddCustomerView()
}
