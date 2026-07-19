import SwiftUI
import MapKit
import CoreLocation

struct TripHistoryDetailView: View {
    var trip: Trip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !trip.trackPoints.isEmpty {
                    Map {
                        MapPolyline(coordinates: trip.trackPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                            .stroke(.blue, lineWidth: 4)
                    }
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(trip.routeName).font(.title3.bold())
                        Text("\(trip.boardStopName) → \(trip.alightStopName)").foregroundStyle(.secondary)
                        Divider()
                        infoRow(NSLocalizedString("history.detail.start_time", comment: ""), trip.startedAt.formatted(date: .abbreviated, time: .shortened))
                        if let ended = trip.endedAt {
                            infoRow(NSLocalizedString("history.detail.end_time", comment: ""), ended.formatted(date: .abbreviated, time: .shortened))
                        }
                        infoRow(NSLocalizedString("history.detail.distance", comment: ""), String(format: "%.0f 米", trip.distanceMeters))
                        if trip.missedStopTriggered {
                            Label(NSLocalizedString("history.detail.missed_stop_flag", comment: ""), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.footnote)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(NSLocalizedString("history.detail.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }
}
