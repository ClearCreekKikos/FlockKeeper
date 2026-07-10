// lib/data/models/incubation_batch_model.dart

enum IncubationMethod { incubator, broodyHen }
enum IncubationOutcome { hatched, failed, ongoing, unknown }

enum BreedingMethod { natural, ai, embryoTransfer }
enum BreedingOutcome { kidded, open, aborted, unknown }

class IncubationBatch {
  final int? id;
  final int? roosterId;
  final int flockId; // Source flock
  final String? roosterName;
  final String? flockName;
  final DateTime setDate;
  final DateTime? expectedHatchDate;
  final DateTime? actualHatchDate;
  final dynamic method; // Supports IncubationMethod and BreedingMethod
  final int eggsSet;
  final int fertileCount;
  final dynamic outcome; // Supports IncubationOutcome and BreedingOutcome
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Compatibility fields
  int? get buckId => roosterId;
  int get doeId => flockId;
  String? get buckName => roosterName;
  String? get doeName => flockName;
  DateTime get breedingDate => setDate;
  DateTime? get expectedKidDate => expectedHatchDate;
  DateTime? get actualKidDate => actualHatchDate;
  bool get confirmedPregnant => eggsSet > 0;
  
  BreedingMethod get breedingMethod {
    if (method is BreedingMethod) return method as BreedingMethod;
    return method == IncubationMethod.incubator ? BreedingMethod.ai : BreedingMethod.natural;
  }

  BreedingOutcome? get breedingOutcome {
    if (outcome is BreedingOutcome) return outcome as BreedingOutcome;
    switch (outcome) {
      case IncubationOutcome.hatched:
        return BreedingOutcome.kidded;
      case IncubationOutcome.failed:
        return BreedingOutcome.aborted;
      case IncubationOutcome.ongoing:
        return BreedingOutcome.unknown;
      default:
        return null;
    }
  }

  IncubationBatch({
    this.id,
    int? roosterId,
    int? buckId,
    int? flockId,
    int? doeId,
    String? roosterName,
    String? buckName,
    String? flockName,
    String? doeName,
    DateTime? setDate,
    DateTime? breedingDate,
    DateTime? expectedHatchDate,
    DateTime? expectedKidDate,
    DateTime? actualHatchDate,
    DateTime? actualKidDate,
    this.method = IncubationMethod.incubator,
    int eggsSet = 0,
    bool? confirmedPregnant,
    this.fertileCount = 0,
    this.outcome = IncubationOutcome.ongoing,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    DateTime? confirmationDate,
    String? confirmationMethod,
  })  : roosterId = roosterId ?? buckId,
        flockId = flockId ?? doeId ?? 0,
        roosterName = roosterName ?? buckName,
        flockName = flockName ?? doeName,
        setDate = setDate ?? breedingDate ?? DateTime.fromMillisecondsSinceEpoch(0),
        expectedHatchDate = expectedHatchDate ?? expectedKidDate,
        actualHatchDate = actualHatchDate ?? actualKidDate,
        eggsSet = eggsSet ?? (confirmedPregnant == true ? 1 : 0);

