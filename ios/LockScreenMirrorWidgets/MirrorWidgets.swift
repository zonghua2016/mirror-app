import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private enum MirrorDeepLink {
    static let lockScreenURL = URL(string: "lockscreenmirror://open?source=widget&quick=1")!
}

private struct MirrorEntry: TimelineEntry {
    let date: Date
}

private struct MirrorProvider: TimelineProvider {
    func placeholder(in context: Context) -> MirrorEntry { MirrorEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (MirrorEntry) -> Void) {
        completion(MirrorEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MirrorEntry>) -> Void) {
        completion(Timeline(entries: [MirrorEntry(date: .now)], policy: .after(.now.addingTimeInterval(900))))
    }
}

private struct MirrorWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "camera.fill")
                .font(.system(size: 20, weight: .bold))
            Text("Open Mirror")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .widgetURL(MirrorDeepLink.lockScreenURL)
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

struct MirrorLockScreenWidget: Widget {
    let kind = "MirrorLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MirrorProvider()) { _ in
            MirrorWidgetView()
        }
        .configurationDisplayName("Lock Screen Mirror")
        .description("Quickly open the mirror camera")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

@available(iOS 18.0, *)
private struct MirrorCaptureControlWidget: ControlWidget {
    let kind = "MirrorCaptureControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: StartMirrorCaptureIntent()) {
                Label("Mirror", systemImage: "camera.viewfinder")
            }
        }
        .displayName("Mirror Capture")
        .description("Use as lock screen camera control")
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct MirrorLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MirrorActivityAttributes.self) { context in
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)

                activityShape(for: context.state.shapeRawValue)
                    .fill(Color.white.opacity(0.18))
                    .overlay {
                        activityShape(for: context.state.shapeRawValue)
                            .stroke(Color.white.opacity(0.95), lineWidth: 2)
                    }
                    .padding(14)

                Image(systemName: context.state.isPreviewVisible ? "camera.viewfinder" : "camera.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(10)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    activityShape(for: context.state.shapeRawValue)
                        .fill(Color.white.opacity(0.12))
                        .overlay {
                            activityShape(for: context.state.shapeRawValue)
                                .stroke(Color.white.opacity(0.9), lineWidth: 1.6)
                        }
                        .frame(width: 120, height: 120)
                        .overlay {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
            } compactLeading: {
                Image(systemName: "camera.viewfinder")
            } compactTrailing: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 9, height: 9)
            } minimal: {
                Image(systemName: "camera.fill")
            }
            .widgetURL(MirrorDeepLink.lockScreenURL)
            .keylineTint(.white)
        }
    }

    private func activityShape(for rawValue: String) -> AnyShape {
        let style = MirrorShapeStyle(rawValue: rawValue) ?? .circle
        switch style {
        case .circle:
            return AnyShape(Circle())
        case .stadium:
            return AnyShape(Capsule(style: .continuous))
        case .blob:
            return AnyShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
    }
}

@main
struct MirrorWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        MirrorLockScreenWidget()

        if #available(iOSApplicationExtension 16.1, *) {
            MirrorLiveActivityWidget()
        }

        if #available(iOSApplicationExtension 18.0, *) {
            MirrorCaptureControlWidget()
        }
    }
}
