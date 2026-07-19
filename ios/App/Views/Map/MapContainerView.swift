import SwiftUI
import MapKit

/// 复用的地图组件：展示路线站点连线、可选中的站点、用户当前位置、以及众包车辆位置。
/// 使用 Apple 原生 MapKit（无需任何第三方 SDK / API Key），账号免费也能直接使用。
struct MapContainerView: View {
    var stops: [Stop]
    var liveVehicles: [LiveVehicle] = []
    var highlightedStopIds: Set<String> = []
    var onTapStop: ((Stop) -> Void)? = nil

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            if stops.count >= 2 {
                MapPolyline(coordinates: stops.sorted(by: { $0.order < $1.order }).map(\.coordinate))
                    .stroke(.blue, lineWidth: 4)
            }

            ForEach(stops) { stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    Button {
                        onTapStop?(stop)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(highlightedStopIds.contains(stop.id) ? Color.orange : Color.blue)
                                .frame(width: 14, height: 14)
                            Circle()
                                .stroke(.white, lineWidth: 2)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }

            ForEach(liveVehicles) { vehicle in
                Annotation(NSLocalizedString("map.live_vehicle", comment: ""), coordinate: vehicle.coordinate) {
                    Image(systemName: "bus.fill")
                        .font(.caption)
                        .padding(6)
                        .background(Color.green, in: Circle())
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onAppear {
            if let first = stops.first {
                cameraPosition = .region(
                    MKCoordinateRegion(center: first.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
                )
            }
        }
    }
}
