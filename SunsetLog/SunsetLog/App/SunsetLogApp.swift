import SwiftUI
import SwiftData

@main
struct SunsetLogApp: App {
    @State private var session = AppSession()
    @State private var router = Router()
    private let container: ModelContainer = Persistence.container()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(router)
                .preferredColorScheme(nil)
                .onOpenURL { url in
                    session.pendingLink = DeepLink.parse(url)
                }
        }
        .modelContainer(container)
    }
}
