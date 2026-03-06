import SwiftUI
import UIKit

@main
struct LockScreenMirrorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - SceneDelegate for handling URL schemes
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)

        // Use SwiftUI for the main interface
        window?.rootViewController = UIHostingController(rootView: ContentView())
        window?.makeKeyAndVisible()

        // Handle URL schemes from widgets and action button
        if let urlContext = connectionOptions.urlContexts.first {
            handleDeepLink(urlContext.url)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Handle deep links from widgets
        if let url = userActivity.webpageURL {
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Handle different URL schemes
        if url.scheme == "LockScreenMirror" {
            switch url.host {
            case "open":
                // Open the main app
                print("Opening mirror app...")
            case "activate":
                // Activate the mirror
                print("Activating mirror...")
            case "deactivate":
                // Deactivate the mirror
                print("Deactivating mirror...")
            case "toggle-shape":
                // Toggle between shapes
                print("Toggling shape...")
            case "scale":
                // Adjust scale
                print("Adjusting scale...")
            case "face-tracking":
                // Toggle face tracking
                print("Toggling face tracking...")
            default:
                break
            }
        }
    }

    func scene(_ scene: UIScene, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }
}

// MARK: - URL Scheme Registration
// In Info.plist:
// <key>CFBundleURLTypes</key>
// <array>
//   <dict>
//     <key>CFBundleURLName</key>
//     <string>com.yourcompany.LockScreenMirror</string>
//     <key>CFBundleURLSchemes</key>
//     <array>
//       <string>LockScreenMirror</string>
//     </array>
//   </dict>
// </array>