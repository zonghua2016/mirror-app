import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct MirrorActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var shapeRawValue: String
        var isPreviewVisible: Bool
    }

    var title: String
}
