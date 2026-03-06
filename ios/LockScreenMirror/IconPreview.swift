import SwiftUI

// InstaMirror App 图标预览和生成器
struct InstaMirrorIconView: View {
    var body: some View {
        ZStack {
            // 背景渐变 - 从深色到深灰色
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.12),
                    Color(red: 0.22, green: 0.24, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 主体：简洁优雅的镜子图标
            VStack(spacing: -5) {
                // 椭圆形镜框
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white)
                    .frame(width: 88, height: 110)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.black.opacity(0.15), lineWidth: 3)
                    )
                    .overlay(
                        // 镜面反光效果
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        // 中央圆（代表镜头）
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.3), Color.black.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 32, height: 32)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 8)
            }
            .padding(.all, 30)

            // 闪光点 - 营造高端感
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 12, height: 12)
                .blur(radius: 2)
                .offset(x: -35, y: -32)

            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 8, height: 8)
                .blur(radius: 1.5)
                .offset(x: 28, y: -28)

            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 16, height: 16)
                .blur(radius: 3)
                .offset(x: 30, y: 38)
        }
        .frame(width: 1024, height: 1024)
        .cornerRadius(180)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// 图标预览工具（用于开发阶段预览）
struct IconPreviewTool: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("InstaMirror App 图标预览")
                .font(.title2)
                .fontWeight(.bold)

            // 主要图标预览
            InstaMirrorIconView()
                .frame(width: 180, height: 180)
                .shadow(radius: 10)
                .padding()

            // 不同尺寸预览
            HStack(spacing: 15) {
                VStack {
                    InstaMirrorIconView()
                        .frame(width: 60, height: 60)
                    Text("60x60")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    InstaMirrorIconView()
                        .frame(width: 87, height: 87)
                    Text("87x87")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    InstaMirrorIconView()
                        .frame(width: 180, height: 180)
                    Text("180x180")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 说明
            VStack(alignment: .leading, spacing: 8) {
                Text("如何使用此图标：")
                    .font(.headline)

                Text("1. 在 Xcode 中打开项目")
                    .font(.body)

                Text("2. 点击 Assets.xcassets → AppIcon.appiconset")
                    .font(.body)

                Text("3. 点击 'Show in Finder'")
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .navigationTitle("图标预览")
    }
}

#Preview {
    IconPreviewTool()
        .frame(width: 400, height: 700)
}
