import SwiftUI

struct MirrorMaskShape: Shape {
    var style: MirrorShapeStyle
    var blobPhase: CGFloat

    var animatableData: CGFloat {
        get { blobPhase }
        set { blobPhase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        switch style {
        case .circle:
            return Circle().path(in: rect)
        case .stadium:
            return Capsule(style: .continuous).path(in: rect)
        case .blob:
            return blobPath(in: rect)
        }
    }

    private func blobPath(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()
        path.move(to: CGPoint(x: 0.19 * w, y: 0.21 * h))
        path.addCurve(
            to: CGPoint(x: 0.81 * w, y: 0.2 * h),
            control1: CGPoint(x: 0.34 * w, y: (0.02 + 0.09 * blobPhase) * h),
            control2: CGPoint(x: 0.66 * w, y: (0.01 + 0.07 * blobPhase) * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.87 * w, y: 0.83 * h),
            control1: CGPoint(x: 0.99 * w, y: 0.34 * h),
            control2: CGPoint(x: 0.98 * w, y: 0.67 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.21 * w, y: 0.85 * h),
            control1: CGPoint(x: 0.69 * w, y: 0.98 * h),
            control2: CGPoint(x: 0.31 * w, y: 0.99 * h)
        )
        path.addCurve(
            to: CGPoint(x: 0.19 * w, y: 0.21 * h),
            control1: CGPoint(x: 0.03 * w, y: 0.69 * h),
            control2: CGPoint(x: 0.02 * w, y: 0.35 * h)
        )
        path.closeSubpath()
        return path
    }
}

struct MirrorIslandLensShape: Shape {
    var circleTopInset: CGFloat
    var pillWidth: CGFloat
    var pillHeight: CGFloat
    var gap: CGFloat

    func path(in rect: CGRect) -> Path {
        let topInset = max(0, circleTopInset)
        let diameter = max(1, min(rect.width, rect.height - topInset))
        let circleRect = CGRect(
            x: (rect.width - diameter) / 2,
            y: topInset,
            width: diameter,
            height: diameter
        )

        let resolvedPillHeight = max(10, min(120, pillHeight))
        let resolvedPillWidth = max(44, min(rect.width * 0.95, pillWidth))
        let pillY = circleRect.minY - resolvedPillHeight - gap
        let pillRect = CGRect(
            x: circleRect.midX - (resolvedPillWidth / 2),
            y: pillY,
            width: resolvedPillWidth,
            height: resolvedPillHeight
        )

        var path = Path()
        path.addEllipse(in: circleRect)
        path.addRoundedRect(
            in: pillRect,
            cornerSize: CGSize(width: resolvedPillHeight / 2, height: resolvedPillHeight / 2)
        )
        return path
    }
}

struct MorphingMirrorShape: Shape {
    var progress: CGFloat // 0.0 是灵动岛状态，1.0 是完全展开状态
    var targetStyle: MirrorShapeStyle
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        // 初始状态：灵动岛尺寸 (约为 126x37)
        let islandWidth: CGFloat = 126
        let islandHeight: CGFloat = 37
        let islandRect = CGRect(
            x: rect.midX - (islandWidth / 2 * (1 - progress)),
            y: 0, // 紧贴顶部
            width: islandWidth + (rect.width - islandWidth) * progress,
            height: islandHeight + (rect.height - islandHeight) * progress
        )
        
        // 根据目标形状进行插值计算
        switch targetStyle {
        case .circle:
            return Path(UIBezierPath(roundedRect: islandRect, cornerRadius: islandRect.height / 2).cgPath)
        case .stadium:
            return Path(UIBezierPath(roundedRect: islandRect, cornerRadius: 40 * progress + (islandRect.height / 2) * (1 - progress)).cgPath)
        case .blob:
            // 这里可以结合你原有的 blobPath 逻辑进行 progress 插值
            return Circle().path(in: islandRect) 
        }
    }
}