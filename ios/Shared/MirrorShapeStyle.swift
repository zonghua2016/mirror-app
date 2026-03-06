import Foundation

enum MirrorShapeStyle: String, CaseIterable, Identifiable {
    case circle
    case stadium
    case blob

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .circle: return "circle"
        case .stadium: return "capsule"
        case .blob: return "seal"
        }
    }
}
