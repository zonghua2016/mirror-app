import UIKit
import SwiftUI

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let coordinator = AppCoordinator()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        IntentBridge.shared.onOpenMirror = { [weak self] in
            Task { @MainActor in
                self?.coordinator.openFromIntent()
            }
        }

        if let url = connectionOptions.urlContexts.first?.url {
            coordinator.handle(url: url)
        }
        if let activity = connectionOptions.userActivities.first {
            handle(userActivity: activity)
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: RootCoordinatorView(coordinator: coordinator))
        window.makeKeyAndVisible()
        self.window = window
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        coordinator.handle(url: url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handle(userActivity: userActivity)
    }

    private func handle(userActivity: NSUserActivity) {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            coordinator.handle(url: url)
            return
        }

        if userActivity.activityType == "com.apple.shortcuts.run-intent" {
            coordinator.openFromIntent()
            return
        }

        if let incomingURL = userActivity.userInfo?["url"] as? URL {
            coordinator.handle(url: incomingURL)
            return
        }

        if let incomingURLString = userActivity.userInfo?["url"] as? String,
           let incomingURL = URL(string: incomingURLString) {
            coordinator.handle(url: incomingURL)
            return
        }

        if userActivity.activityType == "NSUserActivityTypeLockedCameraCapture" {
            coordinator.openFromIntent()
            return
        }

        let normalizedType = userActivity.activityType.lowercased()
        if normalizedType.contains("camera") || normalizedType.contains("capture") || normalizedType.contains("intent") {
            coordinator.openFromIntent()
        }
    }
}
