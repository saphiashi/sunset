import SwiftUI

struct ReportTarget: Identifiable, Hashable {
    let personID: UUID?
    let entryID: UUID?
    let handle: String

    var id: String { "\(personID?.uuidString ?? "-")/\(entryID?.uuidString ?? "-")" }
}

struct ReportSheet: View {
    let target: ReportTarget
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason = .inappropriate
    @State private var details = ""
    @State private var sending = false
    @State private var error: String?
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Text("Thanks. We review every report, and you can also block @\(target.handle) from their profile.")
                    }
                } else {
                    Section(target.entryID == nil ? "Why report @\(target.handle)?" : "What’s wrong with this sunset?") {
                        Picker("Reason", selection: $reason) {
                            ForEach(ReportReason.allCases) { reason in
                                Text(reason.title).tag(reason)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                    Section("Anything else (optional)") {
                        TextField("Details", text: $details, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    if let error {
                        Section {
                            Text(error).foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
                if !sent {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") { Task { await send() } }
                            .disabled(sending)
                    }
                }
            }
        }
    }

    private func send() async {
        sending = true
        defer { sending = false }
        do {
            try await session.social.report(
                personID: target.personID,
                entryID: target.entryID,
                reason: reason,
                details: details
            )
            sent = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
