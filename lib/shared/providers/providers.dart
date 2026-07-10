import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/repositories/animal_repository.dart';
import '../../data/repositories/weight_repository.dart';
import '../../data/repositories/health_repository.dart';
import '../../data/repositories/breeding_repository.dart';
import '../../data/repositories/kidding_repository.dart';
import '../../data/repositories/pasture_repository.dart';
import '../../data/repositories/financial_repository.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../shared/providers/settings_provider.dart';

import '../../data/models/pasture_model.dart';
import '../../data/models/animal_model.dart';

import '../services/herd_service.dart';
import '../services/notification_service.dart';

/// ─── Repositories ──────────────────────────────────────────────────────────

final animalRepositoryProvider = Provider<AnimalRepository>((ref) {
  return AnimalRepository();
});

final weightRepositoryProvider = Provider<WeightRepository>((ref) {
  return WeightRepository();
});

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository();
});

final breedingRepositoryProvider = Provider<BreedingRepository>((ref) {
  return BreedingRepository();
});

final kiddingRepositoryProvider = Provider<KiddingRepository>((ref) {
  return KiddingRepository();
});

final pastureRepositoryProvider = Provider<PastureRepository>((ref) {
  return PastureRepository();
});

final financialRepositoryProvider = Provider<FinancialRepository>((ref) {
  return FinancialRepository();
});

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository();
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository();
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    ref.watch(reminderRepositoryProvider),
    ref.watch(inventoryRepositoryProvider),
  );
  ref.onDispose(() => service.stop());
  return service;
});

/// ─── Settings ──────────────────────────────────────────────────────────────

final settingsStateProvider =
    StateNotifierProvider<SettingsNotifier, Map<String, String>>((ref) {
      return SettingsNotifier();
    });

/// ─── Services ──────────────────────────────────────────────────────────────

final herdServiceProvider = Provider<HerdService>((ref) {
  return HerdService();
});

/// ─── Pasture Rotation Providers ─────────────────────────────────────────────

final pasturesListProvider = FutureProvider<List<Pasture>>((ref) async {
  final repo = ref.watch(pastureRepositoryProvider);
  return await repo.getAllPastures();
});

final pastureDetailAnimalsProvider = FutureProvider.family<List<Animal>, int>((
  ref,
  pastureId,
) async {
  final repo = ref.watch(pastureRepositoryProvider);
  return await repo.getAnimalsInPasture(pastureId);
});

final pastureHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((
      ref,
      pastureId,
    ) async {
      final repo = ref.watch(pastureRepositoryProvider);
      return await repo.getPastureHistory(pastureId);
    });

final animalPastureProvider = FutureProvider.family<Pasture?, int>((
  ref,
  animalId,
) async {
  final repo = ref.watch(pastureRepositoryProvider);
  return await repo.getPastureForAnimal(animalId);
});
