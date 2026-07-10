// lib/data/models/hatch_record_model.dart

enum KidSex { doe, buck, unknown }
enum BirthType { single, twin, triplet, quad, other }
enum Presentation { normal, malpresentation, assisted }
enum SurvivalStatus {
  alive,
  diedAtBirth,
  diedWithin24h,
  diedWithinWeek,
  diedLater,
  sold
}

typedef HatchSurvival = SurvivalStatus;

class HatchRecord {
  final int? id;
  final int? batchId; // References IncubationBatch
  final int flockId; // Source flock
  final int? roosterId;
  final int? chickId; // If individual chick is tracked
  final String? chickName;
  final DateTime hatchDate;
  final int hatchOrder;
  final int chicksHatched; // Quantity hatched
  final double? birthWeightLbs;
  final KidSex sex;
  final SurvivalStatus survivalStatus;
  final String? notes;
  final DateTime createdAt;
  
  // Kidding compatibility fields
  final String? complications;
  final int? damConditionScore;
  final bool receivedColostrum;
  final bool bottleFed;
  final Presentation? _presentation;
  final BirthType? _birthType;

  // Compatibility properties
  int? get breedingEventId => batchId;
  int get doeId => flockId;
  int? get buckId => roosterId;
  int? get kidId => chickId;
  String? get kidName => chickName;
  DateTime get kiddingDate => hatchDate;
  int? get birthOrder => hatchOrder;
  int? get litterSize => chicksHatched;
  
  KidSex get sexCompatibility => sex;
  SurvivalStatus get survivalStatusCompatibility => survivalStatus;

  Presentation get presentation => _presentation ?? Presentation.normal;

  BirthType get birthType {
    if (_birthType != null) return _birthType!;
    return chicksHatched == 1 
        ? BirthType.single 
        : (chicksHatched == 2 
            ? BirthType.twin 
            : (chicksHatched == 3 
                ? BirthType.triplet 
                : (chicksHatched == 4 ? BirthType.quad : BirthType.other)));
  }

  HatchRecord({
    this.id,
    int? batchId,
    int? breedingEventId,
    int? flockId,
    int? doeId,
    int? roosterId,
    int? buckId,
    int? chickId,
    int? kidId,
    String? chickName,
    String? kidName,
    DateTime? hatchDate,
    DateTime? kiddingDate,
    int? hatchOrder,
    int? birthOrder,
    int? chicksHatched,
    int? litterSize,
    this.birthWeightLbs,
    KidSex sex = KidSex.unknown,
    SurvivalStatus survivalStatus = SurvivalStatus.alive,
    this.notes,
    required this.createdAt,
    this.complications,
    this.damConditionScore,
    this.receivedColostrum = false,
    this.bottleFed = false,
    Presentation? presentation,
    BirthType? birthType,
  })  : batchId = batchId ?? breedingEventId,
        flockId = flockId ?? doeId ?? 0,
        roosterId = roosterId ?? buckId,
        chickId = chickId ?? kidId,
        chickName = chickName ?? kidName,
        hatchDate = hatchDate ?? kiddingDate ?? DateTime.fromMillisecondsSinceEpoch(0),
        hatchOrder = hatchOrder ?? birthOrder ?? 1,
        chicksHatched = chicksHatched ?? litterSize ?? 1,
        sex = sex,
        survivalStatus = survivalStatus,
        _presentation = presentation,
        _birthType = birthType;

