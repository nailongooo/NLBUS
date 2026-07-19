import SwiftUI

struct RouteDetailView: View {
    var route: Route

    @EnvironmentObject var appState: AppState
    @StateObject private var favoritesStore = FavoritesStore.shared

    @State private var boardStop: Stop?
    @State private var alightStop: Stop?
    @State private var liveVehicles: [LiveVehicle] = []
    @State private var showingReportSheet = false
    @State private var reportReason = ""
    @State private var refreshTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MapContainerView(
                    stops: route.stops,
                    liveVehicles: liveVehicles,
                    highlightedStopIds: Set([boardStop?.id, alightStop?.id].compactMap { $0 })
                ) { stop in
                    handleStopTap(stop)
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(route.name).font(.title2.bold())
                                Text(route.direction).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                favoritesStore.toggle(route)
                            } label: {
                                Image(systemName: favoritesStore.isFavorite(route.id) ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .font(.title3)
                            }
                        }

                        if let summary = route.summary, !summary.isEmpty {
                            Text(summary).font(.footnote).foregroundStyle(.secondary)
                        }

                        Divider()

                        infoRow(icon: "yensign.circle", text: route.fareDescription ?? NSLocalizedString("route_detail.no_fare_info", comment: ""))
                        infoRow(icon: "clock", text: firstLastBusText)
                        if let headway = route.headwayMinutes {
                            infoRow(icon: "timer", text: String(format: NSLocalizedString("route_detail.headway", comment: ""), headway))
                        }
                        if let company = route.operatorCompany {
                            infoRow(icon: "building.2", text: company)
                        }
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("route_detail.pick_stops_hint", comment: ""))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ForEach(route.stops.sorted(by: { $0.order < $1.order })) { stop in
                        Button {
                            handleStopTap(stop)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(colorFor(stop))
                                    .frame(width: 10, height: 10)
                                Text(stop.name)
                                Spacer()
                                if boardStop?.id == stop.id {
                                    Text(NSLocalizedString("route_detail.board", comment: "")).font(.caption).foregroundStyle(.green)
                                }
                                if alightStop?.id == stop.id {
                                    Text(NSLocalizedString("route_detail.alight", comment: "")).font(.caption).foregroundStyle(.orange)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal)
                        }
                        .foregroundStyle(.primary)
                    }
                }

                actionButtons
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
        .navigationTitle(NSLocalizedString("route_detail.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingReportSheet = true
                } label: {
                    Image(systemName: "flag")
                }
            }
        }
        .sheet(isPresented: $showingReportSheet) {
            reportSheet
        }
        .onAppear { startLiveVehiclePolling() }
        .onDisappear { refreshTimer?.invalidate() }
    }

    private var firstLastBusText: String {
        let first = route.firstBusTime ?? "--"
        let last = route.lastBusTime ?? "--"
        return "\(first) ~ \(last)"
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
            Text(text).font(.footnote)
        }
    }

    private func colorFor(_ stop: Stop) -> Color {
        if boardStop?.id == stop.id { return .green }
        if alightStop?.id == stop.id { return .orange }
        return .blue
    }

    private func handleStopTap(_ stop: Stop) {
        if boardStop == nil {
            boardStop = stop
        } else if alightStop == nil && stop.order > (boardStop?.order ?? -1) {
            alightStop = stop
        } else {
            // 重新选择：把点击的站点当作新的上车站，下车站清空重选
            boardStop = stop
            alightStop = nil
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let board = boardStop, let alight = alightStop {
            VStack(spacing: 10) {
                Button {
                    appState.selectRoute(route, board: board, alight: alight)
                } label: {
                    Label(NSLocalizedString("route_detail.remind_boarding", comment: ""), systemImage: "bell.badge")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button {
                    appState.selectRoute(route, board: board, alight: alight)
                    appState.beginTrip()
                } label: {
                    Label(NSLocalizedString("route_detail.start_trip", comment: ""), systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            Text(NSLocalizedString("route_detail.pick_stops_placeholder", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var reportSheet: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("report.reason_section", comment: "")) {
                    TextEditor(text: $reportReason).frame(height: 120)
                }
            }
            .navigationTitle(NSLocalizedString("report.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { showingReportSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("common.submit", comment: "")) {
                        Task {
                            try? await APIClient.shared.reportRoute(id: route.id, reason: reportReason)
                            showingReportSheet = false
                        }
                    }
                }
            }
        }
    }

    private func startLiveVehiclePolling() {
        Task { await refreshLiveVehicles() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
            Task { await refreshLiveVehicles() }
        }
    }

    private func refreshLiveVehicles() async {
        if let vehicles = try? await APIClient.shared.fetchLiveVehicles(routeId: route.id) {
            liveVehicles = vehicles
        }
    }
}
