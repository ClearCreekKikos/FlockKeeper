// lib/data/models/supplier_model.dart

import '../../shared/utils/date_helper.dart';

/// A supply vendor / supplier (e.g. Tractor Supply, Premier1, Jeffers).
class Supplier {
  final int? id;
  final String name;
  final String? contactInfo;
  final String? website;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Supplier({
    this.id,
    required this.name,
    this.contactInfo,
    this.website,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String,
      contactInfo: map['contact_info'] as String?,
      website: map['website'] as String?,
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
      'name': name,
      'contact_info': contactInfo,
      'website': website,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? contactInfo,
    String? website,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactInfo: contactInfo ?? this.contactInfo,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
