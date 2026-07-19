import SwiftUI
import SwiftData

struct TripHistoryView: View {
    @Query(sort: \Trip.startedAt, order: .reverse) private var trips: [Trip]

    var body: some View {
        Group {
            if trips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 44)).foregroundStyle(.secondary)
                    Text(NSLocalizedString("history.empty", comment: "")).foregroundStyle(.secondary)
                }
            } else {
                List(trips) { trip in
                    NavigationLink(destination: TripHistoryDetailView(trip: trip)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.routeName).font(.headline)
                            Text("\(trip.boardStopName) → \(trip.alightStopName)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text(trip.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("history.title", comment: ""))
    }
}
