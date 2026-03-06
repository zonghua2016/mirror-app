# 锁屏镜像

[中文文档](README_zh.md) | [English](README.md)

原生 iOS 应用（SwiftUI + AVFoundation + Vision），提供锁屏和系统入口的快速镜像预览功能。

![capture](https://p0.ssl.qhimg.com/t110b9a93010769bef6351f614f.png)

## 已实现功能

- 前置摄像头镜像预览，支持平滑拖拽和缩放
- 动态遮罩形状（圆形、药丸形、不规则形），使用弹簧动画
- 按住预览交互：按住右下角摄像头按钮显示镜像气泡，松开后隐藏
- Vision 框架的人脸检测，带平滑自动居中功能
- UltraThinMaterial 工具栏和模拟屏幕闪光效果
- 锁屏小部件深度链接（`lockscreenmirror://open?source=widget`）
- iOS 18 锁屏摄像头捕获扩展（从锁屏摄像头控件启动安全捕获 UI）
- 控制中心小部件（iOS 18+），用于锁屏摄像头插槽（`CameraCaptureIntent`）
- Live Activity + 动态岛视觉状态同步（形状 + 可见状态）
- 应用快捷指令（可通过快捷指令绑定到操作按钮）
- 热管理性能模式切换（30fps 正常模式 / 24fps 限制模式）

## AI生成代码声明

⚠️ **本项目包含AI生成的代码，禁止商业用途。**

本代码库包含使用人工智能工具（Claude、ChatGPT、GitHub Copilot等）生成的代码组件。代码仅用于：
- 教育目的
- 个人学习和实验
- 非商业研究

**商业用途严格禁止**。完整条款请参见 [LICENSE](LICENSE) 文件。

## 项目结构

- Xcode 项目：`ios/LockScreenMirror.xcodeproj`
- 主应用目标：`LockScreenMirror`
- 小部件扩展目标：`LockScreenMirrorWidgetsExtension`
- 锁屏捕获扩展目标：`LockScreenMirrorCaptureExtension`

## 系统要求

- Xcode 17+
- iOS 17+（控制中心小部件需要 iOS 18+）
- Apple 开发者签名（用于真机安装）

## 重要说明

- 这是一个原生项目。**不要运行 `pod install`**。
- 不需要 React Native/Metro 运行时。

## 在 Xcode 中运行（真机）

1. 打开 `ios/LockScreenMirror.xcodeproj`
2. 选择 `LockScreenMirror` 目标，在 **Signing & Capabilities** 中设置您的团队
3. 确保使用唯一的 Bundle Identifier：
   - 应用：`com.mirrorapp.lockscreenmirror`
   - 小部件：`com.mirrorapp.lockscreenmirror.widgets`
4. 连接 iPhone，选择您的设备作为运行目标
5. 构建并运行（`Cmd + R`）
6. 首次启动时授予相机权限

## 在设备上验证功能

1. **应用内镜像**
   - 检查前置摄像头预览是否立即出现
   - 测试拖拽、缩放、形状切换和闪光覆盖效果
   - 按住右下角摄像头按钮，验证镜像气泡是否出现在动态岛附近（非动态岛设备在屏幕中央），松开后消失

2. **锁屏小部件**
   - 在锁屏界面添加 `锁屏镜像` 小部件
   - 点击小部件，确认应用打开至镜像页面

3. **锁屏摄像头控件（iOS 18+）**
   - 长按锁屏，点击 `自定义` → `锁屏`
   - 将右下角摄像头插槽替换为本应用的 `镜像捕获` 控件
   - 锁定设备并按住该右下角控件
   - 验证安全捕获 UI 是否打开，镜像立即显示在动态岛下方（非动态岛设备在中央位置），且无需打开主应用

4. **解锁状态 + 通知中心路径（iOS 18+）**
   - 保持设备解锁，下滑显示通知中心（锁屏样式界面）
   - 长按右下角摄像头控件
   - 验证捕获扩展是否打开
   - 在扩展中，按住右下角摄像头按钮并向左拖动，显示圆形镜像（动态岛下方），非动态岛设备在上部中央位置，松开后隐藏

5. **动态岛 + Live Activity（iOS 16.1+）**
   - 在应用中按住摄像头按钮显示镜像气泡
   - 确认 Live Activity 状态在锁屏/动态岛上更新（形状和可见状态）

6. **操作按钮（iPhone 15 Pro+）**
   - 创建/使用本应用的 `打开镜像` 快捷指令
   - 在设置中将该快捷指令绑定到操作按钮
   - 按下操作按钮，确认应用打开至镜像页面

## 已知平台限制

- 第三方应用无法拦截或覆盖苹果相机私有锁屏渲染管道
- Live Activity/动态岛无法托管来自应用进程的完整 30fps 摄像头流；真实预览通过锁定的摄像头捕获场景提供
- 锁屏入口使用 iOS 18 公共 API 实现：`LockedCameraCaptureExtension` + `CameraCaptureIntent`
- 系统根据当前上下文（锁屏/主屏幕）决定启动主应用还是捕获扩展；此行为无法通过应用代码覆盖

## 排障（长按无响应）

1. 确保在锁屏右下角控件中选择了 **镜像捕获**（而非系统相机）
2. 清理后重新安装：
   - `产品 -> 清理构建文件夹`
   - 从设备删除应用
   - 从 Xcode 重新运行
3. 保持权限文件最小化（不要手动添加锁定摄像头权限键）
4. 如果您的团队配置不支持某项功能，请移除该功能并重新生成配置文件
5. iPhone 12 没有动态岛。预期行为是在上部中央位置显示圆形镜像

## 与英文文档互连

- [English README](README.md)
- [中文 README](README_zh.md)
