import '../../shared/utils/date_helper.dart';

enum HealthRecordType {
  famacha,
  bcs,
  vaccination,
  deworming,
  antibiotic,
  supplement,
  labTest,
  grooming,
  pregnancyCheck,
  illness,
  injury,
  surgery,
  vetVisit,
  other
}

class HealthRecord {
  final int? id;
  final int animalId;
  final HealthRecordType recordType;
  final DateTime recordDate;
  final String? diagnosis; // Used for illness/injury
  final String? treatment; // Product name
  final String? dosage;
  final String? labName;
  final String? labReferenceNumber;
  final String? administrator;
  final int? famachaScore; // 1-5
  final double? bcsScore; // 1-5
  final int? withdrawalDays;
  final DateTime? withdrawalDate;
  final DateTime? followUpDate;
  final double? cost;
  final String? notes;
  final bool resolved;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HealthRecord({
    this.id,
    required this.animalId,
    required this.recordType,
    required this.recordDate,
    this.diagnosis,
    this.treatment,
    this.dosage,
    this.labName,
    this.labReferenceNumber,
    this.administrator,
    this.famachaScore,
    this.bcsScore,
    this.withdrawalDays,
    this.withdrawalDate,
    this.followUpDate,
    this.cost,
    this.notes,
    this.resolved = true,
    this.createdAt,
    this.updatedAt,
  });

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int,
      recordType: HealthRecordType.values.firstWhere(
          (e) => e.name == map['record_type']),
      recordDate: parseDateTimeSafe(map['record_date']),
      diagnosis: map['diagnosis'],
      treatment: map['treatment'],
      dosage: map['dosage'],
      labName: map['lab_name'],
      labReferenceNumber: map['lab_reference_number'],
      administrator: map['administrator'],
      famachaScore: map['famacha_score'],
      bcsScore: (map['bcs_score'] as num?)?.toDouble(),
      withdrawalDays: map['withdrawal_days'],
      withdrawalDate: map['withdrawal_date'] != null 
          ? parseDateTimeSafe(map['withdrawal_date']) : null,
      followUpDate: map['follow_up_date'] != null 
          ? parseDateTimeSafe(map['follow_up_date']) : null,
      cost: (map['cost'] as num?)?.toDouble(),
      notes: map['notes'],
      resolved: map['resolved'] == 1,
      createdAt: map['created_at'] != null ? parseDateTimeSafe(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? parseDateTimeSafe(map['updated_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'animal_id': animalId,
      'record_type': recordType.name,
      'record_date': recordDate.toIso8601String(),
      'diagnosis': diagnosis,
      'treatment': treatment,
      'dosage': dosage,
      'lab_name': labName,
      'lab_reference_number': labReferenceNumber,
      'administrator': administrator,
      'famacha_score': famachaScore,
      'bcs_score': bcsScore,
      'withdrawal_days': withdrawalDays,
      'withdrawal_date': withdrawalDate?.toIso8601String(),
      'follow_up_date': followUpDate?.toIso8601String(),
      'cost': cost,
      'notes': notes,
      'resolved': resolved ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  HealthRecord copyWith({
    int? id,
    int? animalId,
    HealthRecordType? recordType,
    DateTime? recordDate,
    String? diagnosis,
    String? treatment,
    String? dosage,
    String? labName,
    String? labReferenceNumber,
    String? administrator,
    int? famachaScore,
    double? bcsScore,
    int? withdrawalDays,
    DateTime? withdrawalDate,
    DateTime? followUpDate,
    double? cost,
    String? notes,
    bool? resolved,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      recordType: recordType ?? this.recordType,
      recordDate: recordDate ?? this.recordDate,
      diagnosis: diagnosis ?? this.diagnosis,
      treatment: treatment ?? this.treatment,
      dosage: dosage ?? this.dosage,
      labName: labName ?? this.labName,
      labReferenceNumber: labReferenceNumber ?? this.labReferenceNumber,
      administrator: administrator ?? this.administrator,
      famachaScore: famachaScore ?? this.famachaScore,
      bcsScore: bcsScore ?? this.bcsScore,
      withdrawalDays: withdrawalDays ?? this.withdrawalDays,
      withdrawalDate: withdrawalDate ?? this.withdrawalDate,
      followUpDate: followUpDate ?? this.followUpDate,
      cost: cost ?? this.cost,
      notes: notes ?? this.notes,
      resolved: resolved ?? this.resolved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}