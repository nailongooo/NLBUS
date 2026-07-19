import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var announcements: [Announcement] = []
    @State private var recommendedRoutes: [Route] = Route.builtinSamples()
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let announcement = announcements.first {
                    GlassCard {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "megaphone.fill").foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(announcement.title).font(.headline)
                                Text(announcement.content).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("home.quick_actions", comment: ""))
                        .font(.title3.bold())
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        NavigationLink(destination: RouteSearchView()) {
                            quickActionCard(icon: "magnifyingglass", title: NSLocalizedString("home.action.search_route", comment: ""))
                        }
                        NavigationLink(destination: CreateRouteView()) {
                            quickActionCard(icon: "plus.circle.fill", title: NSLocalizedString("home.action.create_route", comment: ""))
                        }
                        NavigationLink(destination: UploadRouteView()) {
                            quickActionCard(icon: "square.and.arrow.up.fill", title: NSLocalizedString("home.action.upload_route", comment: ""))
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("home.recommended", comment: ""))
                        .font(.title3.bold())
                        .padding(.horizontal)

                    ForEach(recommendedRoutes) { route in
                        NavigationLink(destination: RouteDetailView(route: route)) {
                            RouteRowCard(route: route)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(NSLocalizedString("app.name", comment: ""))
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func quickActionCard(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2)
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.primary)
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        if let remoteAnnouncements = try? await APIClient.shared.fetchAnnouncements() {
            announcements = remoteAnnouncements
        }
        if let remoteRoutes = try? await APIClient.shared.fetchPublicRoutes(), !remoteRoutes.isEmpty {
            recommendedRoutes = remoteRoutes
        }
    }
}

struct RouteRowCard: View {
    var route: Route

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: route.iconSystemName)
                    .font(.title2)
                    .foregroundStyle(Color(hex: route.colorHex))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: route.colorHex).opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name).font(.headline)
                    Text(route.direction).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
    }
}
