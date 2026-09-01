import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        @Bindable var session = session

        TabView(selection: $router.tab) {
            NavigationStack(path: $router.tonightPath) {
                HomeView()
                    .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
            }
            .tag(AppTab.tonight)
            .tabItem { Label("Tonight", systemImage: "moon.haze.fill") }

            NavigationStack(path: $router.journalPath) {
                JournalView()
                    .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
            }
            .tag(AppTab.journal)
            .tabItem { Label("Journal", systemImage: "book.closed.fill") }

            Color.clear
                .tag(AppTab.log)
                .tabItem { Label("Log", systemImage: "plus") }

            NavigationStack(path: $router.atlasPath) {
                AtlasView()
                    .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
            }
            .tag(AppTab.atlas)
            .tabItem { Label("Atlas", systemImage: "map") }

            NavigationStack(path: $router.circlePath) {
                CircleHomeView()
                    .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
            }
            .tag(AppTab.circle)
            .tabItem { Label("Circle", systemImage: "sparkles") }
        }
        .tint(Palette.ember)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onChange(of: router.tab) { _, new in
            if new == .log {
                session.logPresented = true
                router.tab = .tonight
            }
        }
        .sheet(isPresented: $session.logPresented) {
            LogSunsetView()
                .environment(session)
                .environment(router)
        }
        .sheet(isPresented: $session.scanPresented) {
            NavigationStack {
                LibraryScanView()
            }
            .environment(session)
            .environment(router)
        }
        .onChange(of: session.pendingLink) { _, link in
            if let link {
                router.apply(link)
                session.pendingLink = nil
            }
        }
        .task {
            session.start()
        }
    }
}
