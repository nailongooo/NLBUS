import SwiftUI
import MapKit
import CoreLocation

/// 地址搜索（用于新建路线时按地名添加站点），基于系统自带的 MKLocalSearchCompleter，
/// 不需要任何第三方地图 API Key。
struct AddressSearchView: View {
    var onPick: (String, CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) var dismiss
    @StateObject private var searcher = AddressSearcher()

    var body: some View {
        NavigationStack {
            List(searcher.results, id: \.self) { completion in
                Button {
                    searcher.resolve(completion) { name, coordinate in
                        if let coordinate {
                            onPick(name, coordinate)
                            dismiss()
                        }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text(completion.title)
                        Text(completion.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searcher.queryText, prompt: NSLocalizedString("address_search.prompt", comment: ""))
            .navigationTitle(NSLocalizedString("address_search.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                }
            }
        }
    }
}

final class AddressSearcher: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var queryText: String = "" {
        didSet { completer.queryFragment = queryText }
    }
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }

    func resolve(_ completion: MKLocalSearchCompletion, callback: @escaping (String, CLLocationCoordinate2D?) -> Void) {
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            callback(completion.title, response?.mapItems.first?.placemark.coordinate)
        }
    }
}
