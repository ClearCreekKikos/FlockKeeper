import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/animal_model.dart';
import '../../../data/models/breeding_event_model.dart';
import '../../../data/models/kidding_record_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';

/// ─── Active Does & Bucks ──────────────────────────────────────────────────
final activeDoesProvider = Provider<List<Animal>>((ref) {
  final animals = ref.watch(activeAnimalsProvider).value ?? [];
  return animals.where((a) => a.sex == Sex.doe).toList();
});

final activeBucksProvider = Provider<List<Animal>>((ref) {
  final animals = ref.watch(activeAnimalsProvider).value ?? [];
  return animals.where((a) => a.sex == Sex.buck).toList();
});

/// ─── Breeding Events List ─────────────────────────────────────────────────
final breedingListProvider = FutureProvider<List<BreedingEvent>>((ref) async {
  final repo = ref.watch(breedingRepositoryProvider);
  return repo.getAllBreedingEvents();
});

/// ─── Kidding Records List ─────────────────────────────────────────────────
final kiddingRecordsListProvider = FutureProvider<List<KiddingRecord>>((ref) async {
  final repo = ref.watch(kiddingRepositoryProvider);
  return repo.getAllKiddingRecords();
});

/// ─── Active Pregnancies ───────────────────────────────────────────────────
final activePregnanciesProvider = Provider<List<BreedingEvent>>((ref) {
  final events = ref.watch(breedingListProvider).value ?? [];
  return events.where((e) => e.isActivePregnancy).toList();
});

/// ─── Breeding Statistics ──────────────────────────────────────────────────
class BreedingStats {
  final int totalBreedings;
  final int activePregnancies;
  final double conceptionRate;
  final int upcomingKiddings30Days;
  final int overdueKiddings;

  const BreedingStats({
    required this.totalBreedings,
    required this.activePregnancies,
    required this.conceptionRate,
    required this.upcomingKiddings30Days,
    required this.overdueKiddings,
  });
}

final breedingStatsProvider = Provider<BreedingStats>((ref) {
  final events = ref.watch(breedingListProvider).value ?? [];
  final activePregnancies = events.where((e) => e.isActivePregnancy).toList();
  
  final now = DateTime.now();
  final upcoming = activePregnancies.where((e) {
    if (e.expectedKidDate == null) return false;
    final diff = e.expectedKidDate!.difference(now).inDays;
    return diff >= 0 && diff <= 30;
  }).length;

  final overdue = activePregnancies.where((e) => e.isOverdue).length;

  // Conception rate = (confirmed pregnant / total breedings that have been checked or confirmed)
  final checkedEvents = events.where((e) => e.confirmedPregnant || e.outcome == BreedingOutcome.open).length;
  final confirmed = events.where((e) => e.confirmedPregnant).length;
  final conceptionRate = checkedEvents > 0 ? (confirmed / checkedEvents) * 100 : 0.0;

  return BreedingStats(
    totalBreedings: events.length,
    activePregnancies: activePregnancies.length,
    conceptionRate: conceptionRate,
    upcomingKiddings30Days: upcoming,
    overdueKiddings: overdue,
  );
});
