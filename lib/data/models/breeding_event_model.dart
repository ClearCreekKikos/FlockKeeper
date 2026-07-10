// lib/data/models/breeding_event_model.dart

enum BreedingMethod { natural, ai, embryoTransfer }
enum BreedingOutcome { kidded, open, aborted, unknown }

class BreedingEvent {
  final int? id;
  final int? buckId;
  final int doeId;
  final String? buckName;
  final String? doeName;
  final DateTime breedingDate;
  final DateTime? expectedKidDate;
  final DateTime? actualKidDate;
  final BreedingMethod method;
  final bool confirmedPregnant;
  final DateTime? confirmationDate;
  final String? confirmationMethod;
  final BreedingOutcome? outcome;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BreedingEvent({
    this.id,
    this.buckId,
    required this.doeId,
    this.buckName,
    this.doeName,
    required this.breedingDate,
    this.expectedKidDate,
    this.actualKidDate,
    this.method = BreedingMethod.natural,
    this.confirmedPregnant = false,
    this.confirmationDate,
    this.confirmationMethod,
    this.outcome,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BreedingEvent.fromMap(Map<String, dynamic> map) {
    return BreedingEvent(
      id: map['id'] as int?,
      buckId: map['buck_id'] as int?,
      doeId: map['doe_id'] as int,
      buckName: map['buck_name'] as String?,
      doeName: map['doe_name'] as String?,
      breedingDate: _parseDate(map['breeding_date'] as String) ?? DateTime.now(),
      expectedKidDate: _parseDate(map['expected_kid_date'] as String?),
      actualKidDate: _parseDate(map['actual_kid_date'] as String?),
      method: _parseMethod(map['method'] as String?),
      confirmedPregnant: (map['confirmed_pregnant'] as int? ?? 0) == 1,
      confirmationDate: _parseDate(map['confirmation_date'] as String?),
      confirmationMethod: map['confirmation_method'] as String?,
      outcome: _parseOutcome(map['outcome'] as String?),
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['created_at'] as String?) ?? DateTime.now(),
      updatedAt: _parseDate(map['updated_at'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'buck_id': buckId,
      'doe_id': doeId,
      'buck_name': buckName,
      'doe_name': doeName,
      'breeding_date': breedingDate.toIso8601String(),
      'expected_kid_date': expectedKidDate?.toIso8601String(),
      'actual_kid_date': actualKidDate?.toIso8601String(),
      'method': _methodToString(method),
      'confirmed_pregnant': confirmedPregnant ? 1 : 0,
      'confirmation_date': confirmationDate?.toIso8601String(),
      'confirmation_method': confirmationMethod,
      'outcome': outcome != null ? _outcomeToString(outcome!) : null,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BreedingEvent copyWith({
    int? id,
    int? buckId,
    int? doeId,
    String? buckName,
    String? doeName,
    DateTime? breedingDate,
    DateTime? expectedKidDate,
    DateTime? actualKidDate,
    BreedingMethod? method,
    bool? confirmedPregnant,
    DateTime? confirmationDate,
    String? confirmationMethod,
    BreedingOutcome? outcome,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BreedingEvent(
      id: id ?? this.id,
      buckId: buckId ?? this.buckId,
      doeId: doeId ?? this.doeId,
      buckName: buckName ?? this.buckName,
      doeName: doeName ?? this.doeName,
      breedingDate: breedingDate ?? this.breedingDate,
      expectedKidDate: expectedKidDate ?? this.expectedKidDate,
      actualKidDate: actualKidDate ?? this.actualKidDate,
      method: method ?? this.method,
      confirmedPregnant: confirmedPregnant ?? this.confirmedPregnant,
      confirmationDate: confirmationDate ?? this.confirmationDate,
      confirmationMethod: confirmationMethod ?? this.confirmationMethod,
      outcome: outcome ?? this.outcome,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ─── Utility Getters ──────────────────────────────────────────────────────

  /// Days remaining until expected kidding (negative if overdue)
  int? get daysUntilKidding {
    if (expectedKidDate == null) return null;
    return expectedKidDate!.difference(DateTime.now()).inDays;
  }

  /// Is this doe currently pregnant and not yet kidded?
  bool get isActivePregnancy {
    return confirmedPregnant && actualKidDate == null;
  }

  /// Is kidding due within the next 7 days?
  bool get isKiddingSoon {
    final days = daysUntilKidding;
    if (days == null) return false;
    return days >= 0 && days <= 7 && actualKidDate == null;
  }

  bool get isOverdue {
    final days = daysUntilKidding;
    if (days == null) return false;
    return days < 0 && actualKidDate == null;
  }

  String get methodDisplay {
    switch (method) {
      case BreedingMethod.natural: return 'Natural';
      case BreedingMethod.ai: return 'Artificial Insemination';
      case BreedingMethod.embryoTransfer: return 'Embryo Transfer';
    }
  }

  // ─── Static Helper: Calculate Expected Kidding Date ───────────────────────
  /// Kiko gestation averages ~150 days
  static DateTime calculateExpectedKidDate(
      DateTime breedingDate, {
        int gestationDays = 150,
      }) {
    return breedingDate.add(Duration(days: gestationDays));
  }

  // ─── Private Parsers ──────────────────────────────────────────────────────
  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  static BreedingMethod _parseMethod(String? str) {
    switch (str?.toLowerCase()) {
      case 'ai': return BreedingMethod.ai;
      case 'embryo_transfer': return BreedingMethod.embryoTransfer;
      default: return BreedingMethod.natural;
    }
  }

  static String _methodToString(BreedingMethod method) {
    switch (method) {
      case BreedingMethod.natural: return 'natural';
      case BreedingMethod.ai: return 'ai';
      case BreedingMethod.embryoTransfer: return 'embryo_transfer';
    }
  }

  static BreedingOutcome? _parseOutcome(String? str) {
    switch (str?.toLowerCase()) {
      case 'kidded': return BreedingOutcome.kidded;
      case 'open': return BreedingOutcome.open;
      case 'aborted': return BreedingOutcome.aborted;
      case 'unknown': return BreedingOutcome.unknown;
      default: return null;
    }
  }

  static String _outcomeToString(BreedingOutcome outcome) {
    switch (outcome) {
      case BreedingOutcome.kidded: return 'kidded';
      case BreedingOutcome.open: return 'open';
      case BreedingOutcome.aborted: return 'aborted';
      case BreedingOutcome.unknown: return 'unknown';
    }
  }
}
