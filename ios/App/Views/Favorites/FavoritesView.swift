import SwiftUI

struct FavoritesView: View {
    @StateObject private var favoritesStore = FavoritesStore.shared

    var body: some View {
        Group {
            if favoritesStore.favorites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star").font(.system(size: 44)).foregroundStyle(.secondary)
                    Text(NSLocalizedString("favorites.empty", comment: "")).foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(favoritesStore.favorites) { route in
                        NavigationLink(destination: RouteDetailView(route: route)) {
                            RouteRowCard(route: route)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            favoritesStore.toggle(favoritesStore.favorites[index])
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(NSLocalizedString("tab.favorites", comment: ""))
    }
}
