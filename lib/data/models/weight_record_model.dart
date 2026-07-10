import '../../shared/utils/date_helper.dart';

class WeightRecord {
  final int? id;
  final int animalId;
  final double weightLbs;
  final DateTime weighDate;
  final String? notes;
  final DateTime? createdAt;

  const WeightRecord({
    this.id,
    required this.animalId,
    required this.weightLbs,
    required this.weighDate,
    this.notes,
    this.createdAt,
  });

  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    return WeightRecord(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      weightLbs: (map['weight_lbs'] as num).toDouble(),
      weighDate: parseDateTimeSafe(map['weigh_date']),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? parseDateTimeSafe(map['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'animal_id': animalId,
      'weight_lbs': weightLbs,
      'weigh_date': weighDate.toIso8601String(),
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  WeightRecord copyWith({
    int? id,
    int? animalId,
    double? weightLbs,
    DateTime? weighDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return WeightRecord(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      weightLbs: weightLbs ?? this.weightLbs,
      weighDate: weighDate ?? this.weighDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}