  factory IncubationBatch.fromMap(Map<String, dynamic> map) {
    return IncubationBatch(
      id: map['id'] as int?,
      roosterId: map['rooster_id'] as int? ?? map['buck_id'] as int?,
      flockId: map['flock_id'] as int? ?? map['doe_id'] as int? ?? 0,
      roosterName: map['rooster_name'] as String? ?? map['buck_name'] as String?,
      flockName: map['flock_name'] as String? ?? map['doe_name'] as String?,
      setDate: _parseDate(map['set_date'] as String? ?? map['breeding_date'] as String) ?? DateTime.now(),
      expectedHatchDate: _parseDate(map['expected_hatch_date'] as String? ?? map['expected_kid_date'] as String?),
      actualHatchDate: _parseDate(map['actual_hatch_date'] as String? ?? map['actual_kid_date'] as String?),
      method: _parseMethod(map['method'] as String?),
      eggsSet: map['eggs_set'] as int? ?? map['confirmed_pregnant'] as int? ?? 0,
      fertileCount: map['fertile_count'] as int? ?? 0,
      outcome: _parseOutcome(map['outcome'] as String?),
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['created_at'] as String?) ?? DateTime.now(),
      updatedAt: _parseDate(map['updated_at'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    String methodStr = 'incubator';
    if (method is IncubationMethod) {
      methodStr = _methodToString(method as IncubationMethod);
    } else if (method is BreedingMethod) {
      methodStr = method == BreedingMethod.natural ? 'natural' : 'ai';
    }

    String? outcomeStr;
    if (outcome is IncubationOutcome) {
      outcomeStr = _outcomeToString(outcome as IncubationOutcome);
    } else if (outcome is BreedingOutcome) {
      outcomeStr = outcome == BreedingOutcome.kidded ? 'hatched' : (outcome == BreedingOutcome.aborted ? 'failed' : 'ongoing');
    }

    return {
      if (id != null) 'id': id,
      'rooster_id': roosterId,
      'buck_id': roosterId,
      'flock_id': flockId,
      'doe_id': flockId,
      'rooster_name': roosterName,
      'buck_name': roosterName,
      'flock_name': flockName,
      'doe_name': flockName,
      'set_date': setDate.toIso8601String(),
      'breeding_date': setDate.toIso8601String(),
      'expected_hatch_date': expectedHatchDate?.toIso8601String(),
      'expected_kid_date': expectedHatchDate?.toIso8601String(),
      'actual_hatch_date': actualHatchDate?.toIso8601String(),
      'actual_kid_date': actualHatchDate?.toIso8601String(),
      'method': methodStr,
      'eggs_set': eggsSet,
      'confirmed_pregnant': eggsSet > 0 ? 1 : 0,
      'fertile_count': fertileCount,
      'outcome': outcomeStr,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  IncubationBatch copyWith({
    int? id,
    int? roosterId,
    int? buckId,
    int? flockId,
    int? doeId,
    String? roosterName,
    String? buckName,
    String? flockName,
    String? doeName,
    DateTime? setDate,
    DateTime? breedingDate,
    DateTime? expectedHatchDate,
    DateTime? expectedKidDate,
    DateTime? actualHatchDate,
    DateTime? actualKidDate,
    dynamic method,
    int? eggsSet,
    bool? confirmedPregnant,
    int? fertileCount,
    dynamic outcome,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? confirmationDate,
    String? confirmationMethod,
  }) {
    return IncubationBatch(
      id: id ?? this.id,
      roosterId: roosterId ?? buckId ?? this.roosterId,
      flockId: flockId ?? doeId ?? this.flockId,
      roosterName: roosterName ?? buckName ?? this.roosterName,
      flockName: flockName ?? doeName ?? this.flockName,
      setDate: setDate ?? breedingDate ?? this.setDate,
      expectedHatchDate: expectedHatchDate ?? expectedKidDate ?? this.expectedHatchDate,
      actualHatchDate: actualHatchDate ?? actualKidDate ?? this.actualHatchDate,
      method: method ?? this.method,
      eggsSet: eggsSet ?? this.eggsSet,
      fertileCount: fertileCount ?? this.fertileCount,
      outcome: outcome ?? this.outcome,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      confirmedPregnant: confirmedPregnant,
    );
  }

  int? get daysUntilHatch {
    if (expectedHatchDate == null) return null;
    return expectedHatchDate!.difference(DateTime.now()).inDays;
  }

  int? get daysUntilKidding => daysUntilHatch;

  bool get isActiveIncubation {
    return actualHatchDate == null && (outcome == IncubationOutcome.ongoing || outcome == null);
  }

  bool get isHatchingSoon {
    final days = daysUntilHatch;
    if (days == null) return false;
    return days >= 0 && days <= 3 && actualHatchDate == null;
  }

  bool get isOverdue {
    final days = daysUntilHatch;
    if (days == null) return false;
    return days < 0 && actualHatchDate == null;
  }

  bool get isKiddingSoon => isHatchingSoon;

  bool get isActivePregnancy => isActiveIncubation;

  DateTime? get confirmationDate => null;
  String? get confirmationMethod => null;

  String get methodDisplay {
    if (method is BreedingMethod) {
      return method == BreedingMethod.natural ? 'Natural' : 'Artificial Insemination';
    }
    switch (method) {
      case IncubationMethod.incubator: return 'Incubator';
      case IncubationMethod.broodyHen: return 'Broody Hen';
      default: return 'Incubator';
    }
  }

  static DateTime calculateExpectedHatchDate(DateTime setDate) {
    return setDate.add(const Duration(days: 21));
  }

  static DateTime calculateExpectedKidDate(DateTime breedingDate) {
    return breedingDate.add(const Duration(days: 150));
  }

  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  static IncubationMethod _parseMethod(String? str) {
    switch (str?.toLowerCase()) {
      case 'broody_hen':
      case 'broodyhen':
      case 'natural':
        return IncubationMethod.broodyHen;
      default:
        return IncubationMethod.incubator;
    }
  }

  static String _methodToString(IncubationMethod method) {
    switch (method) {
      case IncubationMethod.incubator: return 'incubator';
      case IncubationMethod.broodyHen: return 'broody_hen';
    }
  }

  static IncubationOutcome? _parseOutcome(String? str) {
    switch (str?.toLowerCase()) {
      case 'hatched':
      case 'kidded':
        return IncubationOutcome.hatched;
      case 'failed':
      case 'aborted':
        return IncubationOutcome.failed;
      case 'ongoing':
        return IncubationOutcome.ongoing;
      case 'unknown':
        return IncubationOutcome.unknown;
      default:
        return null;
    }
  }

  static String _outcomeToString(IncubationOutcome outcome) {
    switch (outcome) {
      case IncubationOutcome.hatched: return 'hatched';
      case IncubationOutcome.failed: return 'failed';
      case IncubationOutcome.ongoing: return 'ongoing';
      case IncubationOutcome.unknown: return 'unknown';
    }
  }
}

typedef BreedingEvent = IncubationBatch;
