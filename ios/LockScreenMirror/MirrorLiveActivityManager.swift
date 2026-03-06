import ActivityKit
import Foundation

@MainActor
final class MirrorLiveActivityManager {
    static let shared = MirrorLiveActivityManager()

    private var activity: Activity<MirrorActivityAttributes>?

    func sync(isVisible: Bool, shape: MirrorShapeStyle) {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let contentState = MirrorActivityAttributes.ContentState(
            shapeRawValue: shape.rawValue,
            isPreviewVisible: isVisible
        )
        let content = ActivityContent(state: contentState, staleDate: nil)

        if isVisible {
            if let existing = activity {
                Task { await existing.update(content) }
                return
            }

            do {
                let attributes = MirrorActivityAttributes(title: "Lock Screen Mirror")
                activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                activity = nil
            }
        } else {
            guard let existing = activity else { return }
            Task {
                await existing.end(content, dismissalPolicy: .immediate)
            }
            activity = nil
        }
    }
}
