// lib/data/models/egg_collection_model.dart

import '../../shared/utils/date_helper.dart';

class EggCollection {
  final int? id;
  final int animalId; // Can refer to a Flock or individual Hen
  final DateTime collectionDate;
  final String? session; // 'AM', 'PM', 'Overall'
  final int eggCount;
  final int brokenCount;
  final double? averageWeightG;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  EggCollection({
    this.id,
    required this.animalId,
    DateTime? collectionDate,
    DateTime? milkingDate,
    this.session,
    int? eggCount,
    double? yieldLbs,
    this.brokenCount = 0,
    double? averageWeightG,
    double? fatPercent,
    double? proteinPercent,
    int? scc,
    this.notes,
    this.createdAt,
    this.updatedAt,
  })  : collectionDate = collectionDate ?? milkingDate ?? DateTime.fromMillisecondsSinceEpoch(0),
        eggCount = eggCount ?? (yieldLbs != null ? yieldLbs.toInt() : 0),
        averageWeightG = averageWeightG ?? fatPercent;

  // Compatibility properties
  DateTime get milkingDate => collectionDate;
  double get yieldLbs => eggCount.toDouble();
  double? get fatPercent => averageWeightG;
  double? get proteinPercent => null;
  int? get scc => null;

  factory EggCollection.fromMap(Map<String, dynamic> map) {
    return EggCollection(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      collectionDate: parseDateTimeSafe(map['collection_date'] ?? map['milking_date']),
      session: map['session'] as String?,
      eggCount: map['egg_count'] as int? ?? (map['yield_lbs'] as num?)?.toInt() ?? 0,
      brokenCount: map['broken_count'] as int? ?? 0,
      averageWeightG: (map['average_weight_g'] as num?)?.toDouble() ?? (map['fat_percent'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null ? parseDateTimeSafe(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? parseDateTimeSafe(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'animal_id': animalId,
      'collection_date': collectionDate.toIso8601String(),
      'milking_date': collectionDate.toIso8601String(), // Retained for compatibility
      'session': session,
      'egg_count': eggCount,
      'yield_lbs': eggCount.toDouble(), // Retained for compatibility
      'broken_count': brokenCount,
      'average_weight_g': averageWeightG,
      'fat_percent': averageWeightG, // Retained for compatibility
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  EggCollection copyWith({
    int? id,
    int? animalId,
    DateTime? collectionDate,
    String? session,
    int? eggCount,
    int? brokenCount,
    double? averageWeightG,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EggCollection(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      collectionDate: collectionDate ?? this.collectionDate,
      session: session ?? this.session,
      eggCount: eggCount ?? this.eggCount,
      brokenCount: brokenCount ?? this.brokenCount,
      averageWeightG: averageWeightG ?? this.averageWeightG,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

typedef MilkingRecord = EggCollection;
