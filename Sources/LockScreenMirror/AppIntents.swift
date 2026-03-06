import AppIntents
import Foundation
import UIKit

// MARK: - AppIntent for launching the mirror
struct OpenMirrorIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Mirror"
    static var description = IntentDescription("Launch the Lock Screen Mirror app")

    func perform() async throws -> some IntentResult {
        // Open the main app
        let url = URL(string: "LockScreenMirror://open")!
        UIApplication.shared.open(url)

        return .result()
    }
}

// MARK: - AppIntent for activating the mirror from Control Center
struct ActivateMirrorIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate Mirror"
    static var description = IntentDescription("Activate the mirror feature")

    @Parameter(title: "Duration", default: 10)
    var duration: Int

    func perform() async throws -> some IntentResult {
        // This intent will be triggered from Control Center
        // We need to communicate with the main app to activate the mirror
        let url = URL(string: "LockScreenMirror://activate?duration=\(duration)")!
        UIApplication.shared.open(url)

        return .result()
    }
}

// MARK: - AppIntent for deactivating the mirror
struct DeactivateMirrorIntent: AppIntent {
    static var title: LocalizedStringResource = "Deactivate Mirror"
    static var description = IntentDescription("Deactivate the mirror feature")

    func perform() async throws -> some IntentResult {
        let url = URL(string: "LockScreenMirror://deactivate")!
        UIApplication.shared.open(url)

        return .result()
    }
}

// MARK: - AppIntent for toggling shape
struct ToggleShapeIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Shape"
    static var description = IntentDescription("Toggle between circle, stadium, and custom shapes")

    func perform() async throws -> some IntentResult {
        let url = URL(string: "LockScreenMirror://toggle-shape")!
        UIApplication.shared.open(url)

        return .result()
    }
}

// MARK: - AppIntent for adjusting scale
struct AdjustScaleIntent: AppIntent {
    static var title: LocalizedStringResource = "Adjust Scale"
    static var description = IntentDescription("Adjust the mirror scale")

    @Parameter(title: "Scale", default: 1.0)
    var scale: Double

    func perform() async throws -> some IntentResult {
        let url = URL(string: "LockScreenMirror://scale?value=\(scale)")!
        UIApplication.shared.open(url)

        return .result()
    }
}

// MARK: - AppIntent for toggling face tracking
struct ToggleFaceTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Face Tracking"
    static var description = IntentDescription("Toggle face tracking")

    @Parameter(title: "Enabled", default: true)
    var enabled: Bool

    func perform() async throws -> some IntentResult {
        let action = enabled ? "enable" : "disable"
        let url = URL(string: "LockScreenMirror://face-tracking?status=\(action)")!
        UIApplication.shared.open(url)

        return .result()
    }
}

// MARK: - AppIntent for opening the app from Action Button
struct ActionButtonIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Mirror"
    static var description = IntentDescription("Open the Lock Screen Mirror app from Action Button")

    func perform() async throws -> some IntentResult {
        let url = URL(string: "LockScreenMirror://open")!
        UIApplication.shared.open(url)

        return .result()
    }
}

// MARK: - AppIntent for showing Control Center widget
struct ShowControlCenterIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Control Center"
    static var description = IntentDescription("Show Control Center with mirror controls")

    func perform() async throws -> some IntentResult {
        // This is a hint to the system to show Control Center
        // In practice, this would be triggered by the user swiping down
        return .result()
    }
}

// MARK: - AppIntent for hiding Control Center widget
struct HideControlCenterIntent: AppIntent {
    static var title: LocalizedStringResource = "Hide Control Center"
    static var description = IntentDescription("Hide Control Center")

    func perform() async throws -> some IntentResult {
        // This would be triggered by the user swiping up
        return .result()
    }
}