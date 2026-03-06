import SwiftUI

/// The overlay that provides the mirror UI with shape selection and gestures
struct MirrorOverlay: View {
    @StateObject private var faceTrackingManager = FaceTrackingManager(
        session: AVCaptureSession(),
        videoPreviewLayer: AVCaptureVideoPreviewLayer(session: AVCaptureSession())
    )

    @State private var shape: ShapeType = .circle
    @State private var scale: CGFloat = 1.0
    @State private var position: CGSize = .zero

    // Gesture state
    @State private var magnification: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            // This is where the camera feed will be displayed
            // In a real implementation, this would be replaced with CameraView
            Color.black.opacity(0.5)
                .overlay {
                    // Shape mask based on selected shape
                    MaskShape(shape: shape, scale: scale, position: position)
                        .foregroundColor(.white)
                        .opacity(0.8)
                }

            // UI Controls
            VStack {
                Spacer()

                // Bottom toolbar with shape selector and controls
                HStack {
                    Button(action: { shape = .circle }) {
                        Label("Circle", systemImage: "circle.fill")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(shape == .circle ? Color.white.opacity(0.9) : Color.black.opacity(0.3))
                            .cornerRadius(8)
                    }

                    Button(action: { shape = .stadium }) {
                        Label("Stadium", systemImage: "rectangle.fill.and.oval.fill")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(shape == .stadium ? Color.white.opacity(0.9) : Color.black.opacity(0.3))
                            .cornerRadius(8)
                    }

                    Button(action: { shape = .custom }) {
                        Label("Custom", systemImage: "pencil.and.ellipse")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(shape == .custom ? Color.white.opacity(0.9) : Color.black.opacity(0.3))
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 20)
            }

            // Top bar with status
            HStack {
                Text("Lock Screen Mirror")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.leading)

                Spacer()

                if faceTrackingManager.faceTrackingActive {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                        Text("Tracking")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                    .padding(.trailing)
                }
            }
            .padding(.top, 20)
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    magnification = value
                    scale = max(0.5, min(2.0, value))
                }
                .onEnded { _ in
                    // Apply final scale with spring animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        scale = magnification
                    }
                }
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    position = CGSize(width: dragOffset.width / 100, height: dragOffset.height / 100)
                }
                .onEnded { value in
                    // Apply final position with spring animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        position = CGSize(width: dragOffset.width / 100, height: dragOffset.height / 100)
                    }
                }
        )
    }
}

/// Enum for shape types
enum ShapeType: String, CaseIterable {
    case circle
    case stadium
    case custom
}

/// A custom shape that can be circular, stadium-shaped, or custom
struct MaskShape: Shape {
    let shape: ShapeType
    let scale: CGFloat
    let position: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Calculate the size based on scale
        let size = CGSize(
            width: rect.width * scale * 0.8,
            height: rect.height * scale * 0.8
        )

        // Calculate the center position
        let center = CGPoint(
            x: rect.midX + position.width,
            y: rect.midY + position.height
        )

        switch shape {
        case .circle:
            let radius = min(size.width, size.height) / 2
            path.addArc(center: center, radius: radius, startAngle: .zero, endAngle: .twoPi, clockwise: true)

        case .stadium:
            let halfWidth = size.width / 2
            let halfHeight = size.height / 2

            // Create a stadium shape (rectangle with semicircles on each end)
            path.addArc(center: CGPoint(x: center.x - halfWidth, y: center.y), radius: halfHeight, startAngle: .pi / 2, endAngle: 3 * .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y - halfHeight))
            path.addArc(center: CGPoint(x: center.x + halfWidth, y: center.y), radius: halfHeight, startAngle: 3 * .pi / 2, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: center.x - halfWidth, y: center.y + halfHeight))

        case .custom:
            // For custom shape, we could implement a more complex shape
            // For now, use a rounded rectangle
            path.addRoundedRect(in: CGRect(x: center.x - size.width/2, y: center.y - size.height/2, width: size.width, height: size.height), cornerRadius: 20)
        }

        return path
    }
}

// MARK: - Preview
struct MirrorOverlay_Previews: PreviewProvider {
    static var previews: some View {
        MirrorOverlay()
            .previewLayout(.sizeThatFits)
    }
}