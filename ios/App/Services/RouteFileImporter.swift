import Foundation

/// 支持三种用户上传格式：JSON（我们自己的路线格式）、CSV（简单表格）、GPX（GPS 轨迹/路点）。
/// 全部在手机本地解析完成，解析结果只是生成一个 Route 草稿，用户确认无误后再提交/保存。
enum RouteFileImporter {

    enum ImportError: LocalizedError {
        case unsupportedFormat
        case emptyFile
        case malformedCSV(String)
        case malformedJSON(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "不支持的文件格式，请上传 .json / .csv / .gpx 文件"
            case .emptyFile: return "文件内容为空"
            case .malformedCSV(let detail): return "CSV 格式有误：\(detail)"
            case .malformedJSON(let detail): return "JSON 格式有误：\(detail)"
            }
        }
    }

    static func importRoute(from url: URL) throws -> Route {
        let ext = url.pathExtension.lowercased()
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw ImportError.emptyFile }

        switch ext {
        case "json":
            return try importJSON(data: data)
        case "csv":
            guard let text = String(data: data, encoding: .utf8) else {
                throw ImportError.malformedCSV("文件编码需要是 UTF-8")
            }
            return try importCSV(text: text)
        case "gpx":
            guard let text = String(data: data, encoding: .utf8) else {
                throw ImportError.malformedCSV("文件编码需要是 UTF-8")
            }
            return try importGPX(text: text)
        default:
            throw ImportError.unsupportedFormat
        }
    }

    /// JSON 格式示例见 docs/ 或 backend/sql 里的样例数据：
    /// {
    ///   "name": "1路公交",
    ///   "direction": "火车站 -> 大学城",
    ///   "stops": [
    ///     {"name": "火车站", "latitude": 26.07, "longitude": 119.29},
    ///     {"name": "大学城", "latitude": 26.09, "longitude": 119.31}
    ///   ]
    /// }
    private static func importJSON(data: Data) throws -> Route {
        struct ImportStop: Decodable {
            var name: String
            var latitude: Double
            var longitude: Double
        }
        struct ImportPayload: Decodable {
            var name: String
            var direction: String?
            var summary: String?
            var stops: [ImportStop]
        }

        let decoder = JSONDecoder()
        let payload: ImportPayload
        do {
            payload = try decoder.decode(ImportPayload.self, from: data)
        } catch {
            throw ImportError.malformedJSON(error.localizedDescription)
        }

        var draft = Route.emptyDraft()
        draft.name = payload.name
        draft.direction = payload.direction ?? ""
        draft.summary = payload.summary
        draft.source = .userUploaded
        draft.stops = payload.stops.enumerated().map { index, stop in
            Stop(id: UUID().uuidString, routeId: draft.id, name: stop.name, order: index, latitude: stop.latitude, longitude: stop.longitude)
        }
        return draft
    }

    /// CSV 格式（第一行必须是表头）：
    /// name,latitude,longitude
    /// 火车站,26.0798,119.2989
    /// 大学城,26.0961,119.3182
    private static func importCSV(text: String) throws -> Route {
        var lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else { throw ImportError.emptyFile }

        let header = lines.removeFirst()
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        guard let nameIdx = header.firstIndex(of: "name"),
              let latIdx = header.firstIndex(of: "latitude"),
              let lngIdx = header.firstIndex(of: "longitude") else {
            throw ImportError.malformedCSV("表头必须包含 name, latitude, longitude 三列")
        }

        var draft = Route.emptyDraft()
        draft.name = "从 CSV 导入的路线"
        draft.source = .userUploaded

        var stops: [Stop] = []
        for (index, line) in lines.enumerated() {
            let columns = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard columns.count > max(nameIdx, latIdx, lngIdx) else {
                throw ImportError.malformedCSV("第 \(index + 2) 行列数不足")
            }
            guard let lat = Double(columns[latIdx]), let lng = Double(columns[lngIdx]) else {
                throw ImportError.malformedCSV("第 \(index + 2) 行经纬度不是数字")
            }
            stops.append(Stop(id: UUID().uuidString, routeId: draft.id, name: columns[nameIdx], order: index, latitude: lat, longitude: lng))
        }
        draft.stops = stops
        return draft
    }

    /// GPX 文件：把其中的 <wpt>（路点）当作站点；如果没有路点，则从 <trkpt> 轨迹点里
    /// 每隔一定距离抽样几个点作为参考站点（因为轨迹点通常成百上千个，不适合直接当站点）。
    /// 这里用 Foundation 自带的 XMLParser 手写解析，不引入任何第三方库，
    /// 避免因为 GitHub Actions 打包时拉取第三方 Swift Package 失败而导致整个编译失败。
    private static func importGPX(text: String) throws -> Route {
        let parser = SimpleGPXParser()
        guard let data = text.data(using: .utf8) else {
            throw ImportError.malformedCSV("GPX 文件编码有误")
        }
        parser.parse(data: data)

        var draft = Route.emptyDraft()
        draft.name = parser.routeName ?? "从 GPX 导入的路线"
        draft.source = .userUploaded

        var stops: [Stop] = []
        if !parser.waypoints.isEmpty {
            for (index, wpt) in parser.waypoints.enumerated() {
                stops.append(Stop(id: UUID().uuidString, routeId: draft.id, name: wpt.name ?? "站点\(index + 1)", order: index, latitude: wpt.latitude, longitude: wpt.longitude))
            }
        } else if !parser.trackPoints.isEmpty {
            let samples = sampleEvery(parser.trackPoints, keepEvery: max(1, parser.trackPoints.count / 20))
            for (index, pt) in samples.enumerated() {
                stops.append(Stop(id: UUID().uuidString, routeId: draft.id, name: "站点\(index + 1)", order: index, latitude: pt.latitude, longitude: pt.longitude))
            }
        }

        guard !stops.isEmpty else {
            throw ImportError.malformedCSV("GPX 文件中没有找到可用的路点(wpt)或轨迹点(trkpt)")
        }
        draft.stops = stops
        return draft
    }

    private static func sampleEvery<T>(_ array: [T], keepEvery: Int) -> [T] {
        guard keepEvery > 0 else { return array }
        return array.enumerated().filter { $0.offset % keepEvery == 0 }.map { $0.element }
    }
}

