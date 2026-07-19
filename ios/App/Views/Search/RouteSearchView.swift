import SwiftUI

struct RouteSearchView: View {
    @State private var keyword: String = ""
    @State private var results: [Route] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
            if results.isEmpty && !keyword.isEmpty && !isSearching {
                ContentUnavailableFallback(text: NSLocalizedString("search.no_results", comment: ""))
            }
            ForEach(results) { route in
                NavigationLink(destination: RouteDetailView(route: route)) {
                    RouteRowCard(route: route)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .searchable(text: $keyword, prompt: NSLocalizedString("search.prompt", comment: ""))
        .onSubmit(of: .search) { Task { await search() } }
        .onChange(of: keyword) { _, newValue in
            if newValue.isEmpty {
                results = Route.builtinSamples()
            }
        }
        .navigationTitle(NSLocalizedString("tab.search", comment: ""))
        .task { results = Route.builtinSamples() }
    }

    private func search() async {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let remote = try await APIClient.shared.searchRoutes(keyword: keyword)
            results = remote
        } catch {
            errorMessage = NSLocalizedString("search.network_hint", comment: "")
            // 网络不可用时，至少在内置示例路线里做本地关键字过滤，保证功能不完全瘫痪
            results = Route.builtinSamples().filter { $0.name.contains(keyword) || $0.direction.contains(keyword) }
        }
    }
}

struct ContentUnavailableFallback: View {
    var text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.largeTitle).foregroundStyle(.secondary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}
