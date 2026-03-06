import UIKit
import SwiftUI

// MARK: - SceneDelegate for handling URL schemes
@MainActor
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)

        // Use SwiftUI for the main interface
        window?.rootViewController = UIHostingController(rootView: ContentView())
        window?.makeKeyAndVisible()

        // Handle URL schemes from widgets and action button
        if let url = connectionOptions.urlContexts.first?.url {
            handleDeepLink(url)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Handle deep links from widgets
        if let url = userActivity.webpageURL {
            handleDeepLink(url)
        }
    }

    // MARK: - URL Scheme Handling

    private func handleDeepLink(_ url: URL) {
        // Handle different URL schemes
        if url.scheme == "LockScreenMirror" {
            switch url.host {
            case "open":
                // Open the main app
                DispatchQueue.main.async {
                    // This will be handled by the main app
                    // We're just ensuring the app is activated
                }
            case "activate":
                // Activate the mirror
                // Parse duration from query parameters
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let durationString = components.queryItems?.first(where: { $0.name == "duration" })?.value,
                   let duration = Int(durationString) {
                    // Send notification to main app to activate mirror with duration
                }
            case "deactivate":
                // Deactivate the mirror
                // Send notification to main app to deactivate mirror

            case "toggle-shape":
                // Toggle between shapes
                // Send notification to main app to toggle shape

            case "scale":
                // Adjust scale
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let scaleString = components.queryItems?.first(where: { $0.name == "value" })?.value,
                   let scale = Double(scaleString) {
                    // Send notification to main app to adjust scale
                }

            case "face-tracking":
                // Toggle face tracking
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let status = components.queryItems?.first(where: { $0.name == "status" })?.value {
                    let enabled = status == "enable"
                    // Send notification to main app to toggle face tracking
                }

            default:
                break
            }
        }
    }

    func scene(_ scene: UIScene, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}