/// 极简 GPX 解析器：只关心 <wpt>/<trkpt> 的 lat/lon 属性和内部的 <name>，
/// 足够覆盖"用户用 GPS 记录路线后导出 GPX 再导入"这个场景。
private final class SimpleGPXParser: NSObject, XMLParserDelegate {
    struct GeoPoint {
        var name: String?
        var latitude: Double
        var longitude: Double
    }

    private(set) var waypoints: [GeoPoint] = []
    private(set) var trackPoints: [GeoPoint] = []
    private(set) var routeName: String?

    private var currentElement = ""
    private var currentLat: Double?
    private var currentLng: Double?
    private var currentName: String = ""
    private var isInsideWaypoint = false
    private var isInsideTrackPoint = false
    private var isInsideMetadataName = false

    func parse(data: Data) {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        switch elementName {
        case "wpt":
            isInsideWaypoint = true
            currentLat = attributeDict["lat"].flatMap(Double.init)
            currentLng = attributeDict["lon"].flatMap(Double.init)
            currentName = ""
        case "trkpt":
            isInsideTrackPoint = true
            currentLat = attributeDict["lat"].flatMap(Double.init)
            currentLng = attributeDict["lon"].flatMap(Double.init)
        case "name":
            if !isInsideWaypoint && !isInsideTrackPoint {
                isInsideMetadataName = true
                currentName = ""
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElement == "name" {
            currentName += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "wpt":
            if let lat = currentLat, let lng = currentLng {
                waypoints.append(GeoPoint(name: currentName.isEmpty ? nil : currentName, latitude: lat, longitude: lng))
            }
            isInsideWaypoint = false
        case "trkpt":
            if let lat = currentLat, let lng = currentLng {
                trackPoints.append(GeoPoint(name: nil, latitude: lat, longitude: lng))
            }
            isInsideTrackPoint = false
        case "name":
            if isInsideMetadataName {
                routeName = currentName.isEmpty ? nil : currentName
                isInsideMetadataName = false
            }
        default:
            break
        }
    }
}
