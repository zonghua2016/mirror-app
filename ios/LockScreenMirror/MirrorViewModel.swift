import Foundation
import SwiftUI
import UIKit
import PhotosUI

enum MirrorBackgroundStyle: String, CaseIterable, Identifiable {
    case charcoal
    case warm
    case ice
    case mint
    case rose

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .charcoal:
            return Color(red: 0.22, green: 0.24, blue: 0.30)
        case .warm:
            return Color(red: 0.55, green: 0.38, blue: 0.22)
        case .ice:
            return Color(red: 0.30, green: 0.45, blue: 0.62)
        case .mint:
            return Color(red: 0.24, green: 0.54, blue: 0.46)
        case .rose:
            return Color(red: 0.58, green: 0.30, blue: 0.38)
        }
    }
}

@MainActor
final class MirrorViewModel: ObservableObject {
    @Published var shape: MirrorShapeStyle = .circle {
        didSet { MirrorSharedConfig.saveShape(shape) }
    }
    @Published var settingsPanelVisible = true
    @Published var flashOverlayVisible = false
    @Published var quickMirrorActive = true

    @Published var backgroundStyle: MirrorBackgroundStyle = .charcoal {
        didSet { MirrorSharedConfig.saveString(backgroundStyle.rawValue, forKey: MirrorSharedConfig.backgroundStyleKey) }
    }
    @Published var useCustomBackgroundColor = false {
        didSet { MirrorSharedConfig.saveDouble(useCustomBackgroundColor ? 1 : 0, forKey: MirrorSharedConfig.useCustomBackgroundColorKey) }
    }
    @Published var customBackgroundColor: Color = Color(red: 0.32, green: 0.36, blue: 0.43) {
        didSet { saveCustomBackgroundColor() }
    }

