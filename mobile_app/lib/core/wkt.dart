import 'package:latlong2/latlong.dart';

/// Parse WKT POLYGON / MULTIPOLYGON rings into map points (lon lat → LatLng).
List<List<LatLng>> parseWktPolygons(String wkt) {
  if (wkt.isEmpty) return const [];
  final rings = <List<LatLng>>[];
  final ringPattern = RegExp(r'\(\s*((?:-?\d+\.?\d*\s+-?\d+\.?\d*\s*,?\s*)+)\)');
  for (final match in ringPattern.allMatches(wkt)) {
    final body = match.group(1);
    if (body == null) continue;
    final pts = <LatLng>[];
    final pairPattern = RegExp(r'(-?\d+\.?\d*)\s+(-?\d+\.?\d*)');
    for (final pair in pairPattern.allMatches(body)) {
      final lon = double.tryParse(pair.group(1)!);
      final lat = double.tryParse(pair.group(2)!);
      if (lon == null || lat == null) continue;
      pts.add(LatLng(lat, lon));
    }
    if (pts.length >= 3) rings.add(pts);
  }
  return rings;
}
