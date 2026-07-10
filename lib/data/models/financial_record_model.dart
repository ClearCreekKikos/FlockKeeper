// lib/data/models/financial_record_model.dart

import '../../shared/utils/date_helper.dart';

class FinancialRecord {
  final int? id;
  final int? animalId;
  final DateTime recordDate;
  final String category; // 'purchase','sale','feed','medication','veterinary','equipment','pasture','registration','other'
  final String type; // 'income','expense'
  final double amount;
  final String? description;
  final String? vendorBuyer;
  final String? receiptNumber;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FinancialRecord({
    this.id,
    this.animalId,
    required this.recordDate,
    required this.category,
    required this.type,
    required this.amount,
    this.description,
    this.vendorBuyer,
    this.receiptNumber,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory FinancialRecord.fromMap(Map<String, dynamic> map) {
    return FinancialRecord(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int?,
      recordDate: parseDateTimeSafe(map['record_date']),
      category: map['category'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      vendorBuyer: map['vendor_buyer'] as String?,
      receiptNumber: map['receipt_number'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? parseDateTimeSafe(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? parseDateTimeSafe(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'animal_id': animalId,
      'record_date': recordDate.toIso8601String(),
      'category': category,
      'type': type,
      'amount': amount,
      'description': description,
      'vendor_buyer': vendorBuyer,
      'receipt_number': receiptNumber,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  FinancialRecord copyWith({
    int? id,
    int? animalId,
    DateTime? recordDate,
    String? category,
    String? type,
    double? amount,
    String? description,
    String? vendorBuyer,
    String? receiptNumber,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialRecord(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      recordDate: recordDate ?? this.recordDate,
      category: category ?? this.category,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      vendorBuyer: vendorBuyer ?? this.vendorBuyer,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
