import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema([
        Spot.self,
        SunsetEntry.self,
        SkyCollection.self,
        Person.self,
        SharedSpotNote.self,
        UserPrefs.self
    ])

    static func container(inMemory: Bool = false) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            SeedStore.bootstrapIfNeeded(container.mainContext)
            return container
        } catch {
            fatalError("Sunset Log could not open its journal: \(error)")
        }
    }
}
