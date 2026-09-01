import Foundation
import Observation

enum AppTab: Hashable {
    case tonight
    case journal
    case log
    case atlas
    case circle
}

enum Route: Hashable {
    case spot(UUID)
    case entry(UUID)
    case friend(UUID)
    case collection(UUID)
    case saved
    case settings
    case scan
    case calendar
}

@MainActor
@Observable
final class Router {
    var tab: AppTab = .tonight
    var tonightPath: [Route] = []
    var journalPath: [Route] = []
    var atlasPath: [Route] = []
    var circlePath: [Route] = []

    func open(_ route: Route, in tab: AppTab? = nil) {
        let target = tab ?? preferredTab(for: route)
        self.tab = target
        switch target {
        case .tonight: tonightPath.append(route)
        case .journal: journalPath.append(route)
        case .atlas: atlasPath.append(route)
        case .circle: circlePath.append(route)
        case .log: break
        }
    }

    func apply(_ link: DeepLink) {
        switch link {
        case .spot(let id):
            open(.spot(id), in: .atlas)
        case .entry(let id):
            open(.entry(id), in: .journal)
        }
    }

    private func preferredTab(for route: Route) -> AppTab {
        switch route {
        case .spot: return .atlas
        case .entry, .calendar: return .journal
        case .friend, .collection, .saved, .settings, .scan: return .circle
        }
    }
}
