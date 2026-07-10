// lib/data/models/pasture_model.dart

import 'dart:convert';
import 'package:latlong2/latlong.dart';

enum PastureStatus { available, occupied, resting, maintenance }

class Pasture {
final int? id;
final String name;
final double? acreage;
final String? description;
final String? forageType;
final String? waterSource;
final String? fencingType;
final int? carryingCapacity;
final int currentAnimalCount;
final PastureStatus status;
final DateTime? lastGrazedDate;
final DateTime? availableDate;
final int restDaysTarget;
final String? notes;
final List<LatLng>? boundaryPolygon;
final DateTime createdAt;
final DateTime updatedAt;

const Pasture({
this.id,
required this.name,
this.acreage,
this.description,
this.forageType,
this.waterSource,
this.fencingType,
this.carryingCapacity,
this.currentAnimalCount = 0,
this.status = PastureStatus.available,
this.lastGrazedDate,
this.availableDate,
this.restDaysTarget = 30,
this.notes,
this.boundaryPolygon,
required this.createdAt,
required this.updatedAt,
});

factory Pasture.fromMap(Map<String, dynamic> map) {
return Pasture(
id: map['id'] as int?,
name: map['name'] as String,
acreage: map['acreage'] != null ? (map['acreage'] as num).toDouble() : null,
description: map['description'] as String?,
forageType: map['forage_type'] as String?,
waterSource: map['water_source'] as String?,
fencingType: map['fencing_type'] as String?,
carryingCapacity: map['carrying_capacity'] as int?,
currentAnimalCount: map['current_animal_count'] as int? ?? 0,
status: _parseStatus(map['status'] as String?),
lastGrazedDate: _parseDate(map['last_grazed_date'] as String?),
availableDate: _parseDate(map['available_date'] as String?),
restDaysTarget: map['rest_days_target'] as int? ?? 30,
notes: map['notes'] as String?,
boundaryPolygon: _parsePolygon(map['boundary_polygon'] as String?),
createdAt: _parseDate(map['created_at'] as String?) ?? DateTime.now(),
updatedAt: _parseDate(map['updated_at'] as String?) ?? DateTime.now(),
);
}

Map<String, dynamic> toMap() {
return {
if (id != null) 'id': id,
'name': name,
'acreage': acreage,
'description': description,
'forage_type': forageType,
'water_source': waterSource,
'fencing_type': fencingType,
'carrying_capacity': carryingCapacity,
'current_animal_count': currentAnimalCount,
'status': _statusToString(status),
'last_grazed_date': lastGrazedDate?.toIso8601String(),
'available_date': availableDate?.toIso8601String(),
'rest_days_target': restDaysTarget,
'notes': notes,
'boundary_polygon': boundaryPolygon != null
    ? jsonEncode(boundaryPolygon!.map((p) => [p.latitude, p.longitude]).toList())
    : null,
'created_at': createdAt.toIso8601String(),
'updated_at': updatedAt.toIso8601String(),
};
}

Pasture copyWith({
int? id,
String? name,
double? acreage,
String? description,
String? forageType,
String? waterSource,
String? fencingType,
int? carryingCapacity,
int? currentAnimalCount,
PastureStatus? status,
DateTime? lastGrazedDate,
DateTime? availableDate,
int? restDaysTarget,
String? notes,
List<LatLng>? boundaryPolygon,
DateTime? createdAt,
DateTime? updatedAt,
}) {
    return Pasture(
      id: id ?? this.id,
      name: name ?? this.name,
      acreage: acreage ?? this.acreage,
      description: description ?? this.description,
      forageType: forageType ?? this.forageType,
      waterSource: waterSource ?? this.waterSource,
      fencingType: fencingType ?? this.fencingType,
      carryingCapacity: carryingCapacity ?? this.carryingCapacity,
      currentAnimalCount: currentAnimalCount ?? this.currentAnimalCount,
      status: status ?? this.status,
      lastGrazedDate: lastGrazedDate ?? this.lastGrazedDate,
      availableDate: availableDate ?? this.availableDate,
      restDaysTarget: restDaysTarget ?? this.restDaysTarget,
      notes: notes ?? this.notes,
      boundaryPolygon: boundaryPolygon ?? this.boundaryPolygon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
}

// ─── Utility Getters ──────────────────────────────────────────────────────

bool get isAvailable => status == PastureStatus.available;

bool get isOverstocked {
  if (carryingCapacity == null) return false;
  return currentAnimalCount > carryingCapacity!;
}

int? get daysSinceLastGrazed {
  if (lastGrazedDate == null) return null;
  return DateTime.now().difference(lastGrazedDate!).inDays;
}

bool get isReadyToGraze {
  if (availableDate == null) return true;
  return DateTime.now().isAfter(availableDate!);
}

String get statusDisplay {
  switch (status) {
    case PastureStatus.available: return 'Available';
    case PastureStatus.occupied: return 'Occupied';
    case PastureStatus.resting: return 'Resting';
    case PastureStatus.maintenance: return 'Maintenance';
  }
}

// ─── Private Helpers ──────────────────────────────────────────────────────
static DateTime? _parseDate(String? s) {
  if (s == null || s.isEmpty) return null;
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

static PastureStatus _parseStatus(String? s) {
  switch (s?.toLowerCase()) {
    case 'occupied': return PastureStatus.occupied;
    case 'resting': return PastureStatus.resting;
    case 'maintenance': return PastureStatus.maintenance;
    default: return PastureStatus.available;
  }
}

static List<LatLng>? _parsePolygon(String? jsonStr) {
  if (jsonStr == null || jsonStr.isEmpty) return null;
  try {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((item) {
      final point = item as List<dynamic>;
      return LatLng((point[0] as num).toDouble(), (point[1] as num).toDouble());
    }).toList();
  } catch (_) {
    return null;
  }
}

static String _statusToString(PastureStatus status) {
  switch (status) {
    case PastureStatus.available: return 'available';
    case PastureStatus.occupied: return 'occupied';
    case PastureStatus.resting: return 'resting';
    case PastureStatus.maintenance: return 'maintenance';
  }
}
}
