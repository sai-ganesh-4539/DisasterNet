import 'dart:convert';

import 'package:field_app/core/config.dart';
import 'package:http/http.dart' as http;

class LiveGisApi {
  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);
  }

  static Future<Map<String, dynamic>> snapshot({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final uri = _uri('/api/v1/gis/snapshot', {
      'south': south.toStringAsFixed(4),
      'west': west.toStringAsFixed(4),
      'north': north.toStringAsFixed(4),
      'east': east.toStringAsFixed(4),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) {
      throw Exception('GIS snapshot failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> inspect({
    required double latitude,
    required double longitude,
  }) async {
    final uri = _uri('/api/v1/gis/inspect', {
      'latitude': latitude.toStringAsFixed(5),
      'longitude': longitude.toStringAsFixed(5),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw Exception('Inspect failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
