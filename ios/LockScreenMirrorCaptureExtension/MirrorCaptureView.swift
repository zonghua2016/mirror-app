import AVFoundation
import LockedCameraCapture
import SwiftUI

struct MirrorCaptureView: View {
    let session: LockedCameraCaptureSession

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var cameraController = CameraSessionController()
    @State private var blobPhase: CGFloat = 0
    @State private var revealProgress: CGFloat = 0
    @State private var nonIslandShowing = false

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
    }

    private struct IslandFusionBridgeShape: Shape {
        var topWidth: CGFloat
        var bottomWidth: CGFloat
        var curvature: CGFloat

        func path(in rect: CGRect) -> Path {
            let safeTopWidth = max(2, min(rect.width, topWidth))
            let safeBottomWidth = max(safeTopWidth, min(rect.width, bottomWidth))
            let c = max(0, min(1, curvature))

            let midX = rect.midX
            let topY = rect.minY
            let bottomY = rect.maxY

            let topLeft = CGPoint(x: midX - (safeTopWidth / 2), y: topY)
            let topRight = CGPoint(x: midX + (safeTopWidth / 2), y: topY)
            let bottomLeft = CGPoint(x: midX - (safeBottomWidth / 2), y: bottomY)
            let bottomRight = CGPoint(x: midX + (safeBottomWidth / 2), y: bottomY)

            let controlYOffset = rect.height * (0.24 + (0.22 * c))
            let controlXInset = (safeBottomWidth - safeTopWidth) * (0.42 + (0.25 * c))

            var path = Path()
            path.move(to: topLeft)
            path.addQuadCurve(
                to: bottomLeft,
                control: CGPoint(x: topLeft.x - controlXInset, y: topY + controlYOffset)
            )
            path.addLine(to: bottomRight)
            path.addQuadCurve(
                to: topRight,
                control: CGPoint(x: topRight.x + controlXInset, y: topY + controlYOffset)
            )
            path.closeSubpath()
            return path
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            if supportsDynamicIsland(safeTop: safeTop) {
                dynamicIslandLayout(proxy: proxy, safeTop: safeTop)
            } else {
                nonIslandFloatingLayout(proxy: proxy)
            }
        }
        .task {
            _ = session
            let granted = await cameraController.requestPermissionIfNeeded()
            guard granted else { return }

            cameraController.configureSession()
            cameraController.startRunning()
            animateReveal(to: true)
            withAnimation(.spring(response: 0.52, dampingFraction: 0.82, blendDuration: 0)) {
                nonIslandShowing = true
            }

            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                blobPhase = 1
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                cameraController.startRunning()
                if cameraController.authorizationStatus == .authorized {
                    animateReveal(to: true)
                }
                if cameraController.authorizationStatus == .authorized {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.84, blendDuration: 0)) {
                        nonIslandShowing = true
                    }
                }
            default:
                cameraController.stopRunning()
                animateReveal(to: false)
                nonIslandShowing = false
            }
        }
        .onChange(of: cameraController.authorizationStatus) { _, status in
            if status == .authorized {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.84, blendDuration: 0)) {
                    nonIslandShowing = true
                }
            } else {
                nonIslandShowing = false
            }
        }
        .onDisappear {
            animateReveal(to: false)
            nonIslandShowing = false
            cameraController.stopRunning()
        }
    }

    @ViewBuilder
    private func dynamicIslandLayout(proxy: GeometryProxy, safeTop: CGFloat) -> some View {
        let previewDiameter: CGFloat = 226
        let islandMetrics = dynamicIslandMetrics(topInset: safeTop, canvasWidth: proxy.size.width)
        let reveal = max(0, min(1, revealProgress))
        let morph = islandMorphState(for: reveal)
        let mirrorScale = morph.scale
        let mirrorScaleX = morph.scaleX
        let mirrorScaleY = morph.scaleY
        let islandMask = RoundedRectangle(
            cornerRadius: max(18, previewDiameter * morph.cornerRatio),
            style: .continuous
        )
        let pillCenterY = (islandMetrics.centerY - (proxy.size.height / 2)) + morph.islandYOffset
        let staticMirrorTop = (islandMetrics.bottomY - (proxy.size.height / 2)) + morph.islandYOffset
        let mirrorYOffset = staticMirrorTop + morph.topDrift + (previewDiameter / 2)
        let pillRenderHeight = islandMetrics.height
        let mirrorTopY = staticMirrorTop + morph.topDrift
        let pillBottomY = pillCenterY + ((pillRenderHeight * morph.islandScaleY) / 2)

        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.62), Color.black.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if cameraController.authorizationStatus == .authorized {
                CameraPreviewView(session: cameraController.session)
                    .clipShape(islandMask)
                    .overlay {
                        islandMask
                            .stroke(.black, lineWidth: 6 + (3 * morph.mirrorOpacity))
                    }
                    .frame(width: previewDiameter, height: previewDiameter)
                    .offset(x: 0, y: mirrorYOffset)
                    .scaleEffect(x: mirrorScale * mirrorScaleX, y: mirrorScale * mirrorScaleY, anchor: .top)
                    .opacity(morph.mirrorOpacity)
                    .shadow(color: .black.opacity(0.42), radius: 28, y: 14)
                    .compositingGroup()

                if reveal > 0.01 || morph.bridgeOpacity > 0.01 {
                    islandAdhesionBridge(
                        topY: pillBottomY,
                        bottomY: mirrorTopY,
                        morph: morph,
                        mirrorScale: mirrorScale,
                        islandWidth: islandMetrics.width
                    )
                    .allowsHitTesting(false)
                }

                simulatedDynamicIsland(
                    metrics: islandMetrics,
                    morph: morph,
                    canvasHeight: proxy.size.height
                )
                .allowsHitTesting(false)
            } else {
                permissionCard
            }

            VStack {
                Spacer()

                HStack(alignment: .bottom) {
                    Text(revealProgress > 0.5 ? "点击右下角隐藏镜子" : "点击右下角显示镜子")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        Circle()
                            .stroke(Color.white.opacity(0.26), lineWidth: 1.2)
                        Circle()
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 46, height: 46)
                        Image(systemName: revealProgress > 0.2 ? "camera.viewfinder" : "camera.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 78, height: 78)
                    .scaleEffect(revealProgress > 0.02 ? 1.06 : 1.0)
                    .animation(.spring(duration: 0.22, bounce: 0.2), value: revealProgress)
                    .onTapGesture {
                        animateReveal(to: revealProgress <= 0.5)
                    }
                }
            }
            .padding(.top, max(14, safeTop))
            .padding(.horizontal, 16)
            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 14))
        }
    }

    @ViewBuilder
    private func nonIslandFloatingLayout(proxy: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(nonIslandShowing ? 0.7 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.28), value: nonIslandShowing)

            VStack(spacing: 0) {
                Spacer()

                if cameraController.authorizationStatus == .authorized {
                    if nonIslandShowing {
                        ZStack {
                            CameraPreviewView(session: cameraController.session)
                                .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
                                .frame(width: min(300, proxy.size.width - 40), height: min(400, proxy.size.height * 0.52))
                                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

                            VStack {
                                Capsule()
                                    .fill(Color.white.opacity(0.42))
                                    .frame(width: 40, height: 5)
                                    .padding(.top, 12)
                                Spacer()
                            }
                        }
                        .transition(
                            .move(edge: .bottom)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.8, anchor: .center))
                        )
                    }
                } else {
                    permissionCard
                        .padding(.horizontal, 20)
                }

                Spacer()

                HStack {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.84, blendDuration: 0)) {
                            nonIslandShowing.toggle()
                        }
                    } label: {
                        Image(systemName: nonIslandShowing ? "eye.slash.fill" : "camera.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .padding(14)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .foregroundStyle(.white)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 24))
                .transition(.opacity)
            }
            .padding(.horizontal, 20)
        }
    }

    private struct DynamicIslandMetrics {
        let centerY: CGFloat
        let width: CGFloat
        let height: CGFloat
        let bottomY: CGFloat
    }

    private func dynamicIslandMetrics(topInset: CGFloat, canvasWidth: CGFloat) -> DynamicIslandMetrics {
        let _ = canvasWidth
        let islandWidth: CGFloat = 126
        let islandHeight: CGFloat = 37
        let topPadding = max(6, min(11, (topInset * 0.16) + 0.5))
        let centerY = topPadding + (islandHeight / 2)
        return DynamicIslandMetrics(
            centerY: centerY,
            width: islandWidth,
            height: islandHeight,
            bottomY: centerY + (islandHeight / 2)
        )
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
        let bridgeWidth = max(18, (38 * mirrorScale * morph.bridgeWidth))
        let bridgeOpacity = morph.bridgeOpacity
        let topWidth = max(18, islandWidth * 0.88 * morph.islandScaleX)
        let bottomWidth = max(topWidth + 6, bridgeWidth)
        let shape = IslandFusionBridgeShape(topWidth: topWidth, bottomWidth: bottomWidth, curvature: morph.bridgeCurve)

        return ZStack {
            CameraPreviewView(session: cameraController.session)
                .frame(width: bottomWidth + 12, height: bridgeHeight + 10)
                .clipShape(shape)
                .opacity(0.34 * bridgeOpacity)

            shape
                .fill(Color.black.opacity(0.9))
        }
        .frame(width: bottomWidth + 12, height: bridgeHeight + 10)
            .offset(y: topY + (bridgeHeight / 2))
            .opacity(bridgeOpacity)
            .allowsHitTesting(false)
    }

    private func simulatedDynamicIsland(metrics: DynamicIslandMetrics, morph: IslandMorphState, canvasHeight: CGFloat) -> some View {
        let centerY = (metrics.centerY - (canvasHeight / 2)) + morph.islandYOffset
        return ZStack {
            RadialGradient(
                colors: [
                    Color.white.opacity(0.22 * morph.islandGlowOpacity),
                    Color.white.opacity(0.06 * morph.islandGlowOpacity),
                    .clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: metrics.width * 1.2
            )
            .frame(width: metrics.width * 3.0, height: metrics.height * 3.2)
            .blur(radius: 12 * morph.islandGlowOpacity)

            Capsule(style: .continuous)
                .fill(Color.black)
                .frame(width: metrics.width, height: metrics.height)
                .scaleEffect(x: morph.islandScaleX, y: morph.islandScaleY)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18 * morph.islandHighlightOpacity),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(.horizontal, metrics.width * 0.08)
                        .padding(.vertical, metrics.height * 0.08)
                }
                .shadow(color: Color.white.opacity(0.07 * morph.islandGlowOpacity), radius: 7, y: -1)
        }
        .offset(y: centerY)
    }

    private func animateReveal(to visible: Bool) {
        withAnimation(.linear(duration: 0.52)) {
            revealProgress = visible ? 1 : 0
        }
    }

    private func islandMorphState(for progress: CGFloat) -> IslandMorphState {
        let p = max(0, min(1, progress))
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
                islandHighlightOpacity: 0
            )
        }

        let wakeEnd: CGFloat = 0.14
        let growEnd: CGFloat = 0.72

        if p < wakeEnd {
            let t = p / wakeEnd
            let eased = easeOutCubic(t)
            return IslandMorphState(
                scale: 0.001,
                scaleX: 0.48 + (0.14 * eased),
                scaleY: 0.16 + (0.08 * eased),
                cornerRatio: 0.22,
                bridgeWidth: 1.44 - (0.04 * eased),
                bridgeOpacity: 0,
                bridgeCurve: 0.92,
                topDrift: 0,
                mirrorOpacity: 0,
                islandScaleX: 1 + (1.22 * eased),
                islandScaleY: 1 + (0.08 * eased),
                islandYOffset: 0.35 * eased,
                islandGlowOpacity: 0.14 * eased,
                islandHighlightOpacity: 0.22 * eased
            )
        }

        if p < growEnd {
            let t = (p - wakeEnd) / (growEnd - wakeEnd)
            let eased = easeOutCubic(t)
            return IslandMorphState(
                scale: 0.07 + (1.02 * eased),
                scaleX: 1.85 - (0.82 * eased),
                scaleY: 0.22 + (0.9 * eased),
                cornerRatio: 0.22 + (0.28 * eased),
                bridgeWidth: 1.4 - (0.7 * eased),
                bridgeOpacity: 0.94 - (0.5 * eased),
                bridgeCurve: 0.9 - (0.42 * eased),
                topDrift: 0.8 + (5.2 * (1 - eased)),
                mirrorOpacity: min(1, (p - wakeEnd) / 0.06),
                islandScaleX: 2.22 - (1.2 * eased),
                islandScaleY: 1.08 - (0.06 * eased),
                islandYOffset: 0.35 - (0.25 * eased),
                islandGlowOpacity: 0.14 - (0.09 * eased),
                islandHighlightOpacity: 0.22 - (0.14 * eased)
            )
        }

        let t = (p - growEnd) / (1 - growEnd)
        let eased = easeInOutCubic(t)
        let settleOscillation = sin(t * .pi * 1.32) * (1 - t) * 0.06
        return IslandMorphState(
            scale: 1 + (settleOscillation * 0.22),
            scaleX: 1 + (settleOscillation * 0.38),
            scaleY: 1 - (settleOscillation * 0.28),
            cornerRatio: 0.5,
            bridgeWidth: 0.7 - (0.2 * eased),
            bridgeOpacity: 0.44 - (0.28 * eased),
            bridgeCurve: 0.48 - (0.06 * eased),
            topDrift: 0.4 * (1 - eased),
            mirrorOpacity: 1,
            islandScaleX: 1 + (settleOscillation * 0.05),
            islandScaleY: 1 - (settleOscillation * 0.03),
            islandYOffset: 0.1 * (1 - eased),
            islandGlowOpacity: 0.05 - (0.04 * eased),
            islandHighlightOpacity: 0.08 - (0.06 * eased)
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

    private var permissionCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.system(size: 26, weight: .bold))
            Text("相机权限未授权")
                .font(.system(.callout, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func supportsDynamicIsland(safeTop: CGFloat) -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone && safeTop >= 51
    }
}
