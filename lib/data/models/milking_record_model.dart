import '../../shared/utils/date_helper.dart';

class MilkingRecord {
  final int? id;
  final int animalId;
  final DateTime milkingDate;
  final String? session; // 'AM', 'PM', 'Overall'
  final double yieldLbs;
  final double? fatPercent;
  final double? proteinPercent;
  final int? scc;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MilkingRecord({
    this.id,
    required this.animalId,
    required this.milkingDate,
    this.session,
    required this.yieldLbs,
    this.fatPercent,
    this.proteinPercent,
    this.scc,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory MilkingRecord.fromMap(Map<String, dynamic> map) {
    return MilkingRecord(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      milkingDate: parseDateTimeSafe(map['milking_date']),
      session: map['session'] as String?,
      yieldLbs: (map['yield_lbs'] as num).toDouble(),
      fatPercent: (map['fat_percent'] as num?)?.toDouble(),
      proteinPercent: (map['protein_percent'] as num?)?.toDouble(),
      scc: map['scc'] as int?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null ? parseDateTimeSafe(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? parseDateTimeSafe(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'animal_id': animalId,
      'milking_date': milkingDate.toIso8601String(),
      'session': session,
      'yield_lbs': yieldLbs,
      'fat_percent': fatPercent,
      'protein_percent': proteinPercent,
      'scc': scc,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  MilkingRecord copyWith({
    int? id,
    int? animalId,
    DateTime? milkingDate,
    String? session,
    double? yieldLbs,
    double? fatPercent,
    double? proteinPercent,
    int? scc,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MilkingRecord(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      milkingDate: milkingDate ?? this.milkingDate,
      session: session ?? this.session,
      yieldLbs: yieldLbs ?? this.yieldLbs,
      fatPercent: fatPercent ?? this.fatPercent,
      proteinPercent: proteinPercent ?? this.proteinPercent,
      scc: scc ?? this.scc,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
