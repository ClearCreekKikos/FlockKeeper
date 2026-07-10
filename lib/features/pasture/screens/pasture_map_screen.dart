// lib/features/pasture/screens/pasture_map_screen.dart

import 'dart:convert';
import 'dart:math' show Point;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../data/models/pasture_model.dart';
import '../../../data/models/animal_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/utils/geo_utils.dart';
import 'add_edit_pasture_screen.dart';
import 'pasture_detail_screen.dart';
import '../../settings/screens/subscription_paywall_screen.dart';

class PastureMapScreen extends ConsumerStatefulWidget {
  final Pasture? editingPasture;
  const PastureMapScreen({super.key, this.editingPasture});

  @override
  ConsumerState<PastureMapScreen> createState() => _PastureMapScreenState();
}

class _PastureMapScreenState extends ConsumerState<PastureMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _mapKey = GlobalKey();
  
  bool _isSatellite = false;
  bool _isDrawing = false;
  List<LatLng> _drawnPoints = [];
  bool _isSearching = false;

  // Active highlighted pasture when tapping a polygon/pin
  Pasture? _selectedPasture;
  List<Animal> _selectedPastureAnimals = [];

  @override
  void initState() {
    super.initState();
    if (widget.editingPasture != null) {
      _isDrawing = true;
      _drawnPoints = List<LatLng>.from(widget.editingPasture!.boundaryPolygon ?? []);
      _isSatellite = true;
    }
  }

  // Default coordinate (Clear Creek Kikos Farm center coordinates, near Oklahoma/Texas border)
  static final LatLng _defaultCenter = const LatLng(34.8000, -96.5000);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Localized Geocoding search via Nominatim
  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'FlockKeeper Pasture Search Map Tool',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final location = LatLng(lat, lon);
          _mapController.move(location, 16.0);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Centered map on: ${data[0]['display_name']}')),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No location coordinates found for search term.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  LatLng _calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    double sumLat = 0;
    double sumLng = 0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  Color _getStatusColor(PastureStatus status, {double opacity = 0.3}) {
    switch (status) {
      case PastureStatus.available:
        return Colors.green.withValues(alpha: opacity);
      case PastureStatus.occupied:
        return Colors.red.withValues(alpha: opacity);
      case PastureStatus.resting:
        return Colors.orange.withValues(alpha: opacity);
      case PastureStatus.maintenance:
        return Colors.grey.withValues(alpha: opacity);
    }
  }

  Future<void> _fetchPastureAnimals(Pasture pasture) async {
    final repo = ref.read(pastureRepositoryProvider);
    final list = await repo.getAnimalsInPasture(pasture.id!);
    setState(() {
      _selectedPasture = pasture;
      _selectedPastureAnimals = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    final isPremium = settings['is_premium'] == 'true';
    if (!isPremium) {
      return SubscriptionPaywallScreen(
        onDismiss: () => Navigator.pop(context),
      );
    }

    final pasturesAsync = ref.watch(pasturesListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isDrawing ? 'Draw Pasture Boundary' : 'Pastures Map View'),
        actions: [
          IconButton(
            icon: Icon(_isSatellite ? Icons.map : Icons.satellite_outlined),
            tooltip: _isSatellite ? 'Switch to Street View' : 'Switch to Satellite View',
            onPressed: () => setState(() => _isSatellite = !_isSatellite),
          ),
          if (!_isDrawing)
            IconButton(
              icon: const Icon(Icons.edit_road),
              tooltip: 'Draw New Pasture Boundary',
              onPressed: () {
                setState(() {
                  _isDrawing = true;
                  _drawnPoints = [];
                  _selectedPasture = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tap on the map to add fence line corner posts.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // ─── Native flutter_map Tile Rendering ───
          pasturesAsync.when(
            data: (pastures) {
              final polygonList = pastures
                  .where((p) => p.boundaryPolygon != null && p.boundaryPolygon!.isNotEmpty)
                  .map((p) {
                return Polygon(
                  points: p.boundaryPolygon!,
                  color: _getStatusColor(p.status, opacity: 0.3),
                  borderColor: _getStatusColor(p.status, opacity: 0.8),
                  borderStrokeWidth: 3.0,
                );
              }).toList();

              // If drawing, render the current draft polygon
              if (_isDrawing && _drawnPoints.isNotEmpty) {
                polygonList.add(
                  Polygon(
                    points: _drawnPoints,
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderColor: Colors.blueAccent,
                    borderStrokeWidth: 3.0,
                  ),
                );
              }

              // Build pin markers at centroids
              final markerList = pastures
                  .where((p) => p.boundaryPolygon != null && p.boundaryPolygon!.isNotEmpty)
                  .map((p) {
                final centroid = _calculateCentroid(p.boundaryPolygon!);
                return Marker(
                  point: centroid,
                  width: 90,
                  height: 60,
                  child: GestureDetector(
                    onTap: () => _fetchPastureAnimals(p),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getStatusColor(p.status, opacity: 0.95),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                            ],
                          ),
                          child: Text(
                            p.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white,
                          child: Text(
                            '🐐${p.currentAnimalCount}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList();

              // Add raw draft points as circles so they can see vertex handles
              if (_isDrawing) {
                for (int i = 0; i < _drawnPoints.length; i++) {
                  markerList.add(
                    Marker(
                      point: _drawnPoints[i],
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPressMoveUpdate: (details) {
                          final RenderBox? renderBox = _mapKey.currentContext?.findRenderObject() as RenderBox?;
                          if (renderBox != null) {
                            final localOffset = renderBox.globalToLocal(details.globalPosition);
                            final latLng = _mapController.camera.pointToLatLng(Point(localOffset.dx, localOffset.dy));
                            setState(() {
                              _drawnPoints[i] = latLng;
                            });
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }

              // Determine initial map zoom centers
              LatLng mapCenter = _defaultCenter;
              if (widget.editingPasture != null &&
                  widget.editingPasture!.boundaryPolygon != null &&
                  widget.editingPasture!.boundaryPolygon!.isNotEmpty) {
                mapCenter = _calculateCentroid(widget.editingPasture!.boundaryPolygon!);
              } else if (pastures.isNotEmpty) {
                final valid = pastures.firstWhere(
                  (p) => p.boundaryPolygon != null && p.boundaryPolygon!.isNotEmpty,
                  orElse: () => pastures.first,
                );
                if (valid.boundaryPolygon != null && valid.boundaryPolygon!.isNotEmpty) {
                  mapCenter = _calculateCentroid(valid.boundaryPolygon!);
                }
              }

              return FlutterMap(
                key: _mapKey,
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: 15.0,
                  onTap: (tapPosition, latLng) {
                    if (_isDrawing) {
                      setState(() {
                        _drawnPoints.add(latLng);
                      });
                    } else {
                      // Clicked empty area -> dismiss selected pasture panel
                      setState(() {
                        _selectedPasture = null;
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: _isSatellite
                        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.clearcreekkikos.flockkeeper',
                  ),
                  PolygonLayer(polygons: polygonList),
                  MarkerLayer(markers: markerList),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Map Loading Error: $err')),
          ),

          // ─── Address Nominatim Search Bar ───
          if (!_isDrawing)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search Address, City, Zip or Coordinates...',
                            border: InputBorder.none,
                          ),
                          onSubmitted: _searchAddress,
                        ),
                      ),
                      if (_isSearching)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () => _searchAddress(_searchController.text),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // ─── Drawing mode overlay panels ───
          if (_isDrawing) ...[
            // Status bar at top
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                color: Colors.blueAccent.withValues(alpha: 0.9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Drawing Mode Active',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Vertices: ${_drawnPoints.length} | Calculated Area: ${GeoUtils.calculatePolygonAcreage(_drawnPoints).toStringAsFixed(2)} acres',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Controls bar at bottom
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          setState(() {
                            _isDrawing = false;
                            _drawnPoints = [];
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.undo, color: Colors.orange),
                        tooltip: 'Undo last point',
                        onPressed: _drawnPoints.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _drawnPoints.removeLast();
                                });
                              },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                        tooltip: 'Clear all points',
                        onPressed: _drawnPoints.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _drawnPoints.clear();
                                });
                              },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _drawnPoints.length < 3
                            ? null
                            : () async {
                                final computedAcres = GeoUtils.calculatePolygonAcreage(_drawnPoints);
                                final pointsCopy = List<LatLng>.from(_drawnPoints);

                                setState(() {
                                  _isDrawing = false;
                                  _drawnPoints = [];
                                });

                                // Navigate to AddEditPastureScreen with boundary polygon populated
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddEditPastureScreen(
                                      initialBoundary: pointsCopy,
                                      initialAcreage: computedAcres,
                                    ),
                                  ),
                                );

                                if (result == true) {
                                  ref.invalidate(pasturesListProvider);
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ─── Selected Pasture Detail Summary overlay ───
          if (_selectedPasture != null && !_isDrawing)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedPasture!.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Chip(
                            label: Text(
                              _selectedPasture!.statusDisplay,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: _getStatusColor(_selectedPasture!.status, opacity: 0.9),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Size: ${_selectedPasture!.acreage?.toStringAsFixed(2) ?? 'N/A'} acres | Forage: ${_selectedPasture!.forageType ?? 'Unspecified'}',
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                      ),
                      const Divider(height: 16),
                      Text(
                        'Assigned Goats (${_selectedPastureAnimals.length}):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 70,
                        child: _selectedPastureAnimals.isEmpty
                            ? const Center(
                                child: Text(
                                  'No goats currently grazing here.',
                                  style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedPastureAnimals.length,
                                itemBuilder: (context, index) {
                                  final animal = _selectedPastureAnimals[index];
                                  return Card(
                                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            animal.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          Text(
                                            'Tag: ${animal.earTag ?? 'N/A'}',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('Dismiss'),
                            onPressed: () => setState(() => _selectedPasture = null),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('View Full Details'),
                            onPressed: () async {
                              final p = _selectedPasture!;
                              setState(() {
                                _selectedPasture = null;
                              });
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PastureDetailScreen(pastureId: p.id!),
                                ),
                              );
                              ref.invalidate(pasturesListProvider);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
