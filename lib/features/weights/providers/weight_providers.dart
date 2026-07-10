import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/weight_record_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/models/animal_model.dart';

final weightHistoryProvider =
    FutureProvider.family<List<WeightRecord>, int>((ref, animalId) {
  return ref.watch(weightRepositoryProvider).getWeightRecordsForAnimal(animalId);
});

final latestWeightProvider =
    FutureProvider.family<WeightRecord?, int>((ref, animalId) {
  return ref.watch(weightRepositoryProvider).getLatestWeightForAnimal(animalId);
});

final lifetimeADGProvider = FutureProvider.family<double?, int>((ref, animalId) {
  return ref.watch(weightRepositoryProvider).calculateLifetimeADG(animalId);
});

final recentADGProvider = FutureProvider.family<double?, int>((ref, animalId) {
  // Calculate ADG between last 3 weigh ins
  return ref.watch(weightRepositoryProvider).calculateRecentADG(animalId, 3);
});

final milestoneWeightsProvider =
    FutureProvider.family<Map<String, double?>, int>((ref, animalId) async {
  final repo = ref.watch(weightRepositoryProvider);
  // Watch the animal provider so milestones refresh when the animal record (birth weight) updates
  final animal = ref.watch(animalByIdProvider(animalId)).value;

  if (animal == null) return {'birth': null};
  if (animal.dob == null) return {'birth': animal.birthWeightLbs};

  final d30 = await repo.getWeightClosestToDate(
      animalId, animal.dob!.add(const Duration(days: 30)));
  final d90 = await repo.getWeightClosestToDate(
      animalId, animal.dob!.add(const Duration(days: 90)));
  final d120 = await repo.getWeightClosestToDate(
      animalId, animal.dob!.add(const Duration(days: 120)));
  final d150 = await repo.getWeightClosestToDate(
      animalId, animal.dob!.add(const Duration(days: 150)));
  final d365 = await repo.getWeightClosestToDate(
      animalId, animal.dob!.add(const Duration(days: 365)));

  return {
    'birth': animal.birthWeightLbs,
    '30': d30?.weightLbs,
    '90': d90?.weightLbs,
    '120': d120?.weightLbs,
    '150': d150?.weightLbs,
    '365': d365?.weightLbs,
  };
});

class AnimalWeightAnalytics {
  final Animal animal;
  final double? currentWeight;
  final DateTime? latestWeighDate;
  final double? lifetimeADG;
  final double? recentADG;
  final int ageInDays;
  final String ageGroup;
  final String performanceTier; // 'High', 'Target', 'Low'

  AnimalWeightAnalytics({
    required this.animal,
    required this.currentWeight,
    required this.latestWeighDate,
    required this.lifetimeADG,
    required this.recentADG,
    required this.ageInDays,
    required this.ageGroup,
    required this.performanceTier,
  });
}

final weightAnalyticsProvider = FutureProvider<List<AnimalWeightAnalytics>>((ref) async {
  final animals = await ref.watch(activeAnimalsProvider.future);
  final settings = ref.watch(settingsStateProvider);
  final targetHigh = double.tryParse(settings['target_adg_high'] ?? '0.45') ?? 0.45;
  final targetMin = double.tryParse(settings['target_adg_min'] ?? '0.25') ?? 0.25;
  final db = DatabaseHelper();
  
  // Fetch all weight records ordered by date descending
  final weightMaps = await db.query(DatabaseHelper.tableWeightRecords, orderBy: 'weigh_date DESC');
  final allRecords = weightMaps.map((m) => WeightRecord.fromMap(m)).toList();
  
  // Group by animal ID
  final Map<int, List<WeightRecord>> recordsMap = {};
  for (final r in allRecords) {
    recordsMap.putIfAbsent(r.animalId, () => []).add(r);
  }

  final List<AnimalWeightAnalytics> results = [];
  final now = DateTime.now();

  for (final animal in animals) {
    if (animal.id == null) continue;
    
    final records = recordsMap[animal.id!] ?? [];
    final double? currentWeight = records.isNotEmpty ? records.first.weightLbs : null;
    final DateTime? latestWeighDate = records.isNotEmpty ? records.first.weighDate : null;

    // Calculate age in days
    final dob = animal.dob;
    final int ageInDays = dob != null ? now.difference(dob).inDays : 0;

    // Determine age group
    String ageGroup = 'Mature Adults';
    if (ageInDays <= 90) {
      ageGroup = 'Kids';
    } else if (ageInDays <= 180) {
      ageGroup = 'Weanlings';
    } else if (ageInDays <= 365) {
      ageGroup = 'Yearlings';
    } else if (ageInDays <= 730) {
      ageGroup = 'Young Adults';
    }

    // Calculate lifetime ADG in-memory
    double? lifetimeADG;
    if (records.isNotEmpty) {
      final newest = records.first;
      double? startingWeight = animal.birthWeightLbs;
      DateTime? startingDate = dob;

      if (startingWeight == null || startingDate == null) {
        if (records.length >= 2) {
          startingWeight = records.last.weightLbs;
          startingDate = records.last.weighDate;
        }
      }

      if (startingWeight != null && startingDate != null) {
        final days = newest.weighDate.difference(startingDate).inDays;
        if (days > 0) {
          lifetimeADG = (newest.weightLbs - startingWeight) / days;
        } else {
          lifetimeADG = 0.0;
        }
      }
    }

    // Calculate recent ADG in-memory (over last 3 points)
    double? recentADG;
    if (records.length >= 3) {
      final newest = records.first;
      final oldestOfRange = records[2];
      final days = newest.weighDate.difference(oldestOfRange.weighDate).inDays;
      if (days > 0) {
        recentADG = (newest.weightLbs - oldestOfRange.weightLbs) / days;
      }
    }

    // Determine performance tier based on lifetime ADG
    String performanceTier = 'Low';
    final adg = lifetimeADG ?? 0.0;
    if (adg >= targetHigh) {
      performanceTier = 'High';
    } else if (adg >= targetMin) {
      performanceTier = 'Target';
    }

    results.add(AnimalWeightAnalytics(
      animal: animal,
      currentWeight: currentWeight,
      latestWeighDate: latestWeighDate,
      lifetimeADG: lifetimeADG,
      recentADG: recentADG,
      ageInDays: ageInDays,
      ageGroup: ageGroup,
      performanceTier: performanceTier,
    ));
  }

  return results;
});