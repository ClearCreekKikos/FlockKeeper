import '../../shared/utils/date_helper.dart';

class MeatRecord {
  final int? id;
  final int animalId;
  final DateTime recordDate;
  final DateTime? slaughterDate;
  final double? liveWeightLbs;
  final double? hangingWeightLbs;
  final double? dressingPercent;
  final double? cutYieldLbs;
  final String? yieldGrade;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MeatRecord({
    this.id,
    required this.animalId,
    required this.recordDate,
    this.slaughterDate,
    this.liveWeightLbs,
    this.hangingWeightLbs,
    this.dressingPercent,
    this.cutYieldLbs,
    this.yieldGrade,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory MeatRecord.fromMap(Map<String, dynamic> map) {
    return MeatRecord(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      recordDate: parseDateTimeSafe(map['record_date']),
      slaughterDate: map['slaughter_date'] != null ? parseDateTimeSafe(map['slaughter_date']) : null,
      liveWeightLbs: (map['live_weight_lbs'] as num?)?.toDouble(),
      hangingWeightLbs: (map['hanging_weight_lbs'] as num?)?.toDouble(),
      dressingPercent: (map['dressing_percent'] as num?)?.toDouble(),
      cutYieldLbs: (map['cut_yield_lbs'] as num?)?.toDouble(),
      yieldGrade: map['yield_grade'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null ? parseDateTimeSafe(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? parseDateTimeSafe(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'animal_id': animalId,
      'record_date': recordDate.toIso8601String(),
      'slaughter_date': slaughterDate?.toIso8601String(),
      'live_weight_lbs': liveWeightLbs,
      'hanging_weight_lbs': hangingWeightLbs,
      'dressing_percent': dressingPercent,
      'cut_yield_lbs': cutYieldLbs,
      'yield_grade': yieldGrade,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  MeatRecord copyWith({
    int? id,
    int? animalId,
    DateTime? recordDate,
    DateTime? slaughterDate,
    double? liveWeightLbs,
    double? hangingWeightLbs,
    double? dressingPercent,
    double? cutYieldLbs,
    String? yieldGrade,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MeatRecord(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      recordDate: recordDate ?? this.recordDate,
      slaughterDate: slaughterDate ?? this.slaughterDate,
      liveWeightLbs: liveWeightLbs ?? this.liveWeightLbs,
      hangingWeightLbs: hangingWeightLbs ?? this.hangingWeightLbs,
      dressingPercent: dressingPercent ?? this.dressingPercent,
      cutYieldLbs: cutYieldLbs ?? this.cutYieldLbs,
      yieldGrade: yieldGrade ?? this.yieldGrade,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
