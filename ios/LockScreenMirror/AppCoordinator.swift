import Foundation
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    enum Route {
        case mirror
    }

    @Published var route: Route = .mirror
    @Published var launchSource: String = "App"
    @Published var lastOpenToken: Int = 0
    @Published private(set) var pendingQuickMirrorReveal = false

    func handle(url: URL) {
        guard let scheme = url.scheme?.lowercased() else { return }
        guard scheme == "lockscreenmirror" || scheme == "mirrorapp" else { return }

        route = .mirror
        launchSource = launchSourceText(from: url) ?? "DeepLink"
        if shouldRevealQuickMirror(from: url) {
            pendingQuickMirrorReveal = true
        }
        lastOpenToken &+= 1
    }

    func openFromIntent() {
        route = .mirror
        launchSource = "Intent"
        pendingQuickMirrorReveal = true
        lastOpenToken &+= 1
    }

    func consumePendingQuickMirrorReveal() -> Bool {
        let shouldReveal = pendingQuickMirrorReveal
        pendingQuickMirrorReveal = false
        return shouldReveal
    }

    private func launchSourceText(from url: URL) -> String? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let source = components.queryItems?.first(where: { $0.name == "source" })?.value
        else {
            return nil
        }

        switch source.lowercased() {
        case "widget":
            return "Widget"
        case "control":
            return "ControlCenter"
        case "lockedcapture":
            return "LockedCapture"
        case "shortcut":
            return "Shortcut"
        case "actionbutton":
            return "ActionButton"
        default:
            return "DeepLink"
        }
    }

    private func shouldRevealQuickMirror(from url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        let items = components.queryItems ?? []
        let quickValue = items.first(where: { $0.name == "quick" })?.value?.lowercased()
        return quickValue == "1" || quickValue == "true" || quickValue == "yes"
    }
}

struct RootCoordinatorView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        switch coordinator.route {
        case .mirror:
            MirrorScreenView(coordinator: coordinator)
        }
    }
}
