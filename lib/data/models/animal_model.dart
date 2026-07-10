// lib/data/models/animal_model.dart

import 'package:intl/intl.dart';
import '../../shared/utils/path_resolver.dart';

enum Sex { doe, buck, wether, unknown }

enum AnimalStatus { active, sold, deceased, culled, transferred, ancestor }

class Animal {
  final int? id;
  final String name;
  final String? barnName;
  final String? nkrRegNumber;
  final String? earTag;
  final String? tattoo;
  final String? rfidTag;
  final String? eidType;
  final String? eidPlacement;
  final String? idTagNumber;
  final String? idTagPlacement;
  final String? scrapieTag;
  final String? vglId;
  final DateTime? dob;
  final Sex sex;
  final String? color;
  final String? markings;
  final String? registry;
  final String? breedType;
  final String? herdBook;
  final String? secondRegistry;
  final String? secondRegNumber;
  final String? eyeColor;
  final String? earType;
  final String? hornType;
  final String? description;
  final String? ownershipStatus;
  final String breed;
  final int? damId;
  final int? sireId;
  final String? damName;
  final String? sireName;
  final String? damRegNumber;
  final String? sireRegNumber;
  final AnimalStatus status;
  final double? birthWeightLbs;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final DateTime? soldDate;
  final double? soldPrice;
  final String? soldTo;
  final DateTime? deceasedDate;
  final String? deceasedReason;
  final String? photoPath;
  final String? notes;
  final bool isHerdSire;
  final bool isRegistered;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Animal({
    this.id,
    required this.name,
    this.barnName,
    this.nkrRegNumber,
    this.earTag,
    this.tattoo,
    this.rfidTag,
    this.eidType,
    this.eidPlacement,
    this.idTagNumber,
    this.idTagPlacement,
    this.scrapieTag,
    this.vglId,
    this.dob,
    required this.sex,
    this.color,
    this.markings,
    this.registry,
    this.breedType,
    this.herdBook,
    this.secondRegistry,
    this.secondRegNumber,
    this.eyeColor,
    this.earType,
    this.hornType,
    this.description,
    this.ownershipStatus,
    this.breed = 'Kiko',
    this.damId,
    this.sireId,
    this.damName,
    this.sireName,
    this.damRegNumber,
    this.sireRegNumber,
    this.status = AnimalStatus.active,
    this.birthWeightLbs,
    this.purchaseDate,
    this.purchasePrice,
    this.soldDate,
    this.soldPrice,
    this.soldTo,
    this.deceasedDate,
    this.deceasedReason,
    this.photoPath,
    this.notes,
    this.isHerdSire = false,
    this.isRegistered = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // ─── Factory from Database Row ────────────────────────────────────────────
  factory Animal.fromMap(Map<String, dynamic> map) {
    return Animal(
      id: map['id'] as int?,
      name: map['name'] as String,
      barnName: map['barn_name'] as String?,
      nkrRegNumber: map['nkr_reg_number'] as String?,
      earTag: map['ear_tag'] as String?,
      tattoo: map['tattoo'] as String?,
      rfidTag: map['rfid_tag'] as String?,
      eidType: map['eid_type'] as String?,
      eidPlacement: map['eid_placement'] as String?,
      idTagNumber: map['id_tag_number'] as String?,
      idTagPlacement: map['id_tag_placement'] as String?,
      scrapieTag: map['scrapie_tag'] as String?,
      vglId: map['vgl_id'] as String?,
      dob: _parseDate(map['dob'] as String?),
      sex: _parseSex(map['sex'] as String),
      color: map['color'] as String?,
      markings: map['markings'] as String?,
      registry: map['registry'] as String?,
      breedType: map['breed_type'] as String?,
      herdBook: (map['herd_book'] ?? map['breed_type']) as String?,
      secondRegistry: map['second_registry'] as String?,
      secondRegNumber: map['second_reg_number'] as String?,
      eyeColor: map['eye_color'] as String?,
      earType: map['ear_type'] as String?,
      hornType: map['horn_type'] as String?,
      description: map['description'] as String?,
      ownershipStatus: map['ownership_status'] as String?,
      breed: map['breed'] as String? ?? 'Kiko',
      damId: map['dam_id'] as int?,
      sireId: map['sire_id'] as int?,
      damName: map['dam_name'] as String?,
      sireName: map['sire_name'] as String?,
      damRegNumber: map['dam_reg_number'] as String?,
      sireRegNumber: map['sire_reg_number'] as String?,
      status: _parseStatus(map['status'] as String?),
      birthWeightLbs: map['birth_weight_lbs'] as double?,
      purchaseDate: _parseDate(map['purchase_date'] as String?),
      purchasePrice: map['purchase_price'] as double?,
      soldDate: _parseDate(map['sold_date'] as String?),
      soldPrice: map['sold_price'] as double?,
      soldTo: map['sold_to'] as String?,
      deceasedDate: _parseDate(map['deceased_date'] as String?),
      deceasedReason: map['deceased_reason'] as String?,
      photoPath: PathResolver.resolvePath(map['photo_path'] as String?),
      notes: map['notes'] as String?,
      isHerdSire: (map['is_herd_sire'] as int? ?? 0) == 1,
      isRegistered: (map['is_registered'] as int? ?? 0) == 1,
      createdAt: _parseDate(map['created_at'] as String?) ?? DateTime.now(),
      updatedAt: _parseDate(map['updated_at'] as String?) ?? DateTime.now(),
    );
  }

  // ─── Convert to Database Map ──────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'barn_name': barnName,
      'nkr_reg_number': nkrRegNumber,
      'ear_tag': earTag,
      'tattoo': tattoo,
      'rfid_tag': rfidTag,
      'eid_type': eidType,
      'eid_placement': eidPlacement,
      'id_tag_number': idTagNumber,
      'id_tag_placement': idTagPlacement,
      'scrapie_tag': scrapieTag,
      'vgl_id': vglId,
      'dob': dob?.toIso8601String(),
      'sex': sex.name,
      'color': color,
      'markings': markings,
      'registry': registry,
      'breed_type': breedType,
      'herd_book': herdBook,
      'second_registry': secondRegistry,
      'second_reg_number': secondRegNumber,
      'eye_color': eyeColor,
      'ear_type': earType,
      'horn_type': hornType,
      'description': description,
      'ownership_status': ownershipStatus,
      'breed': breed,
      'dam_id': damId,
      'sire_id': sireId,
      'dam_name': damName,
      'sire_name': sireName,
      'dam_reg_number': damRegNumber,
      'sire_reg_number': sireRegNumber,
      'status': status.name,
      'birth_weight_lbs': birthWeightLbs,
      'purchase_date': purchaseDate?.toIso8601String(),
      'purchase_price': purchasePrice,
      'sold_date': soldDate?.toIso8601String(),
      'sold_price': soldPrice,
      'sold_to': soldTo,
      'deceased_date': deceasedDate?.toIso8601String(),
      'deceased_reason': deceasedReason,
      'photo_path': photoPath,
      'notes': notes,
      'is_herd_sire': isHerdSire ? 1 : 0,
      'is_registered': isRegistered ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // ─── CopyWith for Updates ─────────────────────────────────────────────────
  Animal copyWith({
    int? id,
    String? name,
    String? barnName,
    String? nkrRegNumber,
    String? earTag,
    String? tattoo,
    String? rfidTag,
    String? eidType,
    String? eidPlacement,
    String? idTagNumber,
    String? idTagPlacement,
    String? scrapieTag,
    String? vglId,
    DateTime? dob,
    Sex? sex,
    String? color,
    String? markings,
    String? registry,
    String? breedType,
    String? herdBook,
    String? secondRegistry,
    String? secondRegNumber,
    String? eyeColor,
    String? earType,
    String? hornType,
    String? description,
    String? ownershipStatus,
    String? breed,
    int? damId,
    int? sireId,
    String? damName,
    String? sireName,
    String? damRegNumber,
    String? sireRegNumber,
    AnimalStatus? status,
    double? birthWeightLbs,
    DateTime? purchaseDate,
    double? purchasePrice,
    DateTime? soldDate,
    double? soldPrice,
    String? soldTo,
    DateTime? deceasedDate,
    String? deceasedReason,
    String? photoPath,
    String? notes,
    bool? isHerdSire,
    bool? isRegistered,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Animal(
      id: id ?? this.id,
      name: name ?? this.name,
      barnName: barnName ?? this.barnName,
      nkrRegNumber: nkrRegNumber ?? this.nkrRegNumber,
      earTag: earTag ?? this.earTag,
      tattoo: tattoo ?? this.tattoo,
      rfidTag: rfidTag ?? this.rfidTag,
      eidType: eidType ?? this.eidType,
      eidPlacement: eidPlacement ?? this.eidPlacement,
      idTagNumber: idTagNumber ?? this.idTagNumber,
      idTagPlacement: idTagPlacement ?? this.idTagPlacement,
      scrapieTag: scrapieTag ?? this.scrapieTag,
      vglId: vglId ?? this.vglId,
      dob: dob ?? this.dob,
      sex: sex ?? this.sex,
      color: color ?? this.color,
      markings: markings ?? this.markings,
      registry: registry ?? this.registry,
      breedType: breedType ?? this.breedType,
      herdBook: herdBook ?? this.herdBook,
      secondRegistry: secondRegistry ?? this.secondRegistry,
      secondRegNumber: secondRegNumber ?? this.secondRegNumber,
      eyeColor: eyeColor ?? this.eyeColor,
      earType: earType ?? this.earType,
      hornType: hornType ?? this.hornType,
      description: description ?? this.description,
      ownershipStatus: ownershipStatus ?? this.ownershipStatus,
      breed: breed ?? this.breed,
      damId: damId ?? this.damId,
      sireId: sireId ?? this.sireId,
      damName: damName ?? this.damName,
      sireName: sireName ?? this.sireName,
      damRegNumber: damRegNumber ?? this.damRegNumber,
      sireRegNumber: sireRegNumber ?? this.sireRegNumber,
      status: status ?? this.status,
      birthWeightLbs: birthWeightLbs ?? this.birthWeightLbs,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      soldDate: soldDate ?? this.soldDate,
      soldPrice: soldPrice ?? this.soldPrice,
      soldTo: soldTo ?? this.soldTo,
      deceasedDate: deceasedDate ?? this.deceasedDate,
      deceasedReason: deceasedReason ?? this.deceasedReason,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      isHerdSire: isHerdSire ?? this.isHerdSire,
      isRegistered: isRegistered ?? this.isRegistered,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ─── Utility Getters ──────────────────────────────────────────────────────
  String get ageString {
    if (dob == null) return 'Unknown';
    final now = DateTime.now();
    final difference = now.difference(dob!);
    final years = (difference.inDays / 365).floor();
    final months = ((difference.inDays % 365) / 30).floor();

    if (years > 0) {
      return '$years yr${years > 1 ? 's' : ''}';
    } else if (months > 0) {
      return '$months mo';
    } else {
      final days = difference.inDays;
      return '$days day${days != 1 ? 's' : ''}';
    }
  }

  String get displayName => '$name${earTag != null && earTag!.isNotEmpty ? ' ($earTag)' : ''}';

  String get sexDisplay {
    switch (sex) {
      case Sex.doe:
        return 'Doe';
      case Sex.buck:
        return 'Buck';
      case Sex.wether:
        return 'Wether';
      case Sex.unknown:
        return 'Unknown';
    }
  }

  String get statusDisplay {
    switch (status) {
      case AnimalStatus.active:
        return 'Active';
      case AnimalStatus.sold:
        return 'Sold';
      case AnimalStatus.deceased:
        return 'Deceased';
      case AnimalStatus.culled:
        return 'Culled';
      case AnimalStatus.transferred:
        return 'Transferred';
      case AnimalStatus.ancestor:
        return 'Ancestor';
    }
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────
  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      // Fallback for different formats
      try {
        return DateFormat('yyyy-MM-dd').parse(dateStr);
      } catch (_) {
        return null;
      }
    }
  }

  static Sex _parseSex(String? sexStr) {
    switch (sexStr?.toLowerCase()) {
      case 'doe':
      case 'female':
      case 'f':
        return Sex.doe;
      case 'buck':
      case 'male':
      case 'm':
        return Sex.buck;
      case 'wether':
      case 'w':
        return Sex.wether;
      default:
        return Sex.unknown;
    }
  }

  static AnimalStatus _parseStatus(String? statusStr) {
    switch (statusStr?.toLowerCase()) {
      case 'active':
        return AnimalStatus.active;
      case 'sold':
        return AnimalStatus.sold;
      case 'deceased':
        return AnimalStatus.deceased;
      case 'culled':
        return AnimalStatus.culled;
      case 'transferred':
        return AnimalStatus.transferred;
      case 'ancestor':
        return AnimalStatus.ancestor;
      default:
        return AnimalStatus.active;
    }
  }

  @override
  String toString() {
    return 'Animal(id: $id, name: $name, earTag: $earTag, nkr: $nkrRegNumber, secondReg: $secondRegNumber, sex: ${sex.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Animal && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