  factory HatchRecord.fromMap(Map<String, dynamic> map) {
    return HatchRecord(
      id: map['id'] as int?,
      batchId: map['batch_id'] as int? ?? map['breeding_event_id'] as int?,
      flockId: map['flock_id'] as int? ?? map['doe_id'] as int? ?? 0,
      roosterId: map['rooster_id'] as int? ?? map['buck_id'] as int?,
      chickId: map['chick_id'] as int? ?? map['kid_id'] as int?,
      chickName: map['chick_name'] as String? ?? map['kid_name'] as String?,
      hatchDate: _parseDate(map['hatch_date'] as String? ?? map['kidding_date'] as String) ?? DateTime.now(),
      hatchOrder: map['hatch_order'] as int? ?? map['birth_order'] as int? ?? 1,
      chicksHatched: map['chicks_hatched'] as int? ?? map['litter_size'] as int? ?? 1,
      birthWeightLbs: map['birth_weight_lbs'] != null ? (map['birth_weight_lbs'] as num).toDouble() : null,
      sex: _parseSex(map['sex'] as String?),
      survivalStatus: _parseSurvival(map['survival_status'] as String?),
      complications: map['complications'] as String?,
      damConditionScore: map['dam_condition_score'] as int?,
      receivedColostrum: (map['received_colostrum'] as int? ?? 0) == 1,
      bottleFed: (map['bottle_fed'] as int? ?? 0) == 1,
      presentation: _parsePresentation(map['presentation'] as String?),
      birthType: _parseBirthType(map['birth_type'] as String?),
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['created_at'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'batch_id': batchId,
      'breeding_event_id': batchId, // Retained for compatibility
      'flock_id': flockId,
      'doe_id': flockId, // Retained for compatibility
      'rooster_id': roosterId,
      'buck_id': roosterId, // Retained for compatibility
      'chick_id': chickId,
      'kid_id': chickId, // Retained for compatibility
      'chick_name': chickName,
      'kid_name': chickName, // Retained for compatibility
      'hatch_date': hatchDate.toIso8601String(),
      'kidding_date': hatchDate.toIso8601String(), // Retained for compatibility
      'hatch_order': hatchOrder,
      'birth_order': hatchOrder, // Retained for compatibility
      'chicks_hatched': chicksHatched,
      'litter_size': chicksHatched, // Retained for compatibility
      'birth_weight_lbs': birthWeightLbs,
      'sex': sex.name,
      'survival_status': survivalStatus.name,
      'complications': complications,
      'dam_condition_score': damConditionScore,
      'received_colostrum': receivedColostrum ? 1 : 0,
      'bottle_fed': bottleFed ? 1 : 0,
      'presentation': _presentation?.name,
      'birth_type': _birthType?.name,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  HatchRecord copyWith({
    int? id,
    int? batchId,
    int? breedingEventId,
    int? flockId,
    int? doeId,
    int? roosterId,
    int? buckId,
    int? chickId,
    int? kidId,
    String? chickName,
    String? kidName,
    DateTime? hatchDate,
    DateTime? kiddingDate,
    int? hatchOrder,
    int? birthOrder,
    int? chicksHatched,
    int? litterSize,
    double? birthWeightLbs,
    KidSex? sex,
    SurvivalStatus? survivalStatus,
    String? notes,
    DateTime? createdAt,
    String? complications,
    int? damConditionScore,
    bool? receivedColostrum,
    bool? bottleFed,
    Presentation? presentation,
    BirthType? birthType,
  }) {
    return HatchRecord(
      id: id ?? this.id,
      batchId: batchId ?? breedingEventId ?? this.batchId,
      flockId: flockId ?? doeId ?? this.flockId,
      roosterId: roosterId ?? buckId ?? this.roosterId,
      chickId: chickId ?? kidId ?? this.chickId,
      chickName: chickName ?? kidName ?? this.chickName,
      hatchDate: hatchDate ?? kiddingDate ?? this.hatchDate,
      hatchOrder: hatchOrder ?? birthOrder ?? this.hatchOrder,
      chicksHatched: chicksHatched ?? litterSize ?? this.chicksHatched,
      birthWeightLbs: birthWeightLbs ?? this.birthWeightLbs,
      sex: sex ?? this.sex,
      survivalStatus: survivalStatus ?? this.survivalStatus,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      complications: complications ?? this.complications,
      damConditionScore: damConditionScore ?? this.damConditionScore,
      receivedColostrum: receivedColostrum ?? this.receivedColostrum,
      bottleFed: bottleFed ?? this.bottleFed,
      presentation: presentation ?? this.presentation,
      birthType: birthType ?? this.birthType,
    );
  }

  bool get isAlive => survivalStatus == SurvivalStatus.alive ||
      survivalStatus == SurvivalStatus.sold;

  String get survivalDisplay {
    switch (survivalStatus) {
      case SurvivalStatus.alive: return 'Alive';
      case SurvivalStatus.diedAtBirth: return 'Died at Birth';
      case SurvivalStatus.diedWithin24h: return 'Died within 24h';
      case SurvivalStatus.diedWithinWeek: return 'Died within a Week';
      case SurvivalStatus.diedLater: return 'Died Later';
      case SurvivalStatus.sold: return 'Sold';
    }
  }

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static KidSex _parseSex(String? s) {
    switch (s?.toLowerCase()) {
      case 'doe':
      case 'female':
      case 'hen':
      case 'pullet':
        return KidSex.doe;
      case 'buck':
      case 'male':
      case 'rooster':
      case 'cockerel':
        return KidSex.buck;
      default:
        return KidSex.unknown;
    }
  }

  static SurvivalStatus _parseSurvival(String? s) {
    switch (s?.toLowerCase()) {
      case 'alive': return SurvivalStatus.alive;
      case 'died_at_birth': return SurvivalStatus.diedAtBirth;
      case 'died_within_24h': return SurvivalStatus.diedWithin24h;
      case 'died_within_week': return SurvivalStatus.diedWithinWeek;
      case 'died_later': return SurvivalStatus.diedLater;
      case 'sold': return SurvivalStatus.sold;
      default: return SurvivalStatus.alive;
    }
  }

  static Presentation? _parsePresentation(String? s) {
    switch (s?.toLowerCase()) {
      case 'normal': return Presentation.normal;
      case 'malpresentation': return Presentation.malpresentation;
      case 'assisted': return Presentation.assisted;
      default: return null;
    }
  }

  static BirthType? _parseBirthType(String? s) {
    switch (s?.toLowerCase()) {
      case 'single': return BirthType.single;
      case 'twin': return BirthType.twin;
      case 'triplet': return BirthType.triplet;
      case 'quad': return BirthType.quad;
      case 'other': return BirthType.other;
      default: return null;
    }
  }
}

typedef KiddingRecord = HatchRecord;