    // 背景图片支持
    @Published var useBackgroundImage = false {
        didSet { MirrorSharedConfig.saveDouble(useBackgroundImage ? 1 : 0, forKey: "useBackgroundImage") }
    }
    @Published var backgroundImage: PhotosPickerItem? = nil {
        didSet {
            if let item = backgroundImage {
                // 将 PhotosPickerItem 转换为 UIImage
                Task { @MainActor in
                    do {
                        // 使用 loadTransferable 加载数据
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            self.backgroundImageAsUIImage = image
                            // 保存图片
                            saveBackgroundImage(image)
                        }
                    }
                }
            } else {
                backgroundImageAsUIImage = nil
            }
        }
    }
    // 用于界面渲染的 UIImage 版本
    @Published var backgroundImageAsUIImage: UIImage? = nil

    // Reference style panel tuning parameters.
    @Published var backgroundBlurRadius: CGFloat = 0 {
        didSet { persistClamped(\.backgroundBlurRadius, in: 0...30, key: MirrorSharedConfig.backgroundBlurRadiusKey) }
    }

    // 内部使用的参数（不在设置面板中显示）
    @Published var overlayAlpha: CGFloat = 0.8
    @Published var mirrorYOffset: CGFloat = -69
    @Published var outlineYOffset: CGFloat = -60
    @Published var revealYOffset: CGFloat = 0
    @Published var lensGap: CGFloat = 0
    @Published var pillWidth: CGFloat = 109
    @Published var pillHeight: CGFloat = 54

    @Published var backgroundIntensity: CGFloat = 0.42 {
        didSet {
            let clamped = max(0, min(1, backgroundIntensity))
            if abs(clamped - backgroundIntensity) > .ulpOfOne {
                backgroundIntensity = clamped
                return
            }
            MirrorSharedConfig.saveDouble(Double(backgroundIntensity), forKey: MirrorSharedConfig.backgroundIntensityKey)
        }
    }
    @Published var screenBrightness: CGFloat = UIScreen.main.brightness {
        didSet {
            let clamped = max(0.1, min(1.0, screenBrightness))
            if abs(clamped - screenBrightness) > .ulpOfOne {
                screenBrightness = clamped
                return
            }
            UIScreen.main.brightness = screenBrightness
            MirrorSharedConfig.saveDouble(Double(screenBrightness), forKey: MirrorSharedConfig.screenBrightnessKey)
        }
    }

    @Published var persistentScale: CGFloat = 1.0
    @Published var transientScale: CGFloat = 1.0

    @Published var previewSize: CGFloat = 250 {
        didSet {
            let clamped = max(250, min(350, previewSize))
            if abs(clamped - previewSize) > .ulpOfOne {
                previewSize = clamped
                return
            }
            MirrorSharedConfig.saveDouble(Double(previewSize), forKey: MirrorSharedConfig.previewSizeKey)
        }
    }

    // 动画增强参数
    @Published var islandBreathePhase: CGFloat = 0 // 呼吸动画相位

    init() {
        shape = MirrorSharedConfig.loadShape()
        if
            let raw = MirrorSharedConfig.loadString(forKey: MirrorSharedConfig.backgroundStyleKey),
            let style = MirrorBackgroundStyle(rawValue: raw)
        {
            backgroundStyle = style
        }

        useCustomBackgroundColor = (MirrorSharedConfig.loadDouble(forKey: MirrorSharedConfig.useCustomBackgroundColorKey) ?? 0) > 0.5
        if
            let r = MirrorSharedConfig.loadDouble(forKey: MirrorSharedConfig.customBackgroundRedKey),
            let g = MirrorSharedConfig.loadDouble(forKey: MirrorSharedConfig.customBackgroundGreenKey),
            let b = MirrorSharedConfig.loadDouble(forKey: MirrorSharedConfig.customBackgroundBlueKey)
        {
            customBackgroundColor = Color(red: r, green: g, blue: b)
        }

        // 加载背景图片设置
        useBackgroundImage = (MirrorSharedConfig.loadDouble(forKey: "useBackgroundImage") ?? 0) > 0.5
        backgroundImageAsUIImage = loadBackgroundImage()

        backgroundBlurRadius = CGFloat(MirrorSharedConfig.loadDouble(forKey: MirrorSharedConfig.backgroundBlurRadiusKey) ?? Double(backgroundBlurRadius))

        if let intensity = MirrorSharedConfig.loadDouble(forKey: MirrorSharedConfig.backgroundIntensityKey) {
            backgroundIntensity = max(0, min(1, CGFloat(intensity)))
        }

        if let brightness = MirrorSharedConfig.loadDouble(forKey: MirrorSharedConfig.screenBrightnessKey) {
            screenBrightness = max(0.1, min(1.0, CGFloat(brightness)))
        }

        if let savedPreviewSize = MirrorSharedConfig.loadDouble(forKey: MirrorSharedConfig.previewSizeKey) {
            previewSize = max(250, min(350, CGFloat(savedPreviewSize)))
        }

        // 启动呼吸动画
        startBreathingAnimation()
    }

    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            islandBreathePhase = 1
        }
    }

    func magnifyChanged(_ value: CGFloat) {
        transientScale = value
    }

    func magnifyEnded(_ value: CGFloat) {
        persistentScale = max(0.6, min(2.4, persistentScale * value))
        transientScale = 1.0
    }

    var finalScale: CGFloat {
        max(0.6, min(2.4, persistentScale * transientScale))
    }

    func triggerFlashOverlay() {
        withAnimation(.easeIn(duration: 0.08)) {
            flashOverlayVisible = true
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.08)) {
            flashOverlayVisible = false
        }
    }

    func setQuickMirrorVisible(_ visible: Bool) {
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            quickMirrorActive = visible
        }
    }

    func toggleQuickMirror() {
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
            quickMirrorActive.toggle()
        }
    }

    func applyCurrentBrightness() {
        UIScreen.main.brightness = screenBrightness
    }

    var resolvedBackgroundColor: Color {
        let baseColor = useCustomBackgroundColor ? customBackgroundColor : backgroundStyle.color
        // 直接返回原始颜色，不应用亮度调整
        return baseColor
    }

    private func persistClamped(_ keyPath: ReferenceWritableKeyPath<MirrorViewModel, CGFloat>, in range: ClosedRange<CGFloat>, key: String) {
        let value = self[keyPath: keyPath]
        let clamped = max(range.lowerBound, min(range.upperBound, value))
        if abs(clamped - value) > .ulpOfOne {
            self[keyPath: keyPath] = clamped
            return
        }
        MirrorSharedConfig.saveDouble(Double(clamped), forKey: key)
    }

    private func saveCustomBackgroundColor() {
        let uiColor = UIColor(customBackgroundColor)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
        MirrorSharedConfig.saveDouble(Double(r), forKey: MirrorSharedConfig.customBackgroundRedKey)
        MirrorSharedConfig.saveDouble(Double(g), forKey: MirrorSharedConfig.customBackgroundGreenKey)
        MirrorSharedConfig.saveDouble(Double(b), forKey: MirrorSharedConfig.customBackgroundBlueKey)
    }

    private func saveBackgroundImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("background_image.jpg")
        try? imageData.write(to: fileURL)
    }

    private func loadBackgroundImage() -> UIImage? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("background_image.jpg")
        return UIImage(contentsOfFile: fileURL.path)
    }

}
