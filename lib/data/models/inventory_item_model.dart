// lib/data/models/inventory_item_model.dart

import '../../shared/utils/date_helper.dart';

/// Categories for ranch supply inventory items.
enum InventoryCategory {
  healthMedical,
  hoofGrooming,
  kidding,
  workingChute,
  cleaning,
  feedNutrition,
  fencingPasture,
  generalTools,
  paperwork,
}

class InventoryItem {
  final int? id;
  final String name;
  final InventoryCategory category;
  final String unit; // e.g. "bottles", "boxes", "each", "rolls"
  final double currentQuantity;
  final double minimumQuantity;
  final double costPerUnit;
  final int? supplierId;
  final String? supplierName; // denormalized for display convenience
  final DateTime? expirationDate;
  final String? barcode;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InventoryItem({
    this.id,
    required this.name,
    required this.category,
    this.unit = 'each',
    this.currentQuantity = 0,
    this.minimumQuantity = 1,
    this.costPerUnit = 0.0,
    this.supplierId,
    this.supplierName,
    this.expirationDate,
    this.barcode,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Computed total value = cost per unit × current quantity.
  double get totalValue => costPerUnit * currentQuantity;

  /// Whether this item is at or below its minimum stock level.
  bool get isLowStock =>
      minimumQuantity > 0 && currentQuantity <= minimumQuantity;

  /// Whether this item is completely out of stock.
  bool get isOutOfStock => currentQuantity <= 0;

  /// Whether this item has an expiration date that is within `days` from now.
  bool isExpiringSoon({int days = 30}) {
    if (expirationDate == null) return false;
    return expirationDate!.difference(DateTime.now()).inDays <= days;
  }

  /// Whether this item is expired.
  bool get isExpired {
    if (expirationDate == null) return false;
    return expirationDate!.isBefore(DateTime.now());
  }

  // ─── Serialisation ──────────────────────────────────────────────────────

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: _parseCategory(map['category'] as String?),
      unit: (map['unit'] as String?) ?? 'each',
      currentQuantity: (map['current_quantity'] as num?)?.toDouble() ?? 0,
      minimumQuantity: (map['minimum_quantity'] as num?)?.toDouble() ?? 1,
      costPerUnit: (map['cost_per_unit'] as num?)?.toDouble() ?? 0.0,
      supplierId: map['supplier_id'] as int?,
      supplierName: map['supplier_name'] as String?,
      expirationDate: map['expiration_date'] != null
          ? parseDateTimeSafe(map['expiration_date'])
          : null,
      barcode: map['barcode'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int?) != 0,
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
      'category': _categoryToString(category),
      'unit': unit,
      'current_quantity': currentQuantity,
      'minimum_quantity': minimumQuantity,
      'cost_per_unit': costPerUnit,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'expiration_date': expirationDate?.toIso8601String(),
      'barcode': barcode,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  InventoryItem copyWith({
    int? id,
    String? name,
    InventoryCategory? category,
    String? unit,
    double? currentQuantity,
    double? minimumQuantity,
    double? costPerUnit,
    int? supplierId,
    String? supplierName,
    DateTime? expirationDate,
    String? barcode,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      minimumQuantity: minimumQuantity ?? this.minimumQuantity,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      expirationDate: expirationDate ?? this.expirationDate,
      barcode: barcode ?? this.barcode,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }


  // ─── Helpers ────────────────────────────────────────────────────────────

  static InventoryCategory _parseCategory(String? s) {
    switch (s) {
      case 'health_medical':
        return InventoryCategory.healthMedical;
      case 'hoof_grooming':
        return InventoryCategory.hoofGrooming;
      case 'kidding':
        return InventoryCategory.kidding;
      case 'working_chute':
        return InventoryCategory.workingChute;
      case 'cleaning':
        return InventoryCategory.cleaning;
      case 'feed_nutrition':
        return InventoryCategory.feedNutrition;
      case 'fencing_pasture':
        return InventoryCategory.fencingPasture;
      case 'general_tools':
        return InventoryCategory.generalTools;
      case 'paperwork':
        return InventoryCategory.paperwork;
      default:
        return InventoryCategory.generalTools;
    }
  }

  static String _categoryToString(InventoryCategory cat) {
    switch (cat) {
      case InventoryCategory.healthMedical:
        return 'health_medical';
      case InventoryCategory.hoofGrooming:
        return 'hoof_grooming';
      case InventoryCategory.kidding:
        return 'kidding';
      case InventoryCategory.workingChute:
        return 'working_chute';
      case InventoryCategory.cleaning:
        return 'cleaning';
      case InventoryCategory.feedNutrition:
        return 'feed_nutrition';
      case InventoryCategory.fencingPasture:
        return 'fencing_pasture';
      case InventoryCategory.generalTools:
        return 'general_tools';
      case InventoryCategory.paperwork:
        return 'paperwork';
    }
  }

  /// Human‑readable label for a category.
  static String categoryLabel(InventoryCategory cat) {
    switch (cat) {
      case InventoryCategory.healthMedical:
        return 'Health & Medical';
      case InventoryCategory.hoofGrooming:
        return 'Hoof & Grooming';
      case InventoryCategory.kidding:
        return 'Kidding Supplies';
      case InventoryCategory.workingChute:
        return 'Working / Chute Day';
      case InventoryCategory.cleaning:
        return 'Cleaning & Sanitation';
      case InventoryCategory.feedNutrition:
        return 'Feed & Nutrition';
      case InventoryCategory.fencingPasture:
        return 'Fencing & Pasture';
      case InventoryCategory.generalTools:
        return 'General Ranch Tools';
      case InventoryCategory.paperwork:
        return 'Paperwork & Admin';
    }
  }

  /// Icon name string for UI (mapped in the screen layer).
  static String categoryIcon(InventoryCategory cat) {
    switch (cat) {
      case InventoryCategory.healthMedical:
        return 'medical_services';
      case InventoryCategory.hoofGrooming:
        return 'content_cut';
      case InventoryCategory.kidding:
        return 'child_friendly';
      case InventoryCategory.workingChute:
        return 'construction';
      case InventoryCategory.cleaning:
        return 'cleaning_services';
      case InventoryCategory.feedNutrition:
        return 'restaurant';
      case InventoryCategory.fencingPasture:
        return 'fence';
      case InventoryCategory.generalTools:
        return 'build';
      case InventoryCategory.paperwork:
        return 'description';
    }
  }
}
