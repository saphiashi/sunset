import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.modelContext) private var context
    @Query private var prefs: [UserPrefs]
    @State private var showReset = false
    @State private var newCollection = false

    private var settings: UserPrefs {
        if let existing = prefs.first { return existing }
        let created = UserPrefs()
        context.insert(created)
        return created
    }

    var body: some View {
        List {
            Section {
                Toggle("Sunset tonight reminder", isOn: reminderBinding)
                Stepper(
                    "Alert \(settings.reminderLeadMinutes) minutes before",
                    value: leadBinding,
                    in: 5...90,
                    step: 5
                )
                if session.notifications.authorization == .denied {
                    Button("Notifications are off — open Settings") {
                        SettingsDeeplink.open()
                    }
                }
                if let scheduled = session.notifications.lastScheduledSunset {
                    Text("Next ping is aimed at \(scheduled.formatted(date: .abbreviated, time: .shortened)).")
                        .font(Typeface.caption(12))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Last light")
            } footer: {
                Text("A local notification, scheduled from the next computed sunset. Nothing leaves the phone.")
            }

            Section("Library") {
                NavigationLink(value: Route.scan) {
                    Label("Scan camera roll", systemImage: "photo.on.rectangle")
                }
                Button("New collection") { newCollection = true }
            }

            Section("Location") {
                LabeledContent("Status", value: locationLabel)
                if session.location.isDenied {
                    Button("Allow location in Settings") { SettingsDeeplink.open() }
                } else {
                    Button("Refresh position") { session.location.request() }
                }
            }

            Section("About") {
                LabeledContent("Social", value: "Mock client")
                LabeledContent("Persistence", value: "SwiftData, on device")
                Text("Share cards for Stories are not in this build. Sunrise logging is out of scope.")
                    .font(Typeface.caption(12))
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reseed demo data", role: .destructive) {
                    showReset = true
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await session.notifications.refresh()
            await syncReminder()
        }
        .onChange(of: settings.remindersEnabled) { _, _ in
            Task { await syncReminder() }
        }
        .onChange(of: settings.reminderLeadMinutes) { _, _ in
            Task { await syncReminder() }
        }
        .confirmationDialog("Replace the journal with seed evenings?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Reseed", role: .destructive) {
                SeedStore.reset(context)
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $newCollection) {
            NewCollectionSheet()
        }
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { settings.remindersEnabled },
            set: { new in
                settings.remindersEnabled = new
                try? context.save()
                if new {
                    Task {
                        _ = await session.notifications.request()
                        await syncReminder()
                    }
                } else {
                    Task { await syncReminder() }
                }
            }
        )
    }

    private var leadBinding: Binding<Int> {
        Binding(
            get: { settings.reminderLeadMinutes },
            set: { new in
                settings.reminderLeadMinutes = new
                try? context.save()
                Task { await syncReminder() }
            }
        )
    }

    private func syncReminder() async {
        await session.notifications.syncReminder(
            enabled: settings.remindersEnabled,
            leadMinutes: settings.reminderLeadMinutes,
            sunset: session.nextSunset
        )
    }

    private var locationLabel: String {
        switch session.location.authorization {
        case .authorizedAlways, .authorizedWhenInUse: return "When in use"
        case .denied, .restricted: return "Denied"
        case .notDetermined: return "Not asked"
        @unknown default: return "Unknown"
        }
    }
}
