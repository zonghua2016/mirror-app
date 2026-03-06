import SwiftUI

struct ContentView: View {
    @State private var showCamera: Bool = false

    var body: some View {
        ZStack {
            // Background
            Color.black
                .edgesIgnoringSafeArea(.all)

            // Main content
            if showCamera {
                // Camera view with overlay
                CameraView()
                    .overlay {
                        MirrorOverlay()
                    }
            } else {
                // Launch screen
                VStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 64))
                        .padding(.bottom, 20)

                    Text("Tap to start mirror")
                        .foregroundColor(.white)
                        .font(.title2)
                        .fontWeight(.medium)
                        .padding(.bottom, 40)

                    Text("(Double-tap lock button on iPhone 15 Pro+)")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    showCamera.toggle()
                }
            }
        }
        .onAppear {
            // Request camera permission
            let cameraManager = CameraManager()
            cameraManager.requestCameraPermission { granted in
                if granted {
                    showCamera = true
                } else {
                    // Show permission dialog
                    // In a real app, we'd present a proper permission request
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}