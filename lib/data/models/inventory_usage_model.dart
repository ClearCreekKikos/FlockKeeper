// lib/data/models/inventory_usage_model.dart

import '../../shared/utils/date_helper.dart';

/// Records a single usage event for an inventory item (batch usage logging).
class InventoryUsage {
  final int? id;
  final int inventoryItemId;
  final double quantityUsed;
  final DateTime usageDate;
  final String? notes;
  final DateTime? createdAt;

  const InventoryUsage({
    this.id,
    required this.inventoryItemId,
    required this.quantityUsed,
    required this.usageDate,
    this.notes,
    this.createdAt,
  });

  factory InventoryUsage.fromMap(Map<String, dynamic> map) {
    return InventoryUsage(
      id: map['id'] as int?,
      inventoryItemId: map['inventory_item_id'] as int,
      quantityUsed: (map['quantity_used'] as num).toDouble(),
      usageDate: parseDateTimeSafe(map['usage_date']),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? parseDateTimeSafe(map['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'inventory_item_id': inventoryItemId,
      'quantity_used': quantityUsed,
      'usage_date': usageDate.toIso8601String(),
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  InventoryUsage copyWith({
    int? id,
    int? inventoryItemId,
    double? quantityUsed,
    DateTime? usageDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return InventoryUsage(
      id: id ?? this.id,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      quantityUsed: quantityUsed ?? this.quantityUsed,
      usageDate: usageDate ?? this.usageDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
