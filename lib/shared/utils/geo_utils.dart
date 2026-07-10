// lib/shared/utils/geo_utils.dart

import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class GeoUtils {
  /// Calculates area of a polygon in square meters using spherical coordinate projection
  static double calculatePolygonAreaMeters(List<LatLng> polygon) {
    if (polygon.length < 3) return 0.0;
    
    const double r = 6378137.0; // Earth radius in meters
    
    // Calculate bounding box center to use localized projection
    double sumLat = 0;
    for (final p in polygon) {
      sumLat += p.latitude;
    }
    final double centerLatRad = (sumLat / polygon.length) * (math.pi / 180.0);
    final double cosCenterLat = math.cos(centerLatRad);

    final points = polygon.map((latLng) {
      final double latRad = latLng.latitude * (math.pi / 180.0);
      final double lonRad = latLng.longitude * (math.pi / 180.0);
      
      // Localized sinusoidal projection
      final double x = r * lonRad * cosCenterLat;
      final double y = r * latRad;
      return _Point2D(x, y);
    }).toList();
    
    double area = 0.0;
    int j = points.length - 1;
    for (int i = 0; i < points.length; i++) {
      area += (points[j].x * points[i].y) - (points[i].x * points[j].y);
      j = i;
    }
    
    return (area / 2.0).abs();
  }
  
  /// Calculates acreage of a polygon
  static double calculatePolygonAcreage(List<LatLng> polygon) {
    final double areaMeters = calculatePolygonAreaMeters(polygon);
    // 1 acre = 4046.85642 square meters
    return areaMeters / 4046.85642;
  }
}

class _Point2D {
  final double x;
  final double y;
  _Point2D(this.x, this.y);
}
