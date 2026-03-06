import AppIntents
import Foundation

@available(iOS 18.0, *)
struct StartMirrorCaptureIntent: CameraCaptureIntent {
    static var title: LocalizedStringResource { "Start Mirror Capture" }
    static var description: IntentDescription {
        IntentDescription("Launch mirror capture from lock screen camera control")
    }
    static let openAppWhenRun = true
    private var controlURL: URL {
        URL(string: "lockscreenmirror://open?source=control&quick=1")!
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        .result(opensIntent: OpenURLIntent(controlURL))
    }
}
