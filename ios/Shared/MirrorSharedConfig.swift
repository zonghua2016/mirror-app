import Foundation

enum MirrorSharedConfig {
    static let shapeKey = "mirror_shape"
    static let backgroundStyleKey = "mirror_background_style"
    static let backgroundIntensityKey = "mirror_background_intensity"
    static let backgroundColorBrightnessKey = "mirror_background_color_brightness"
    static let screenBrightnessKey = "mirror_screen_brightness"
    static let useCustomBackgroundColorKey = "mirror_use_custom_background_color"
    static let customBackgroundRedKey = "mirror_custom_background_red"
    static let customBackgroundGreenKey = "mirror_custom_background_green"
    static let customBackgroundBlueKey = "mirror_custom_background_blue"
    static let backgroundBlurRadiusKey = "mirror_background_blur_radius"
    static let overlayAlphaKey = "mirror_overlay_alpha"
    static let mirrorYOffsetKey = "mirror_y_offset"
    static let outlineYOffsetKey = "mirror_outline_y_offset"
    static let revealYOffsetKey = "mirror_reveal_y_offset"
    static let lensGapKey = "mirror_lens_gap"
    static let pillWidthKey = "mirror_pill_width"
    static let pillHeightKey = "mirror_pill_height"
    static let previewSizeKey = "mirror_preview_size"

    static var defaults: UserDefaults {
        .standard
    }

    static func saveShape(_ shape: MirrorShapeStyle) {
        defaults.set(shape.rawValue, forKey: shapeKey)
    }

    static func loadShape() -> MirrorShapeStyle {
        guard
            let raw = defaults.string(forKey: shapeKey),
            let style = MirrorShapeStyle(rawValue: raw)
        else {
            return .circle
        }
        return style
    }

    static func saveString(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    static func loadString(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    static func saveDouble(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    static func loadDouble(forKey key: String) -> Double? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.double(forKey: key)
    }
}
