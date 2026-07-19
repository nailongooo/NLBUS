import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct CreateRouteView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var draft = Route.emptyDraft()
    @State private var showingAddressSearch = false
    @State private var isRecordingGPS = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var savedSuccessfully = false

    private let gpsRecorder = LocationManager()

    var body: some View {
        Form {
            Section(NSLocalizedString("create_route.basic_info", comment: "")) {
                TextField(NSLocalizedString("create_route.name", comment: ""), text: $draft.name)
                TextField(NSLocalizedString("create_route.direction", comment: ""), text: $draft.direction)
                TextField(NSLocalizedString("create_route.summary", comment: ""), text: Binding(get: { draft.summary ?? "" }, set: { draft.summary = $0 }), axis: .vertical)
                ColorPicker(NSLocalizedString("create_route.color", comment: ""), selection: Binding(
                    get: { Color(hex: draft.colorHex) },
                    set: { draft.colorHex = $0.toHex() }
                ))
            }

            Section(NSLocalizedString("create_route.operation_info", comment: "")) {
                TextField(NSLocalizedString("create_route.fare", comment: ""), text: Binding(get: { draft.fareDescription ?? "" }, set: { draft.fareDescription = $0 }))
                TextField(NSLocalizedString("create_route.first_bus", comment: ""), text: Binding(get: { draft.firstBusTime ?? "" }, set: { draft.firstBusTime = $0 }))
                TextField(NSLocalizedString("create_route.last_bus", comment: ""), text: Binding(get: { draft.lastBusTime ?? "" }, set: { draft.lastBusTime = $0 }))
                TextField(NSLocalizedString("create_route.headway", comment: ""), value: Binding(get: { draft.headwayMinutes ?? 0 }, set: { draft.headwayMinutes = $0 }), format: .number)
                    .keyboardType(.numberPad)
                TextField(NSLocalizedString("create_route.operator", comment: ""), text: Binding(get: { draft.operatorCompany ?? "" }, set: { draft.operatorCompany = $0 }))
            }

            Section(NSLocalizedString("create_route.stops_section", comment: "")) {
                Map(position: $cameraPosition) {
                    ForEach(draft.stops) { stop in
                        Annotation(stop.name, coordinate: stop.coordinate) {
                            Circle().fill(.blue).frame(width: 12, height: 12)
                        }
                    }
                    if draft.stops.count >= 2 {
                        MapPolyline(coordinates: draft.stops.sorted(by: { $0.order < $1.order }).map(\.coordinate))
                            .stroke(.blue, lineWidth: 3)
                    }
                }
                .frame(height: 220)
                .mapControls { MapUserLocationButton() }
                .onTapGesture { /* 提示用户使用下方按钮添加站点，直接点地图坐标转换在部分设备上不稳定，改为下方两种确定性更强的方式 */ }

                Button {
                    showingAddressSearch = true
                } label: {
                    Label(NSLocalizedString("create_route.add_by_address", comment: ""), systemImage: "text.magnifyingglass")
                }

                Button {
                    toggleGPSRecording()
                } label: {
                    Label(
                        isRecordingGPS ? NSLocalizedString("create_route.stop_gps_record", comment: "") : NSLocalizedString("create_route.start_gps_record", comment: ""),
                        systemImage: isRecordingGPS ? "stop.circle.fill" : "location.circle"
                    )
                    .foregroundStyle(isRecordingGPS ? .red : .accentColor)
                }

                ForEach(draft.stops.sorted(by: { $0.order < $1.order })) { stop in
                    HStack {
                        Text("\(stop.order + 1). \(stop.name)")
                        Spacer()
                        Text(String(format: "%.4f, %.4f", stop.latitude, stop.longitude))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    var sorted = draft.stops.sorted(by: { $0.order < $1.order })
                    sorted.remove(atOffsets: indexSet)
                    reindex(&sorted)
                    draft.stops = sorted
                }
                .onMove { from, to in
                    var sorted = draft.stops.sorted(by: { $0.order < $1.order })
                    sorted.move(fromOffsets: from, toOffset: to)
                    reindex(&sorted)
                    draft.stops = sorted
                }
            }

            Section(NSLocalizedString("create_route.visibility_section", comment: "")) {
                Toggle(NSLocalizedString("create_route.make_public", comment: ""), isOn: $draft.isPublic)
                Text(draft.isPublic ? NSLocalizedString("create_route.public_hint", comment: "") : NSLocalizedString("create_route.private_hint", comment: ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let saveError {
                Text(saveError).foregroundStyle(.red).font(.footnote)
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(NSLocalizedString("common.save", comment: "")).frame(maxWidth: .infinity)
                    }
                }
                .disabled(draft.name.isEmpty || draft.stops.count < 2 || isSaving)
            }
        }
        .navigationTitle(NSLocalizedString("create_route.title", comment: ""))
        .toolbar { EditButton() }
        .sheet(isPresented: $showingAddressSearch) {
            AddressSearchView { name, coordinate in
                appendStop(name: name, coordinate: coordinate)
            }
        }
        .alert(NSLocalizedString("create_route.saved_title", comment: ""), isPresented: $savedSuccessfully) {
            Button(NSLocalizedString("common.ok", comment: "")) { dismiss() }
        }
    }

    private func appendStop(name: String, coordinate: CLLocationCoordinate2D) {
        let stop = Stop(id: UUID().uuidString, routeId: draft.id, name: name, order: draft.stops.count, latitude: coordinate.latitude, longitude: coordinate.longitude)
        draft.stops.append(stop)
        cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
    }

    private func reindex(_ stops: inout [Stop]) {
        for i in stops.indices { stops[i].order = i }
    }

    private func toggleGPSRecording() {
        isRecordingGPS.toggle()
        if isRecordingGPS {
            gpsRecorder.requestWhenInUseAuthorization()
            gpsRecorder.onLocationUpdate = { location in
                DispatchQueue.main.async {
                    appendStop(name: String(format: NSLocalizedString("create_route.gps_stop_name", comment: ""), draft.stops.count + 1), coordinate: location.coordinate)
                }
            }
            gpsRecorder.startForegroundOnlyUpdates()
        } else {
            gpsRecorder.stopForegroundOnlyUpdates()
        }
    }

    private func save() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        draft.status = draft.isPublic ? .pending : .privateOnly
        draft.updatedAt = Date()
        do {
            _ = try await APIClient.shared.createRoute(draft)
            savedSuccessfully = true
        } catch {
            saveError = error.localizedDescription
        }
    }
}

extension Color {
    /// 把 SwiftUI Color 转回 "#RRGGBB" 字符串，配合 ColorPicker 使用
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
