import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/animal_repository.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../../data/repositories/health_repository.dart';
import '../../../data/models/animal_model.dart';
import '../../../shared/providers/providers.dart';
import '../models/field_mapping.dart';
import 'package:intl/intl.dart';

class ImportService {
  final AnimalRepository _animalRepo;
  // ignore: unused_field
  final WeightRepository _weightRepo;
  // ignore: unused_field
  final HealthRepository _healthRepo;

  ImportService(this._animalRepo, this._weightRepo, this._healthRepo);

  Future<ImportResult> importAnimals({
    required List<Map<String, String>> rawRows,
    required List<FieldMapping> mappings,
    required ConflictResolutionStrategy conflictStrategy,
  }) async {
    int success = 0;
    int skipped = 0;
    int updated = 0;
    final errors = <ImportError>[];

    for (int i = 0; i < rawRows.length; i++) {
      try {
        final mapped = _applyMappings(rawRows[i], mappings);
        final animal = _parseAnimal(mapped);

        // Check for existing animal matching any unique field
        final existing = await _animalRepo.findDuplicateAnimal(animal);

        if (existing != null) {
          switch (conflictStrategy) {
            case ConflictResolutionStrategy.skip:
              skipped++;
              break;
            case ConflictResolutionStrategy.overwrite:
              await _animalRepo.updateAnimal(animal.copyWith(id: existing.id));
              updated++;
              break;
            case ConflictResolutionStrategy.keepBoth:
              await _animalRepo.insertAnimal(animal);
              success++;
              break;
          }
        } else {
          await _animalRepo.insertAnimal(animal);
          success++;
        }
      } catch (e) {
        errors.add(ImportError(rowIndex: i + 2, message: e.toString()));
      }
    }

    return ImportResult(
      totalRows: rawRows.length,
      successCount: success,
      updatedCount: updated,
      skippedCount: skipped,
      errors: errors,
    );
  }

  Map<String, String> _applyMappings(
    Map<String, String> rawRow,
    List<FieldMapping> mappings,
  ) {
    final result = <String, String>{};
    for (final mapping in mappings) {
      if (mapping.targetField != null) {
        result[mapping.targetField!] = rawRow[mapping.sourceField] ?? '';
      }
    }
    return result;
  }

  Animal _parseAnimal(Map<String, String> data) {
    final now = DateTime.now();
    return Animal(
      name: data['name']?.trim().isNotEmpty == true
          ? data['name']!.trim()
          : 'Unknown',
      barnName: _getNullableString(data['barnName']),
      nkrRegNumber: _getNullableString(data['nkrRegNumber']),
      earTag: _getNullableString(data['earTag']),
      tattoo: _getNullableString(data['tattoo']),
      rfidTag: _getNullableString(data['rfidTag']),
      eidType: _getNullableString(data['eidType']),
      eidPlacement: _getNullableString(data['eidPlacement']),
      idTagNumber: _getNullableString(data['idTagNumber']),
      idTagPlacement: _getNullableString(data['idTagPlacement']),
      scrapieTag: _getNullableString(data['scrapieTag']),
      vglId: _getNullableString(data['vglId']),
      dob: _parseDate(data['dob']),
      sex: _parseSex(data['sex'] ?? ''),
      color: _getNullableString(data['color']),
      markings: _getNullableString(data['markings']),
      registry: _getNullableString(data['registry']),
      breedType: _getNullableString(data['breedType']),
      herdBook:
          _getNullableString(data['herdBook']) ??
          _getNullableString(data['breedType']),
      eyeColor: _getNullableString(data['eyeColor']),
      earType: _getNullableString(data['earType']),
      hornType: _getNullableString(data['hornType']),
      description: _getNullableString(data['description']),
      ownershipStatus: _getNullableString(data['ownershipStatus']),
      breed: data['breed']?.trim().isNotEmpty == true
          ? data['breed']!.trim()
          : 'Kiko',
      damName: _getNullableString(data['damName']),
      sireName: _getNullableString(data['sireName']),
      damRegNumber: _getNullableString(data['damRegNumber']),
      sireRegNumber: _getNullableString(data['sireRegNumber']),
      status: _parseStatus(data['status'] ?? 'active'),
      birthWeightLbs: double.tryParse(data['birthWeightLbs'] ?? ''),
      purchaseDate: _parseDate(data['purchaseDate']),
      purchasePrice: double.tryParse(data['purchasePrice'] ?? ''),
      soldDate: _parseDate(data['soldDate']),
      soldPrice: double.tryParse(data['soldPrice'] ?? ''),
      soldTo: _getNullableString(data['soldTo']),
      deceasedDate: _parseDate(data['deceasedDate']),
      deceasedReason: _getNullableString(data['deceasedReason']),
      notes: _getNullableString(data['notes']),
      isHerdSire: _parseBool(data['isHerdSire']),
      isRegistered: _parseBool(data['isRegistered']),
      createdAt: now,
      updatedAt: now,
    );
  }

  String? _getNullableString(String? val) {
    if (val == null) return null;
    final trimmed = val.trim();
    return trimmed.isNotEmpty ? trimmed : null;
  }

  bool _parseBool(String? value) {
    if (value == null) return false;
    final v = value.toLowerCase().trim();
    return v == 'yes' || v == 'true' || v == 'y' || v == '1';
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    // Try multiple date formats
    final formats = [
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'MM-dd-yyyy',
      'dd/MM/yyyy',
      'M/d/yyyy',
      'yyyy/MM/dd',
    ];
    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parseStrict(value);
      } catch (e) {
        debugPrint('Failed to parse date "$value" with format "$fmt": $e');
        // Try next format
      }
    }
    return null;
  }

  Sex _parseSex(String value) {
    final v = value.toLowerCase().trim();
    if (v == 'f' || v == 'female' || v == 'doe') return Sex.doe;
    if (v == 'm' || v == 'male' || v == 'buck') return Sex.buck;
    if (v == 'w' || v == 'wether' || v == 'castrated') return Sex.wether;
    return Sex.unknown;
  }

  AnimalStatus _parseStatus(String value) {
    final v = value.toLowerCase().trim();
    if (v == 'active') return AnimalStatus.active;
    if (v == 'sold') return AnimalStatus.sold;
    if (v == 'deceased') return AnimalStatus.deceased;
    if (v == 'culled') return AnimalStatus.culled;
    if (v == 'transferred') return AnimalStatus.transferred;
    return AnimalStatus.active;
  }
}

enum ConflictResolutionStrategy { skip, overwrite, keepBoth }

class ImportResult {
  final int totalRows;
  final int successCount;
  final int updatedCount;
  final int skippedCount;
  final List<ImportError> errors;

  const ImportResult({
    required this.totalRows,
    required this.successCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.errors,
  });
}

class ImportError {
  final int rowIndex;
  final String message;
  const ImportError({required this.rowIndex, required this.message});
}

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(
    ref.read(animalRepositoryProvider),
    ref.read(weightRepositoryProvider),
    ref.read(healthRepositoryProvider),
  );
});
