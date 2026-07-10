// lib/data/models/kidding_record_model.dart

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

class KiddingRecord {
  final int? id;
  final int? breedingEventId;
  final int doeId;
  final int? buckId;
  final int? kidId;
  final String? kidName;
  final DateTime kiddingDate;
  final int? birthOrder;
  final int? litterSize;
  final double? birthWeightLbs;
  final KidSex sex;
  final BirthType? birthType;
  final Presentation? presentation;
  final SurvivalStatus survivalStatus;
  final bool receivedColostrum;
  final bool bottleFed;
  final int? damConditionScore;
  final String? complications;
  final String? notes;
  final DateTime createdAt;

  const KiddingRecord({
    this.id,
    this.breedingEventId,
    required this.doeId,
    this.buckId,
    this.kidId,
    this.kidName,
    required this.kiddingDate,
    this.birthOrder,
    this.litterSize,
    this.birthWeightLbs,
    this.sex = KidSex.unknown,
    this.birthType,
    this.presentation,
    this.survivalStatus = SurvivalStatus.alive,
    this.receivedColostrum = false,
    this.bottleFed = false,
    this.damConditionScore,
    this.complications,
    this.notes,
    required this.createdAt,
  });

  factory KiddingRecord.fromMap(Map<String, dynamic> map) {
    return KiddingRecord(
      id: map['id'] as int?,
      breedingEventId: map['breeding_event_id'] as int?,
      doeId: map['doe_id'] as int,
      buckId: map['buck_id'] as int?,
      kidId: map['kid_id'] as int?,
      kidName: map['kid_name'] as String?,
      kiddingDate: _parseDate(map['kidding_date'] as String) ?? DateTime.now(),
      birthOrder: map['birth_order'] as int?,
      litterSize: map['litter_size'] as int?,
      birthWeightLbs: map['birth_weight_lbs'] != null
          ? (map['birth_weight_lbs'] as num).toDouble()
          : null,
      sex: _parseSex(map['sex'] as String?),
      birthType: _parseBirthType(map['birth_type'] as String?),
      presentation: _parsePresentation(map['presentation'] as String?),
      survivalStatus: _parseSurvival(map['survival_status'] as String?),
      receivedColostrum: (map['received_colostrum'] as int? ?? 0) == 1,
      bottleFed: (map['bottle_fed'] as int? ?? 0) == 1,
      damConditionScore: map['dam_condition_score'] as int?,
      complications: map['complications'] as String?,
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['created_at'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'breeding_event_id': breedingEventId,
      'doe_id': doeId,
      'buck_id': buckId,
      'kid_id': kidId,
      'kid_name': kidName,
      'kidding_date': kiddingDate.toIso8601String(),
      'birth_order': birthOrder,
      'litter_size': litterSize,
      'birth_weight_lbs': birthWeightLbs,
      'sex': _sexToString(sex),
      'birth_type': birthType != null ? _birthTypeToString(birthType!) : null,
      'presentation':
      presentation != null ? _presentationToString(presentation!) : null,
      'survival_status': _survivalToString(survivalStatus),
      'received_colostrum': receivedColostrum ? 1 : 0,
      'bottle_fed': bottleFed ? 1 : 0,
      'dam_condition_score': damConditionScore,
      'complications': complications,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  KiddingRecord copyWith({
    int? id,
    int? breedingEventId,
    int? doeId,
    int? buckId,
    int? kidId,
    String? kidName,
    DateTime? kiddingDate,
    int? birthOrder,
    int? litterSize,
    double? birthWeightLbs,
    KidSex? sex,
    BirthType? birthType,
    Presentation? presentation,
    SurvivalStatus? survivalStatus,
    bool? receivedColostrum,
    bool? bottleFed,
    int? damConditionScore,
    String? complications,
    String? notes,
    DateTime? createdAt,
  }) {
    return KiddingRecord(
      id: id ?? this.id,
      breedingEventId: breedingEventId ?? this.breedingEventId,
      doeId: doeId ?? this.doeId,
      buckId: buckId ?? this.buckId,
      kidId: kidId ?? this.kidId,
      kidName: kidName ?? this.kidName,
      kiddingDate: kiddingDate ?? this.kiddingDate,
      birthOrder: birthOrder ?? this.birthOrder,
      litterSize: litterSize ?? this.litterSize,
      birthWeightLbs: birthWeightLbs ?? this.birthWeightLbs,
      sex: sex ?? this.sex,
      birthType: birthType ?? this.birthType,
      presentation: presentation ?? this.presentation,
      survivalStatus: survivalStatus ?? this.survivalStatus,
      receivedColostrum: receivedColostrum ?? this.receivedColostrum,
      bottleFed: bottleFed ?? this.bottleFed,
      damConditionScore: damConditionScore ?? this.damConditionScore,
      complications: complications ?? this.complications,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
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

  // ─── Private Parsers ──────────────────────────────────────────────────────
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
      case 'doe': return KidSex.doe;
      case 'buck': return KidSex.buck;
      default: return KidSex.unknown;
    }
  }

  static String _sexToString(KidSex s) {
    switch (s) {
      case KidSex.doe: return 'doe';
      case KidSex.buck: return 'buck';
      case KidSex.unknown: return 'unknown';
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

  static String _birthTypeToString(BirthType t) {
    switch (t) {
      case BirthType.single: return 'single';
      case BirthType.twin: return 'twin';
      case BirthType.triplet: return 'triplet';
      case BirthType.quad: return 'quad';
      case BirthType.other: return 'other';
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

  static String _presentationToString(Presentation p) {
    switch (p) {
      case Presentation.normal: return 'normal';
      case Presentation.malpresentation: return 'malpresentation';
      case Presentation.assisted: return 'assisted';
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

  static String _survivalToString(SurvivalStatus s) {
    switch (s) {
      case SurvivalStatus.alive: return 'alive';
      case SurvivalStatus.diedAtBirth: return 'died_at_birth';
      case SurvivalStatus.diedWithin24h: return 'died_within_24h';
      case SurvivalStatus.diedWithinWeek: return 'died_within_week';
      case SurvivalStatus.diedLater: return 'died_later';
      case SurvivalStatus.sold: return 'sold';
    }
  }
}
