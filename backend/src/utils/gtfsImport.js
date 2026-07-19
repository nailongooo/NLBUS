const { v4: uuidv4 } = require('uuid');

/// 极简 GTFS 导入：接收 GTFS 标准里的 routes.txt / stops.txt / trips.txt / stop_times.txt 四个文件的原始文本
/// （不需要在服务器上解压 zip；管理员在本地把 GTFS zip 解压后，把这四个 .txt 文件分别上传即可）。
/// 只覆盖最常见字段，复杂的 GTFS 特性（如多日历、多种交通方式）不在第一版范围内。

function parseCSVText(text) {
  const lines = text.replace(/\r\n/g, '\n').split('\n').filter(l => l.length > 0);
  if (lines.length === 0) return [];
  const header = splitCSVLine(lines[0]);
  return lines.slice(1).map(line => {
    const cols = splitCSVLine(line);
    const obj = {};
    header.forEach((h, i) => { obj[h.trim()] = (cols[i] || '').trim(); });
    return obj;
  });
}

// 简单处理带引号的 CSV 字段（GTFS 文件里站名经常包含逗号，需要引号包裹）
function splitCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      result.push(current);
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current);
  return result;
}

function convertGTFSToRoutes({ routesTxt, stopsTxt, tripsTxt, stopTimesTxt }) {
  const gtfsRoutes = parseCSVText(routesTxt);
  const gtfsStops = parseCSVText(stopsTxt);
  const gtfsTrips = parseCSVText(tripsTxt);
  const gtfsStopTimes = parseCSVText(stopTimesTxt);

  const stopsById = new Map(gtfsStops.map(s => [s.stop_id, s]));
  // 每条 GTFS route 只取它的第一个 trip 作为代表性的站序（一条路线在 GTFS 里往往有很多个 trip/班次，
  // 第一版先只导入"典型的一趟"作为站点顺序，足够覆盖大部分公交路线的场景）。
  const firstTripByRoute = new Map();
  gtfsTrips.forEach(trip => {
    if (!firstTripByRoute.has(trip.route_id)) {
      firstTripByRoute.set(trip.route_id, trip);
    }
  });

  const stopTimesByTrip = new Map();
  gtfsStopTimes.forEach(st => {
    if (!stopTimesByTrip.has(st.trip_id)) stopTimesByTrip.set(st.trip_id, []);
    stopTimesByTrip.get(st.trip_id).push(st);
  });

  const results = [];
  for (const route of gtfsRoutes) {
    const trip = firstTripByRoute.get(route.route_id);
    if (!trip) continue;
    const stopTimes = (stopTimesByTrip.get(trip.trip_id) || [])
      .sort((a, b) => Number(a.stop_sequence) - Number(b.stop_sequence));
    if (stopTimes.length < 2) continue;

    const stops = stopTimes.map(st => {
      const gtfsStop = stopsById.get(st.stop_id);
      return {
        name: gtfsStop ? gtfsStop.stop_name : st.stop_id,
        latitude: gtfsStop ? parseFloat(gtfsStop.stop_lat) : 0,
        longitude: gtfsStop ? parseFloat(gtfsStop.stop_lon) : 0
      };
    }).filter(s => !Number.isNaN(s.latitude) && !Number.isNaN(s.longitude));

    if (stops.length < 2) continue;

    results.push({
      id: uuidv4(),
      name: route.route_short_name || route.route_long_name || route.route_id,
      direction: trip.trip_headsign || '',
      stops
    });
  }
  return results;
}

module.exports = { convertGTFSToRoutes, parseCSVText };
