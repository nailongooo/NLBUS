import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingActiveTrip = false

    var body: some View {
        ZStack {
            TabView {
                NavigationStack { HomeView() }
                    .tabItem { Label(NSLocalizedString("tab.home", comment: ""), systemImage: "house.fill") }

                NavigationStack { RouteSearchView() }
                    .tabItem { Label(NSLocalizedString("tab.search", comment: ""), systemImage: "magnifyingglass") }

                NavigationStack { FavoritesView() }
                    .tabItem { Label(NSLocalizedString("tab.favorites", comment: ""), systemImage: "star.fill") }

                NavigationStack { ProfileView() }
                    .tabItem { Label(NSLocalizedString("tab.profile", comment: ""), systemImage: "person.crop.circle") }
            }

            // 行程一旦进入"等车"或"进行中"，就用一个悬浮入口随时可以回到行程页面
            if appState.tripPhase == .active || appState.tripPhase == .waitingForBoarding {
                VStack {
                    Spacer()
                    Button {
                        showingActiveTrip = true
                    } label: {
                        HStack {
                            Image(systemName: appState.tripPhase == .active ? "location.fill" : "clock.fill")
                            Text(appState.tripPhase == .active ? NSLocalizedString("root.trip_in_progress", comment: "") : NSLocalizedString("root.waiting_for_bus", comment: ""))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(hex: appState.accentColorHex))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal)
                        .padding(.bottom, 60)
                        .shadow(radius: 6)
                    }
                }
            }

            ArrivalBanner()
        }
        .fullScreenCover(isPresented: $showingActiveTrip) {
            NavigationStack {
                ActiveTripView()
            }
        }
    }
}
