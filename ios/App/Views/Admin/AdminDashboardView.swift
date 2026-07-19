import SwiftUI

struct AdminDashboardView: View {
    @State private var stats: AdminAPIClient.AdminStats?
    @State private var pendingRoutes: [Route] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let stats {
                Section(NSLocalizedString("admin.stats_section", comment: "")) {
                    statRow(NSLocalizedString("admin.stats.total_routes", comment: ""), "\(stats.totalRoutes)")
                    statRow(NSLocalizedString("admin.stats.pending_routes", comment: ""), "\(stats.pendingRoutes)")
                    statRow(NSLocalizedString("admin.stats.total_feedback", comment: ""), "\(stats.totalFeedback)")
                }
            }

            Section(NSLocalizedString("admin.pending_routes_section", comment: "")) {
                if pendingRoutes.isEmpty {
                    Text(NSLocalizedString("admin.no_pending_routes", comment: "")).foregroundStyle(.secondary)
                }
                ForEach(pendingRoutes) { route in
                    NavigationLink(destination: AdminRouteReviewView(route: route, onHandled: { await refresh() })) {
                        VStack(alignment: .leading) {
                            Text(route.name).font(.headline)
                            Text(route.direction).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                NavigationLink(NSLocalizedString("admin.announcement_nav", comment: "")) {
                    AdminAnnouncementView()
                }
                Button(NSLocalizedString("admin.logout", comment: ""), role: .destructive) {
                    AdminAPIClient.shared.logout()
                }
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
        }
        .navigationTitle(NSLocalizedString("admin.dashboard_title", comment: ""))
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary) }
    }

    private func refresh() async {
        do {
            stats = try await AdminAPIClient.shared.fetchStats()
            pendingRoutes = try await AdminAPIClient.shared.fetchPendingRoutes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
