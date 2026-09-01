import SwiftUI
import SwiftData

struct RouteDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case .spot(let id):
            SpotDetailView(spotID: id)
        case .entry(let id):
            EntryDetailView(entryID: id)
        case .friend(let id):
            FriendProfileView(personID: id)
        case .collection(let id):
            CollectionDetailView(collectionID: id)
        case .saved:
            SavedSpotsView()
        case .settings:
            SettingsView()
        case .scan:
            LibraryScanView()
        case .calendar:
            CalendarJournalView()
        }
    }
}
