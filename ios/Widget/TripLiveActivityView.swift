import ActivityKit
import WidgetKit
import SwiftUI

/// 锁屏 / 灵动岛实时活动的界面。
struct TripLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            // 锁屏样式
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bus.fill")
                        .foregroundStyle(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(distanceText(context.state.distanceMeters))
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.alightStopName)
                        .font(.subheadline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.stageDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "bus.fill")
            } compactTrailing: {
                Text(distanceText(context.state.distanceMeters))
                    .font(.caption2)
            } minimal: {
                Image(systemName: "bus.fill")
            }
        }
    }

    private func distanceText(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TripActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "bus.fill").foregroundStyle(.blue)
                Text(context.attributes.routeName).font(.headline)
                Spacer()
                Text(distanceText(context.state.distanceMeters)).font(.headline)
            }
            Text("\(context.attributes.direction) · \(NSLocalizedString("route_detail.alight", comment: "")): \(context.attributes.alightStopName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(context.state.stageDescription)
                .font(.caption)
                .foregroundStyle(.orange)
            if let eta = context.state.etaSeconds {
                Text(String(format: NSLocalizedString("trip.eta_format", comment: ""), Int(eta / 60)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private func distanceText(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }
}
