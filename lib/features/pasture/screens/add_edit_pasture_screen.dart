// lib/features/pasture/screens/add_edit_pasture_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/pasture_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/utils/geo_utils.dart';
import 'pasture_map_screen.dart';

class AddEditPastureScreen extends ConsumerStatefulWidget {
  final Pasture? pasture;
  final List<LatLng>? initialBoundary;
  final double? initialAcreage;

  const AddEditPastureScreen({
    super.key,
    this.pasture,
    this.initialBoundary,
    this.initialAcreage,
  });

  @override
  ConsumerState<AddEditPastureScreen> createState() => _AddEditPastureScreenState();
}

class _AddEditPastureScreenState extends ConsumerState<AddEditPastureScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _acreageController;
  late TextEditingController _capacityController;
  late TextEditingController _forageController;
  late TextEditingController _waterController;
  late TextEditingController _fencingController;
  late TextEditingController _restDaysController;
  late TextEditingController _notesController;
  late PastureStatus _status;
  List<LatLng>? _boundaryPolygon;

  bool get isEdit => widget.pasture != null;

  @override
  void initState() {
    super.initState();
    _boundaryPolygon = widget.pasture?.boundaryPolygon ?? widget.initialBoundary;
    _nameController = TextEditingController(text: widget.pasture?.name ?? '');
    
    final initialAcreText = widget.pasture?.acreage?.toString() ?? 
                            (widget.initialAcreage != null ? widget.initialAcreage!.toStringAsFixed(2) : '');
    _acreageController = TextEditingController(text: initialAcreText);
    
    _capacityController = TextEditingController(text: widget.pasture?.carryingCapacity?.toString() ?? '');
    _forageController = TextEditingController(text: widget.pasture?.forageType ?? '');
    _waterController = TextEditingController(text: widget.pasture?.waterSource ?? '');
    _fencingController = TextEditingController(text: widget.pasture?.fencingType ?? '');
    _restDaysController = TextEditingController(text: widget.pasture?.restDaysTarget.toString() ?? '30');
    _notesController = TextEditingController(text: widget.pasture?.notes ?? '');
    _status = widget.pasture?.status ?? PastureStatus.available;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _acreageController.dispose();
    _capacityController.dispose();
    _forageController.dispose();
    _waterController.dispose();
    _fencingController.dispose();
    _restDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _savePasture() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(pastureRepositoryProvider);
    final now = DateTime.now();

    final newPasture = Pasture(
      id: widget.pasture?.id,
      name: _nameController.text.trim(),
      acreage: double.tryParse(_acreageController.text.trim()),
      carryingCapacity: int.tryParse(_capacityController.text.trim()),
      forageType: _forageController.text.trim().isNotEmpty ? _forageController.text.trim() : null,
      waterSource: _waterController.text.trim().isNotEmpty ? _waterController.text.trim() : null,
      fencingType: _fencingController.text.trim().isNotEmpty ? _fencingController.text.trim() : null,
      restDaysTarget: int.tryParse(_restDaysController.text.trim()) ?? 30,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      status: _status,
      currentAnimalCount: widget.pasture?.currentAnimalCount ?? 0,
      lastGrazedDate: widget.pasture?.lastGrazedDate,
      availableDate: widget.pasture?.availableDate,
      boundaryPolygon: _boundaryPolygon,
      createdAt: widget.pasture?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (isEdit) {
        await repo.updatePasture(newPasture);
      } else {
        await repo.insertPasture(newPasture);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Pasture updated successfully.'
                  : 'Pasture created successfully.',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving pasture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Pasture' : 'Add Pasture'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Pasture Name ───────────────────────────────────────────────
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Pasture Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name for the pasture';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ─── Acreage ─────────────────────────────────────────────────
              TextFormField(
                controller: _acreageController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Acreage (ac)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.crop_square_outlined),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (double.tryParse(value.trim()) == null) {
                      return 'Enter a valid decimal';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // ─── Map Boundary Preview ───
              if (_boundaryPolygon != null && _boundaryPolygon!.isNotEmpty) ...[
                const Text(
                  'Map Boundary Preview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: () {
                          double sumLat = 0;
                          double sumLng = 0;
                          for (final p in _boundaryPolygon!) {
                            sumLat += p.latitude;
                            sumLng += p.longitude;
                          }
                          return LatLng(sumLat / _boundaryPolygon!.length, sumLng / _boundaryPolygon!.length);
                        }(),
                        initialZoom: 15.5,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                          userAgentPackageName: 'com.clearcreekkikos.flockkeeper',
                        ),
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _boundaryPolygon!,
                              color: Colors.green.withValues(alpha: 0.3),
                              borderColor: Colors.green,
                              borderStrokeWidth: 3.0,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: Text(_boundaryPolygon != null ? 'Modify Boundary on Map' : 'Draw Boundary on Map'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  // Direct link to drawing mode
                  final points = await Navigator.push<List<LatLng>>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PastureMapScreen(
                        editingPasture: widget.pasture?.copyWith(boundaryPolygon: _boundaryPolygon) ??
                            Pasture(
                              name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'New Pasture',
                              boundaryPolygon: _boundaryPolygon,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ),
                      ),
                    ),
                  );

                  if (points != null) {
                    setState(() {
                      _boundaryPolygon = points;
                      final acres = GeoUtils.calculatePolygonAcreage(points);
                      _acreageController.text = acres.toStringAsFixed(2);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // ─── Carrying Capacity ───────────────────────────────────────
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Carrying Capacity (head)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (int.tryParse(value.trim()) == null) {
                      return 'Enter a valid integer';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ─── Forage Type ─────────────────────────────────────────────────
              TextFormField(
                controller: _forageController,
                decoration: const InputDecoration(
                  labelText: 'Forage Type (e.g. Alfalfa, Clover, Mixed)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.grass),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Water Source ────────────────────────────────────────────
              TextFormField(
                controller: _waterController,
                decoration: const InputDecoration(
                  labelText: 'Water Source',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Fencing Type ────────────────────────────────────────────
              TextFormField(
                controller: _fencingController,
                decoration: const InputDecoration(
                  labelText: 'Fencing Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fence_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Status ──────────────────────────────────────────────────
              DropdownButtonFormField<PastureStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.checklist_outlined),
                ),
                items: PastureStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(
                      status.name[0].toUpperCase() + status.name.substring(1),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _status = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // ─── Target Rest Days ────────────────────────────────────────
              TextFormField(
                controller: _restDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rest Target (days)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  if (int.tryParse(value.trim()) == null) {
                    return 'Enter valid integer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ─── Notes ───────────────────────────────────────────────────────
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'General Notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_note_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // ─── Save Button ─────────────────────────────────────────────────
              ElevatedButton(
                onPressed: _savePasture,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isEdit ? 'Save Changes' : 'Create Pasture',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
