import SwiftUI

@main
struct LockScreenMirrorApp: App {
    // This is the entry point for the main app
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar) // For lock screen experience
    }
}

// MARK: - App Delegate for handling URL schemes
@main
struct App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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