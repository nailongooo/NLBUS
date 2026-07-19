import SwiftUI

struct ActiveTripView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showEndConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let route = appState.activeRoute {
                    MapContainerView(stops: route.stops)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal)

                    GlassCard {
                        VStack(spacing: 12) {
                            Text(route.name).font(.headline)
                            Text(route.direction).font(.subheadline).foregroundStyle(.secondary)

                            if appState.tripPhase == .waitingForBoarding {
                                statusBlock(
                                    icon: "clock.fill",
                                    title: NSLocalizedString("trip.waiting_title", comment: ""),
                                    subtitle: NSLocalizedString("trip.waiting_subtitle", comment: ""),
                                    color: .blue
                                )
                            } else {
                                stageStatusBlock
                            }
                        }
                    }
                    .padding(.horizontal)

                    if appState.tripMonitor.gpsSignalWeak {
                        Label(NSLocalizedString("trip.gps_weak", comment: ""), systemImage: "location.slash")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    actionButtons
                        .padding(.horizontal)
                } else {
                    Text(NSLocalizedString("trip.no_active_trip", comment: ""))
                        .foregroundStyle(.secondary)
                        .padding(.top, 80)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(NSLocalizedString("trip.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(NSLocalizedString("trip.end_confirm_title", comment: ""), isPresented: $showEndConfirm) {
            Button(NSLocalizedString("trip.end_confirm_action", comment: ""), role: .destructive) {
                appState.endTrip(manually: true)
                dismiss()
            }
            Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
        }
    }

    private var stageStatusBlock: some View {
        let stage = appState.tripMonitor.currentStage
        let distance = appState.tripMonitor.distanceToAlightMeters
        let (icon, color, title): (String, Color, String) = {
            switch stage {
            case .idle: return ("figure.walk", .gray, NSLocalizedString("stage.idle", comment: ""))
            case .preAlert: return ("bell", .blue, NSLocalizedString("stage.pre_alert", comment: ""))
            case .approaching: return ("bell.badge", .orange, NSLocalizedString("stage.approaching", comment: ""))
            case .arrival: return ("bell.and.waves.left.and.right.fill", .red, NSLocalizedString("stage.arrival", comment: ""))
            }
        }()

        return statusBlock(
            icon: icon,
            title: title,
            subtitle: distance.map { String(format: NSLocalizedString("trip.distance_remaining", comment: ""), Int($0)) } ?? NSLocalizedString("trip.locating", comment: ""),
            color: color
        )
    }

    private func statusBlock(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(color)
            Text(title).font(.title3.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            if let eta = appState.tripMonitor.latestETA {
                Text(String(format: NSLocalizedString("trip.eta_format", comment: ""), Int(eta.etaSeconds / 60)))
                    .font(.footnote)
                    .foregroundStyle(eta.source == .crowdsourced ? .green : .secondary)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if appState.tripPhase == .waitingForBoarding {
            VStack(spacing: 10) {
                Button {
                    appState.beginTrip()
                } label: {
                    Label(NSLocalizedString("route_detail.start_trip", comment: ""), systemImage: "location.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    appState.cancelWaiting()
                    dismiss()
                } label: {
                    Text(NSLocalizedString("common.cancel", comment: "")).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        } else {
            Button(role: .destructive) {
                showEndConfirm = true
            } label: {
                Label(NSLocalizedString("trip.end_trip", comment: ""), systemImage: "flag.checkered")
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
