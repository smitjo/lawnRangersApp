import SwiftUI

/// Voice-driven planning, powered by ElevenLabs.
///
/// Tap the mic and say a customer's name (e.g. "plan Johnson", or "schedule
/// everyone") — the app transcribes it with ElevenLabs Scribe, auto-picks the
/// next Tuesday/Thursday they're due (Tue/Thu only), adds it to the shared plan,
/// and reads the confirmation back in an ElevenLabs voice.
///
/// The lower section auto-schedules every due lawn at once, computing the day
/// either on-device (`MowingSchedule`) or from the sheet backend
/// (`?action=autoschedule`) — both apply the same Tue/Thu rule.
struct VoicePlanView: View {
    let customers: [PlanningCustomer]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VoicePlanModel()

    var body: some View {
        NavigationStack {
            Form {
                voiceSection
                if !model.scheduled.isEmpty { resultsSection }
                autoScheduleSection
            }
            .navigationTitle("Voice Planning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { model.customers = customers }
            .alert("Voice error", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    // MARK: - Speak to plan

    private var voiceSection: some View {
        Section {
            Button {
                Task { await model.toggleRecording() }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: model.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(model.isRecording ? .red : Color.lawnGreen)
                        .symbolEffect(.pulse, isActive: model.isRecording)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.isRecording ? "Listening… tap to stop" : "Tap to speak")
                            .font(.headline)
                        Text("e.g. “plan Johnson” or “schedule everyone”")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.isWorking { ProgressView() }
                }
            }
            .buttonStyle(.plain)
            .disabled(!ElevenLabsService.isConfigured || model.isWorking)

            if !ElevenLabsService.isConfigured {
                Label("Connect the Google Sheets backend in Settings to use voice.",
                      systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !model.transcript.isEmpty {
                Text("“\(model.transcript)”").font(.callout).italic()
            }
            if !model.status.isEmpty {
                Text(model.status).font(.subheadline).foregroundStyle(Color.lawnGreen)
            }
        } header: {
            Text("Speak to plan")
        } footer: {
            Text("Transcribed by ElevenLabs Scribe; confirmations are spoken back with an ElevenLabs voice. The crew only mows Tuesdays and Thursdays, so dates snap to the next Tue/Thu.")
        }
    }

    private var resultsSection: some View {
        Section("Scheduled") {
            ForEach(model.scheduled) { r in
                HStack {
                    Image(systemName: "calendar.badge.checkmark").foregroundStyle(Color.lawnGreen)
                    Text(r.customer).font(.headline)
                    Spacer()
                    Text(r.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Auto-schedule all due

    private var autoScheduleSection: some View {
        Section {
            Picker("Find the day", selection: $model.source) {
                Text("On device").tag(VoicePlanModel.Source.onDevice)
                Text("From sheet").tag(VoicePlanModel.Source.backend)
            }
            .pickerStyle(.segmented)

            Button {
                Task { await model.autoScheduleAllDue() }
            } label: {
                HStack {
                    Label("Auto-schedule due lawns", systemImage: "wand.and.stars")
                    Spacer()
                    if model.isWorking { ProgressView() }
                }
            }
            .disabled(model.isWorking)
        } header: {
            Text("Auto-schedule")
        } footer: {
            Text("Schedules every lawn that's due (or overdue) onto its next Tuesday or Thursday. “On device” computes from the loaded planning data; “From sheet” asks the Google Sheet backend (?action=autoschedule).")
        }
    }
}

/// Drives recording, ElevenLabs transcription/speech, command parsing, and the
/// Tue/Thu auto-scheduling for `VoicePlanView`.
@MainActor
final class VoicePlanModel: ObservableObject {
    enum Source { case onDevice, backend }

    struct ScheduledResult: Identifiable {
        let id = UUID()
        let customer: String
        let date: Date
    }

    @Published var transcript = ""
    @Published var status = ""
    @Published var isRecording = false
    @Published var isWorking = false
    @Published var scheduled: [ScheduledResult] = []
    @Published var errorMessage: String?
    @Published var source: Source = .onDevice

    var customers: [PlanningCustomer] = []
    private let recorder = VoiceRecorder()
    private let plan = PlanStore.shared

    // MARK: Recording

    func toggleRecording() async {
        if isRecording {
            isRecording = false
            let url = recorder.stopRecording()
            await transcribeAndAct(url)
        } else {
            transcript = ""; status = ""; scheduled = []
            let ok = await recorder.startRecording()
            if ok {
                isRecording = true
            } else {
                errorMessage = "Couldn't start recording. Check microphone access in Settings."
            }
        }
    }

    private func transcribeAndAct(_ url: URL?) async {
        guard let url else { return }
        isWorking = true
        status = "Transcribing…"
        defer { isWorking = false }
        do {
            let text = try await ElevenLabsService.transcribe(audioURL: url)
            transcript = text
            try? FileManager.default.removeItem(at: url)
            await handle(command: text)
        } catch {
            status = ""
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Command handling

    private func handle(command text: String) async {
        let lower = text.lowercased()
        let wantsAll = ["all", "everyone", "everything", "every lawn"]
            .contains { lower.contains($0) }

        let targets = wantsAll
            ? MowingSchedule.dueCustomers(customers)
            : resolveCustomers(in: lower)

        guard !targets.isEmpty else {
            let msg = "I didn't catch a customer name. Try saying a name like “plan Johnson.”"
            status = msg
            await speak(msg)
            return
        }

        let (done, skipped) = await schedule(targets, date: nil)
        scheduled = done
        let msg = confirmation(done: done, skipped: skipped)
        status = msg
        await speak(msg)
    }

    /// Customers whose name is spoken in the (lowercased) transcript.
    private func resolveCustomers(in lower: String) -> [PlanningCustomer] {
        customers.filter { c in
            let name = c.customer.lowercased().trimmingCharacters(in: .whitespaces)
            return !name.isEmpty && lower.contains(name)
        }
    }

    // MARK: Auto-schedule all due

    func autoScheduleAllDue() async {
        isWorking = true
        defer { isWorking = false }
        do {
            switch source {
            case .onDevice:
                let due = MowingSchedule.dueCustomers(customers)
                let (done, skipped) = await schedule(due, date: nil)
                scheduled = done
                status = confirmation(done: done, skipped: skipped)
            case .backend:
                let recs = try await AutoScheduleService.fetch()
                var done: [ScheduledResult] = []
                var skipped: [String] = []
                for rec in recs {
                    guard let date = rec.recommendedDate else { continue }
                    if plan.isPlanned(rec.customer) { skipped.append(rec.customer); continue }
                    await plan.add(customer: rec.customer, scheduled: date,
                                   notes: "Auto-scheduled (sheet)")
                    done.append(.init(customer: rec.customer, date: date))
                }
                scheduled = done
                status = confirmation(done: done, skipped: skipped)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Helpers

    /// Adds a planned job for each customer (skipping any already planned),
    /// computing the Tue/Thu date on-device when `date` is nil.
    private func schedule(_ targets: [PlanningCustomer], date: Date?)
        async -> (done: [ScheduledResult], skipped: [String]) {
        var done: [ScheduledResult] = []
        var skipped: [String] = []
        for c in targets {
            if plan.isPlanned(c.customer) { skipped.append(c.customer); continue }
            let when = date ?? MowingSchedule.recommendedDate(for: c)
            await plan.add(customer: c.customer, scheduled: when, notes: "Auto-scheduled by voice")
            done.append(.init(customer: c.customer, date: when))
        }
        return (done, skipped)
    }

    private func confirmation(done: [ScheduledResult], skipped: [String]) -> String {
        if done.isEmpty {
            if skipped.isEmpty { return "Nothing was due — no lawns scheduled." }
            return "Those lawns are already planned."
        }
        let fmt = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        if done.count == 1, let r = done.first {
            return "Scheduled \(r.customer) for \(r.date.formatted(fmt))."
        }
        let names = done.map(\.customer)
        let list = names.count <= 3
            ? names.joined(separator: ", ")
            : "\(names.prefix(3).joined(separator: ", ")) and \(names.count - 3) more"
        return "Scheduled \(done.count) lawns: \(list)."
    }

    private func speak(_ text: String) async {
        guard ElevenLabsService.isConfigured else { return }
        do {
            let audio = try await ElevenLabsService.speak(text)
            recorder.play(audio)
        } catch {
            ErrorLogger.log(error.localizedDescription, context: "VoicePlan.speak")
        }
    }
}

#Preview {
    VoicePlanView(customers: [])
}
