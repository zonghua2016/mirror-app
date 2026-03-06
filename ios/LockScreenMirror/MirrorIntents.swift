import AppIntents

@available(iOS 17.0, *)
struct OpenMirrorIntent: AppIntent {
    static var title: LocalizedStringResource { "Open Mirror" }
    static var description: IntentDescription { IntentDescription("Open Lock Screen Mirror instantly") }
    static let openAppWhenRun = true

    private var mirrorURL: URL {
        URL(string: "lockscreenmirror://open?source=shortcut")!
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if #available(iOS 18.0, *) {
            return .result(opensIntent: OpenURLIntent(mirrorURL))
        }

        IntentBridge.shared.fireIntent()
        return .result()
    }
}

@available(iOS 17.0, *)
struct MirrorShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenMirrorIntent(),
            phrases: [
                "Open mirror in \(.applicationName)",
                "Launch mirror in \(.applicationName)"
            ],
            shortTitle: "Mirror",
            systemImageName: "camera.fill"
        )
    }
}

@MainActor
final class IntentBridge {
    static let shared = IntentBridge()
    var onOpenMirror: (() -> Void)?

    func fireIntent() {
        onOpenMirror?()
    }
}
