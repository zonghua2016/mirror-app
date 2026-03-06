import SwiftUI
import UIKit
import CoreHaptics
import PhotosUI

struct MirrorScreenView: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var viewModel = MirrorViewModel()
    @StateObject private var cameraController = CameraSessionController()

    @Namespace private var shapeSelectionNamespace
    @State private var blobPhase: CGFloat = 0
    @State private var lastAutoRevealToken: Int = -1
    @State private var islandRevealProgress: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let safeTop = effectiveTopInset(fallback: proxy.safeAreaInsets.top)

            ZStack {
                ambientBackground

                mirrorPreview(
                    safeTop: safeTop,
                    canvasWidth: proxy.size.width,
                    canvasHeight: proxy.size.height
                )

                if viewModel.flashOverlayVisible {
                    Color.white
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                VStack(spacing: 12) {
                    Spacer()
                    if viewModel.settingsPanelVisible {
                        settingsPanel
                    }
                    holdToMirrorControls
                }
                .padding(.horizontal, 16)
                .padding(.top, max(safeTop, 16))
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 14))
            }
        }
        .statusBarHidden(true)
        .task {
            let granted = await cameraController.requestPermissionIfNeeded()
            guard granted else { return }

            cameraController.configureSession()
            cameraController.startRunning()
            viewModel.setQuickMirrorVisible(true)
            applyThermalPolicy()
        }
        .onAppear {
            viewModel.shape = .circle
            // 不在这里设置镜子显示，由 triggerQuickMirrorIfNeeded() 完全控制
            islandRevealProgress = viewModel.quickMirrorActive ? 1 : 0
            viewModel.applyCurrentBrightness()
            // 应用初始焦距设置
            cameraController.setZoomLevel(viewModel.finalScale)
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
            triggerQuickMirrorIfNeeded()
        }
        .onDisappear {
            cameraController.stopRunning()
            MirrorLiveActivityManager.shared.sync(isVisible: false, shape: viewModel.shape)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                cameraController.startRunning()
                viewModel.applyCurrentBrightness()
                applyThermalPolicy()
            default:
                cameraController.stopRunning()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            applyThermalPolicy()
        }
        .onChange(of: coordinator.lastOpenToken) { _, _ in
            cameraController.startRunning()
            triggerQuickMirrorIfNeeded()
        }
        .onChange(of: viewModel.quickMirrorActive) { _, visible in
            MirrorLiveActivityManager.shared.sync(isVisible: visible, shape: viewModel.shape)
            animateIslandReveal(visible: visible)
            // 更新焦距
            cameraController.setZoomLevel(viewModel.finalScale)
        }
        .onChange(of: viewModel.shape) { _, shape in
            MirrorLiveActivityManager.shared.sync(isVisible: viewModel.quickMirrorActive, shape: shape)
        }
    }

    private func mirrorPreview(safeTop: CGFloat, canvasWidth: CGFloat, canvasHeight: CGFloat) -> some View {
        let pinchGesture = MagnificationGesture()
            .onChanged { value in
                viewModel.magnifyChanged(value)
            }
            .onEnded { value in
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    viewModel.magnifyEnded(value)
                }
            }

        let visible = viewModel.quickMirrorActive
        // 显示框大小只由 previewSize 和可见性决定，不受 finalScale（焦距）影响
        let displayScale = visible ? 1.0 : 0.64
        let islandStyle = supportsDynamicIsland(safeTop: safeTop)
        let islandMetrics = islandStyle ? dynamicIslandMetrics(topInset: safeTop, canvasWidth: canvasWidth) : nil
        let previewFrameHeight = viewModel.previewSize
        let displayHeight = previewFrameHeight * displayScale

        // 灵动岛底部作为镜子动画的基准点
        let anchorY = mirrorAnchorY(
            islandBottomY: islandMetrics?.bottomY,
            previewHeight: displayHeight,
            safeTop: safeTop,
            canvasHeight: canvasHeight
        )
        let baseYOffset = anchorY - (canvasHeight / 2)

        // 确保在 islandStyle 模式下，contentYOffset 为 0，避免之前的 mirrorYOffset 干扰
        // 但保留 outlineYOffset 用于同步调整模拟灵动岛和镜子位置
        let contentYOffset = islandStyle ? viewModel.outlineYOffset : viewModel.mirrorYOffset
        let renderShape = mirrorRenderShape(islandStyle: islandStyle)
        let mirrorCenterYOffset = baseYOffset + contentYOffset
        let revealProgress = islandStyle ? islandRevealProgress : (visible ? 1 : 0)

        let morph = islandStyle ? islandMorphState(for: revealProgress) : IslandMorphState(
            scale: 1,
            scaleX: 1,
            scaleY: 1,
            cornerRatio: 0.5,
            bridgeWidth: 1,
            bridgeOpacity: 0,
            bridgeCurve: 0.58,
            topDrift: 0,
            mirrorOpacity: visible ? 1 : 0,
            islandScaleX: 1,
            islandScaleY: 1,
            islandYOffset: 0,
            islandGlowOpacity: 0,
            islandHighlightOpacity: 0,
            dropletStretch: 0,
            dropletPinch: 0,
            dropletProgress: 0
        )

        let effectiveShape = islandStyle
            ? AnyShape(MirrorMaskShape(style: viewModel.shape, blobPhase: blobPhase))
            : renderShape

        // 灵动岛模式下也复用同一套中心坐标链路（anchor + 用户偏移），
        // 避免镜子、黑色边框和动画缩放中心不一致。
        let staticMirrorTop = mirrorCenterYOffset - (previewFrameHeight / 2)

        // 应用动画偏移
        let animatedYOffset = islandStyle
            ? (staticMirrorTop + morph.topDrift + (previewFrameHeight / 2))
            : mirrorCenterYOffset

        // 显示框的缩放只由动画状态决定，不受焦距影响
        let animatedScale = islandStyle
            ? (displayScale * morph.scale)
            : displayScale
        let animatedScaleX = islandStyle ? morph.scaleX : 1
        let animatedScaleY = islandStyle ? morph.scaleY : 1

        // 镜子的实际 top 位置（用于桥接计算）
        let mirrorTopY = islandStyle
            ? (staticMirrorTop + morph.topDrift)
            : (animatedYOffset - (previewFrameHeight / 2))

        let mirrorOpacity = islandStyle ? morph.mirrorOpacity : revealProgress

        return ZStack {
            switch cameraController.authorizationStatus {
            case .authorized:
                // 镜子窗口 - 从灵动岛内部水滴状弹出
                // 确保相机预览和有效形状完全匹配
                CameraPreviewView(session: cameraController.session)
                    .clipShape(effectiveShape)
                    .overlay {
                        effectiveShape
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(islandStyle ? 0.95 : 1),
                                        Color.black.opacity(islandStyle ? 0.88 : 1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: islandStyle ? (6 + (3 * morph.mirrorOpacity)) : 9
                            )
                    }
                    .frame(width: viewModel.previewSize, height: previewFrameHeight)
                    .scaleEffect(x: animatedScale * animatedScaleX, y: animatedScale * animatedScaleY, anchor: .top)
                    .offset(
                        x: 0,
                        y: animatedYOffset
                    )
                    .opacity(mirrorOpacity)
                    .allowsHitTesting(visible)
                    .gesture(pinchGesture)
                    .animation(.spring(duration: 0.42, bounce: 0.23), value: viewModel.shape)
                    .animation(.spring(duration: 0.32, bounce: 0.2), value: visible)
                    // 增强阴影效果，增加景深感
                    .shadow(color: .black.opacity(0.42), radius: 28, x: 0, y: 14)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                    .compositingGroup()

                if islandStyle, let metrics = islandMetrics {
                    let pillHeight = metrics.height
                    let pillCenterY = (metrics.centerY - (canvasHeight / 2)) + morph.islandYOffset
                    let pillBottomY = pillCenterY + ((pillHeight * morph.islandScaleY) / 2)

                    // 连接层只负责灵动岛与镜子的”融合桥接”，不再重复渲染镜子本体。
                    if morph.bridgeOpacity > 0.01 && revealProgress < 0.62 {
                        islandAdhesionBridge(
                            topY: pillBottomY,
                            bottomY: mirrorTopY,
                            morph: morph,
                            mirrorScale: animatedScale,
                            islandWidth: metrics.width
                        )
                    }

                    simulatedDynamicIsland(
                        metrics: metrics,
                        morph: morph,
                        canvasHeight: canvasHeight
                    )
                    .allowsHitTesting(false)
                }
            case .denied, .restricted:
                permissionCard
            default:
                permissionHint
            }
        }
    }

    private func mirrorAnchorY(islandBottomY: CGFloat?, previewHeight: CGFloat, safeTop: CGFloat, canvasHeight: CGFloat) -> CGFloat {
        // 情况 A：灵动岛机型 - 严格以灵动岛底部为基准
        if let islandBottomY = islandBottomY {
            // 镜子顶部紧贴灵动岛底部，镜子中心 = 灵动岛底部 + (镜子高度 / 2) + 用户调整间距
            return islandBottomY + (previewHeight / 2) + viewModel.lensGap
        }

        // 情况 B：非灵动岛但识别为刘海屏 (如 iPhone 12)
        if supportsDynamicIsland(safeTop: safeTop) {
            return safeTop + (previewHeight / 2) + viewModel.lensGap
        }

        // 情况 C：普通机型或手动模式
        return (canvasHeight * 0.42) + viewModel.mirrorYOffset
    }

    private func supportsDynamicIsland(safeTop: CGFloat) -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone && safeTop >= 51
    }

    private struct DynamicIslandMetrics {
        let centerX: CGFloat
        let centerY: CGFloat
        let width: CGFloat
        let height: CGFloat
        let bottomY: CGFloat
    }

    private struct IslandMorphState {
        let scale: CGFloat
        let scaleX: CGFloat
        let scaleY: CGFloat
        let cornerRatio: CGFloat
        let bridgeWidth: CGFloat
        let bridgeOpacity: CGFloat
        let bridgeCurve: CGFloat
        let topDrift: CGFloat
        let mirrorOpacity: CGFloat
        let islandScaleX: CGFloat
        let islandScaleY: CGFloat
        let islandYOffset: CGFloat
        let islandGlowOpacity: CGFloat
        let islandHighlightOpacity: CGFloat
        // 水滴效果参数
        let dropletStretch: CGFloat // 水滴纵向拉伸
        let dropletPinch: CGFloat // 水滴顶部收缩
        let dropletProgress: CGFloat // 水滴整体进度
    }

    private func dynamicIslandMetrics(topInset: CGFloat, canvasWidth: CGFloat) -> DynamicIslandMetrics {
        // iPhone 14 Pro/15 Pro/16 Pro Dynamic Island 真实物理尺寸
        // 宽度: 126.33 points, 高度: 37.48 points
        // 位置: 距离屏幕顶部约 11.5 points（居中）

        let islandWidth: CGFloat = 126.33
        let islandHeight: CGFloat = 37.48

        // 使用固定的顶部偏移量，确保与真实灵动岛位置匹配
        // 真机测试验证：11.5pt 是大多数设备的准确值
        let topPadding: CGFloat = 11.5

        let centerY = topPadding + (islandHeight / 2)
        let bottomY = centerY + (islandHeight / 2)
        let centerX = canvasWidth / 2

        return DynamicIslandMetrics(
            centerX: centerX,
            centerY: centerY,
            width: islandWidth,
            height: islandHeight,
            bottomY: bottomY
        )
    }

    private func effectiveTopInset(fallback: CGFloat) -> CGFloat {
        max(fallback, currentWindowTopInset())
    }

    private func currentWindowTopInset() -> CGFloat {
        guard
            let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
        else {
            return 0
        }
        return window.safeAreaInsets.top
    }

    private var ambientBackground: some View {
        ZStack {
            if viewModel.useBackgroundImage, let image = viewModel.backgroundImageAsUIImage {
                // 使用背景图片 - 撑满整个屏幕
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .opacity(viewModel.backgroundIntensity)
                }
                .ignoresSafeArea()
            } else {
                // 使用背景颜色 - 上方80%为选中颜色，下方20%渐变为暗色
                LinearGradient(
                    colors: [
                        viewModel.resolvedBackgroundColor.opacity(1 * viewModel.backgroundIntensity),
                        viewModel.resolvedBackgroundColor.opacity(0.8 * viewModel.backgroundIntensity),
                        Color.black.opacity(0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // 保留原有的径向渐变效果，使其更柔和，只在顶部有微弱影响
                RadialGradient(
                    colors: [
                        viewModel.resolvedBackgroundColor.opacity(0.1 * viewModel.backgroundIntensity * viewModel.overlayAlpha),
                        viewModel.resolvedBackgroundColor.opacity(0.05 * viewModel.backgroundIntensity),
                        .clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()
            }
        }
        .blur(radius: 0)
    }

    private var permissionCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("请在系统设置允许相机权限")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Button("打开设置") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.16), in: Capsule())
            .foregroundStyle(.white)
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var permissionHint: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(.white)
            Text("准备相机中…")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("设置")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                Spacer()
            }

            ScrollView(.vertical, showsIndicators: false) {
                settingsPanelContent
                    .padding(.vertical, 2)
            }
            .frame(maxHeight: 250)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            Color.black.opacity(0.84 * viewModel.overlayAlpha),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var settingsPanelContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 暂时隐藏形状设置，默认使用圆形
            // HStack(spacing: 10) {
            //     ForEach(MirrorShapeStyle.allCases) { style in
            //         Button {
            //             withAnimation(.spring(duration: 0.45, bounce: 0.24)) {
            //                 viewModel.shape = style
            //             }
            //         } label: {
            //             Image(systemName: style.symbolName)
            //                 .font(.system(size: 14, weight: .bold))
            //                 .frame(width: 34, height: 34)
            //                 .background(.ultraThinMaterial, in: Circle())
            //                 .overlay {
            //                     if viewModel.shape == style {
            //                         Circle()
            //                             .stroke(.white.opacity(0.92), lineWidth: 1.6)
            //                             .matchedGeometryEffect(id: "shape-ring", in: shapeSelectionNamespace)
            //                     }
            //                 }
            //         }
            //         .buttonStyle(.plain)
            //         .foregroundStyle(.white)
            //     }
            // }

            HStack(spacing: 8) {
                ForEach(MirrorBackgroundStyle.allCases) { style in
                    Button {
                        withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                            viewModel.backgroundStyle = style
                            // 切换到默认颜色时，关闭自定义颜色
                            viewModel.useCustomBackgroundColor = false
                        }
                    } label: {
                        Circle()
                            .fill(style.color)
                            .frame(width: 24, height: 24)
                            .overlay {
                                if viewModel.backgroundStyle == style && !viewModel.useCustomBackgroundColor {
                                    Circle()
                                        .stroke(.white, lineWidth: 1.8)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // 调色盘：选色后自动切换为自定义背景并立即生效
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { viewModel.customBackgroundColor },
                        set: { newColor in
                            viewModel.customBackgroundColor = newColor
                            viewModel.useCustomBackgroundColor = true
                            // 切换到颜色背景
                            viewModel.useBackgroundImage = false
                        }
                    ),
                    supportsOpacity: true
                )
                .opacity(1)
            }

            // 上传背景图片按钮
            if let image = viewModel.backgroundImageAsUIImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        }

                    Button(viewModel.useBackgroundImage ? "切换回背景色" : "使用此图片") {
                        viewModel.useBackgroundImage.toggle()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())

                    Spacer()

                    Button("删除图片") {
                        viewModel.backgroundImage = nil
                        viewModel.backgroundImageAsUIImage = nil
                        viewModel.useBackgroundImage = false
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }

            // 始终显示上传新图片按钮
            PhotosPicker(selection: $viewModel.backgroundImage, matching: .images) {
                Text(viewModel.backgroundImageAsUIImage != nil ? "更换背景图片" : "上传背景图片")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .onChange(of: viewModel.backgroundImage) { newValue in
                if let _ = newValue {
                    viewModel.useBackgroundImage = true
                    viewModel.useCustomBackgroundColor = false
                }
            }

            tuningRow(title: "背景强度", value: valueText(viewModel.backgroundIntensity, digits: 2), range: 0...1.0, binding: $viewModel.backgroundIntensity, step: 0.01)
            tuningRow(title: "屏幕亮度", value: valueText(viewModel.screenBrightness, digits: 2), range: 0.1...1.0, binding: $viewModel.screenBrightness, step: 0.01)
            tuningRow(title: "焦距", value: valueText(viewModel.finalScale, digits: 2), range: 1.0...3.0, binding: Binding(
                get: { viewModel.finalScale },
                set: { newValue in
                    viewModel.persistentScale = newValue
                    viewModel.transientScale = 1
                    cameraController.setZoomLevel(newValue)
                }
            ), step: 0.01)
            tuningRow(title: "尺寸", value: valueText(viewModel.previewSize, digits: 0), range: 250...350, binding: Binding(
                get: { viewModel.previewSize },
                set: { newValue in
                    viewModel.previewSize = max(250, min(350, newValue))
                }
            ), step: 1)
        }
    }

    private var holdToMirrorControls: some View {
        HStack(alignment: .bottom) {
            Button {
                // 添加振动反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                viewModel.settingsPanelVisible.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .stroke(Color.white.opacity(0.26), lineWidth: 1.2)
                    Image(systemName: viewModel.settingsPanelVisible ? "bolt.fill" : "bolt.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)

            Spacer()

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .stroke(Color.white.opacity(0.26), lineWidth: 1.2)
                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 46, height: 46)
                Image(systemName: viewModel.quickMirrorActive ? "camera.viewfinder" : "camera.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)
            .scaleEffect(viewModel.quickMirrorActive ? 1.08 : 1.0)
            .animation(.spring(duration: 0.28, bounce: 0.24), value: viewModel.quickMirrorActive)
            .onTapGesture {
                // 添加振动反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                viewModel.toggleQuickMirror()
            }
        }
    }


    // 移除 imagePicker 变量，直接在 sheet 中使用 PhotosPicker

    private func sliderTile(title: String, value: CGFloat, range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Slider(value: binding(for: title), in: range)
                .tint(.white)
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tuningRow(
        title: String,
        value: String,
        range: ClosedRange<CGFloat>,
        binding: Binding<CGFloat>,
        step: CGFloat
    ) -> some View {
        HStack(spacing: 12) {
            Text("\(title): \(value)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: 132, alignment: .leading)

            Slider(value: binding, in: range, step: step)
                .tint(.blue)
        }
    }

    private func valueText(_ value: CGFloat, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }

    private func binding(for title: String) -> Binding<CGFloat> {
        switch title {
        case "缩放":
            Binding(
                get: { viewModel.finalScale },
                set: { newValue in
                    viewModel.persistentScale = newValue
                    viewModel.transientScale = 1
                }
            )
        case "尺寸":
            Binding(
                get: { viewModel.previewSize },
                set: { newValue in
                    viewModel.previewSize = max(250, min(350, newValue))
                }
            )
        case "背景强度":
            Binding(
                get: { viewModel.backgroundIntensity },
                set: { newValue in
                    viewModel.backgroundIntensity = newValue
                }
            )
        default:
            Binding(
                get: { viewModel.screenBrightness },
                set: { newValue in
                    viewModel.screenBrightness = newValue
                }
            )
        }
    }

    private func mirrorRenderShape(islandStyle: Bool) -> AnyShape {
        if islandStyle {
            return AnyShape(Circle())
        }
        return AnyShape(MirrorMaskShape(style: viewModel.shape, blobPhase: blobPhase))
    }


    private func islandAdhesionBridge(
        topY: CGFloat,
        bottomY: CGFloat,
        morph: IslandMorphState,
        mirrorScale: CGFloat,
        islandWidth: CGFloat
    ) -> some View {
        let gap = max(0, bottomY - topY)
        let bridgeHeight = max(6, gap * 0.98)
        let bridgeWidth = max(18, (42 * mirrorScale * morph.bridgeWidth))
        let bridgeOpacity = morph.bridgeOpacity

        // 灵动岛宽度作为顶部宽度
        let topWidth = max(18, islandWidth * 0.92 * morph.islandScaleX)
        // 底部宽度：从灵动岛平滑过渡到镜子窗口
        let bottomWidth = max(topWidth + 8, bridgeWidth)

        // 使用胶囊形状作为桥接，而不是删除的DropletShape
        let shape = Capsule(style: .continuous)
            .fill(Color.black.opacity(0.92 + (0.06 * morph.dropletProgress)))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12 * bridgeOpacity),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
            }
            .blur(radius: (1 - morph.dropletProgress) * 0.9)

        return shape
            .frame(width: bottomWidth + 16, height: bridgeHeight + 14)
            .scaleEffect(x: 1, y: 0.92 + (0.18 * morph.dropletStretch), anchor: .top)
            .offset(y: topY + (bridgeHeight / 2))
            .opacity(bridgeOpacity)
            .allowsHitTesting(false)
            .compositingGroup()
    }

    private func simulatedDynamicIsland(metrics: DynamicIslandMetrics, morph: IslandMorphState, canvasHeight: CGFloat) -> some View {
        // 模拟灵动岛与真实灵动岛完全重叠
        // 使用真实灵动岛的中心位置
        let realIslandCenterY = metrics.centerY

        // 应用Outline Y偏移，使模拟灵动岛和镜子窗口同步移动
        let adjustedCenterY = realIslandCenterY + viewModel.outlineYOffset + morph.islandYOffset

        // 呼吸灯脉动效果
        let glowPulse = 1 + sin(blobPhase * .pi * 2) * 0.15

        return ZStack {
            // 径向光晕背景 - 增强呼吸灯效果
            RadialGradient(
                colors: [
                    Color(white: 0.85).opacity(0.25 * morph.islandGlowOpacity * glowPulse),
                    Color(white: 0.75).opacity(0.1 * morph.islandGlowOpacity * glowPulse),
                    .clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: metrics.width * 1.4
            )
            .frame(width: metrics.width * 3.5, height: metrics.height * 3.8)
            .blur(radius: 16 * morph.islandGlowOpacity * glowPulse)

            // 外发光层
            RadialGradient(
                colors: [
                    Color.white.opacity(0.08 * morph.islandGlowOpacity),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: metrics.width * 0.8
            )
            .frame(width: metrics.width * 2.5, height: metrics.height * 2.8)
            .blur(radius: 8 * morph.islandGlowOpacity)

            // 主体黑色胶囊 - 模拟灵动岛
            Capsule(style: .continuous)
                .fill(Color.black)
                .frame(width: metrics.width, height: metrics.height)
                .scaleEffect(x: morph.islandScaleX, y: morph.islandScaleY)

                // 内部高光渐变 - 模拟玻璃反光
                .overlay {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22 * morph.islandHighlightOpacity),
                                    Color.white.opacity(0.08 * morph.islandHighlightOpacity),
                                    Color.white.opacity(0.03 * morph.islandHighlightOpacity),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.horizontal, metrics.width * 0.1)
                        .padding(.vertical, metrics.height * 0.12)
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12 * morph.islandHighlightOpacity),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .padding(1)
                }
                .shadow(
                    color: Color.black.opacity(0.45),
                    radius: 4,
                    y: 1
                )
                .shadow(
                    color: Color.white.opacity(0.08 * morph.islandGlowOpacity * glowPulse),
                    radius: 8,
                    y: -2
                )
        }
        .frame(width: metrics.width, height: metrics.height)
        .position(x: metrics.centerX, y: adjustedCenterY)
        .compositingGroup()
    }

    private func animateIslandReveal(visible: Bool) {
        // 缩短时长，让“起滴 -> 拉伸 -> 回弹”更像系统级反馈。
        let animation: Animation = visible
            ? .spring(duration: 0.52, bounce: 0.28, blendDuration: 0.08)
            : .spring(duration: 0.42, bounce: 0.2, blendDuration: 0.04)
        withAnimation(animation) {
            islandRevealProgress = visible ? 1 : 0
        }
    }

    private func islandMorphState(for progress: CGFloat) -> IslandMorphState {
        let p = max(0, min(1, progress))
        // 初始状态：灵动岛保持最小药丸形态
        if p <= 0.0001 {
            return IslandMorphState(
                scale: 0.001,
                scaleX: 0.48,
                scaleY: 0.16,
                cornerRatio: 0.22,
                bridgeWidth: 1.4,
                bridgeOpacity: 0,
                bridgeCurve: 0.92,
                topDrift: 0,
                mirrorOpacity: 0,
                islandScaleX: 1,
                islandScaleY: 1,
                islandYOffset: 0,
                islandGlowOpacity: 0,
                islandHighlightOpacity: 0,
                dropletStretch: 0,
                dropletPinch: 0,
                dropletProgress: 0
            )
        }

        // 阶段1：灵动岛"苏醒"准备释放水滴 (0–0.15)
        let wakeEnd: CGFloat = 0.15

        if p < wakeEnd {
            let t = p / wakeEnd
            let eased = springOutElastic(t)

            return IslandMorphState(
                scale: 0.001,
                scaleX: 0.48 + (0.22 * eased),
                scaleY: 0.16 + (0.12 * eased),
                cornerRatio: 0.22,
                bridgeWidth: 1.44 - (0.06 * eased),
                bridgeOpacity: 0,
                bridgeCurve: 0.92,
                topDrift: 0,
                mirrorOpacity: 0,
                islandScaleX: 1 + (0.4 * eased), // 轻微膨胀
                islandScaleY: 1 + (0.08 * eased),
                islandYOffset: 0,
                islandGlowOpacity: 0.28 * eased,
                islandHighlightOpacity: 0.35 * eased,
                dropletStretch: 0,
                dropletPinch: 0,
                dropletProgress: 0
            )
        }

        // 阶段2：水滴从灵动岛内部形成并向下延伸 (0.15–0.55)
        let dropletEnd: CGFloat = 0.55

        if p < dropletEnd {
            let t = (p - wakeEnd) / (dropletEnd - wakeEnd)
            let eased = smoothStep(t)

            // 水滴拉伸效果：从灵动岛内部向下延伸
            let stretch = eased * 1.2 // 纵向拉伸
            let pinch = sin(t * .pi) * 0.3 // 中间收缩，形成水滴形状

            return IslandMorphState(
                scale: 0.001 + (0.6 * eased), // 镜子开始放大
                scaleX: 0.7 - (0.15 * pinch), // 水滴中间收缩
                scaleY: 0.28 + (stretch * 0.8), // 纵向拉伸
                cornerRatio: 0.22 + (0.2 * eased),
                bridgeWidth: 1.4 - (0.6 * eased),
                bridgeOpacity: 0.52 * eased, // 桥接更克制，避免存在感过强
                bridgeCurve: 0.9 - (0.35 * eased),
                topDrift: 0 + (12 * eased), // 向下延伸
                mirrorOpacity: min(1, (p - wakeEnd) / 0.12),
                islandScaleX: 1.4 - (0.35 * eased), // 灵动岛轻微收缩
                islandScaleY: 1.08 - (0.06 * eased),
                islandYOffset: 0,
                islandGlowOpacity: 0.28 - (0.12 * eased),
                islandHighlightOpacity: 0.35 - (0.15 * eased),
                dropletStretch: stretch,
                dropletPinch: pinch,
                dropletProgress: eased
            )
        }

        // 阶段3：水滴成型并分离 (0.55–0.85)
        let formEnd: CGFloat = 0.85

        if p < formEnd {
            let t = (p - dropletEnd) / (formEnd - dropletEnd)
            let eased = easeOutCubic(t)

            // 水滴继续拉伸并成型
            let stretch = 1.2 - (0.2 * eased) // 稍微回弹
            let pinch = 0.3 * (1 - eased) // 收缩消失

            // Gooey黑框进度：在成型阶段逐渐消失
            let gooeyProgress = 1.0 - eased

            return IslandMorphState(
                scale: 0.6 + (0.42 * eased), // 继续放大
                scaleX: 0.55 + (0.45 * eased), // 恢复正常宽度
                scaleY: 1.08 - (0.1 * eased), // 恢复正常比例
                cornerRatio: 0.42 + (0.08 * eased),
                bridgeWidth: 0.8 - (0.35 * eased),
                bridgeOpacity: 0.4 * (1 - eased), // 在分离阶段迅速收敛
                bridgeCurve: 0.55 - (0.15 * eased),
                topDrift: 12 - (4 * eased), // 轻微回弹
                mirrorOpacity: 1,
                islandScaleX: 1.05 - (0.05 * eased), // 灵动岛恢复
                islandScaleY: 1.02 - (0.02 * eased),
                islandYOffset: 0,
                islandGlowOpacity: 0.16 - (0.1 * eased),
                islandHighlightOpacity: 0.2 - (0.12 * eased),
                dropletStretch: stretch * gooeyProgress,
                dropletPinch: pinch * gooeyProgress,
                dropletProgress: gooeyProgress
            )
        }

        // 阶段4：最终稳定 (0.85–1.0)
        let t = (p - formEnd) / (1 - formEnd)
        let eased = easeInOutCubic(t)
        let settleOscillation = sin(t * .pi * 1.6) * (1 - t) * 0.06

        return IslandMorphState(
            scale: 1 + (settleOscillation * 0.15),
            scaleX: 1 + (settleOscillation * 0.25),
            scaleY: 1 - (settleOscillation * 0.18),
            cornerRatio: 0.5,
            bridgeWidth: 0.45 - (0.15 * eased),
            bridgeOpacity: 0, // 稳态不显示桥接层，去除残留块
            bridgeCurve: 0.4 - (0.05 * eased),
            topDrift: 8 - (6 * eased),
            mirrorOpacity: 1,
            islandScaleX: 1 + (settleOscillation * 0.04),
            islandScaleY: 1 - (settleOscillation * 0.02),
            islandYOffset: 0,
            islandGlowOpacity: 0.06 - (0.04 * eased),
            islandHighlightOpacity: 0.08 - (0.06 * eased),
            dropletStretch: 0,
            dropletPinch: 0,
            dropletProgress: 0
        )
    }

    private func easeOutCubic(_ t: CGFloat) -> CGFloat {
        1 - pow(1 - t, 3)
    }

    private func easeInOutCubic(_ t: CGFloat) -> CGFloat {
        if t < 0.5 {
            return 4 * t * t * t
        }
        return 1 - pow(-2 * t + 2, 3) / 2
    }

    // 弹性缓动函数 - 模拟果冻/气球效果
    private func springOutElastic(_ t: CGFloat) -> CGFloat {
        let c4 = (2 * CGFloat.pi) / 3
        return t == 0 ? 0 : t == 1 ? 1 :
            pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1
    }

    // 平滑缓动函数 - 用于墨水扩散效果
    private func smoothStep(_ t: CGFloat) -> CGFloat {
        let t2 = t * t
        let t3 = t2 * t
        return 3 * t2 - 2 * t3
    }

    private func applyThermalPolicy() {
        let thermalState = ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .serious, .critical:
            cameraController.setPerformanceMode(.constrained)
        default:
            cameraController.setPerformanceMode(.normal)
        }
    }

    private func triggerQuickMirrorIfNeeded() {
        let currentToken = coordinator.lastOpenToken
        guard currentToken != lastAutoRevealToken else { return }

        let hasPendingQuickReveal = coordinator.consumePendingQuickMirrorReveal()
        let source = coordinator.launchSource.lowercased()
        let isControlLaunch = source.contains("intent") || source.contains("control") || source.contains("widget")

        guard hasPendingQuickReveal || isControlLaunch else { return }

        lastAutoRevealToken = currentToken
        viewModel.shape = .circle

        // 增强触发动画：先轻微收缩再弹出，模拟果冻的弹性
        viewModel.setQuickMirrorVisible(true)

        // 添加轻微的脉冲效果，模拟生命感
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4, blendDuration: 0)) {
            viewModel.previewSize = viewModel.previewSize * 0.95
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3, blendDuration: 0)) {
                viewModel.previewSize = viewModel.previewSize * 1.05
            }
        }

        viewModel.triggerFlashOverlay()
    }
}

