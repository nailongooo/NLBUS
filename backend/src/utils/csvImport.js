const { v4: uuidv4 } = require('uuid');

/// 解析管理员批量导入用的 CSV：每一行是"路线名,方向,站点名,纬度,经度,站点顺序"，
/// 相同路线名+方向的多行会被合并成一条路线的多个站点。
function parseAdminCSV(text) {
  const lines = text.replace(/\r\n/g, '\n').split('\n').filter(l => l.trim().length > 0);
  const header = lines.shift().split(',').map(h => h.trim().toLowerCase());
  const idx = {
    routeName: header.indexOf('route_name'),
    direction: header.indexOf('direction'),
    stopName: header.indexOf('stop_name'),
    latitude: header.indexOf('latitude'),
    longitude: header.indexOf('longitude'),
    order: header.indexOf('stop_order')
  };
  if (idx.routeName === -1 || idx.stopName === -1 || idx.latitude === -1 || idx.longitude === -1) {
    throw new Error('CSV 表头必须包含 route_name, stop_name, latitude, longitude 这几列');
  }

  const routesMap = new Map();
  lines.forEach((line, i) => {
    const cols = line.split(',').map(c => c.trim());
    const routeName = cols[idx.routeName];
    const direction = idx.direction !== -1 ? cols[idx.direction] : '';
    const key = `${routeName}__${direction}`;
    if (!routesMap.has(key)) {
      routesMap.set(key, {
        id: uuidv4(),
        name: routeName,
        direction,
        stops: []
      });
    }
    const lat = parseFloat(cols[idx.latitude]);
    const lng = parseFloat(cols[idx.longitude]);
    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      throw new Error(`第 ${i + 2} 行的经纬度不是合法数字`);
    }
    routesMap.get(key).stops.push({
      name: cols[idx.stopName],
      latitude: lat,
      longitude: lng
    });
  });

  return Array.from(routesMap.values());
}

module.exports = { parseAdminCSV };
