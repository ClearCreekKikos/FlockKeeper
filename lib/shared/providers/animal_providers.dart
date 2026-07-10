import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/models/animal_model.dart';
import '../../../shared/providers/providers.dart';

/// ─── Get All Animals ───────────────────────────────────────────────────────

final animalsProvider = FutureProvider<List<Animal>>((ref) async {
  final repo = ref.watch(animalRepositoryProvider);
  return repo.getAllAnimals();
});

/// ─── Active Animals Only ───────────────────────────────────────────────────

final activeAnimalsProvider = FutureProvider<List<Animal>>((ref) async {
  final repo = ref.watch(animalRepositoryProvider);
  return repo.getActiveAnimals();
});

/// ─── Single Animal ─────────────────────────────────────────────────────────

final animalByIdProvider = FutureProvider.family<Animal?, int>((
  ref,
  animalId,
) async {
  final repo = ref.watch(animalRepositoryProvider);
  return repo.getAnimalById(animalId);
});

/// ─── Search Provider ───────────────────────────────────────────────────────

final animalSearchQueryProvider = StateProvider<String>((ref) => '');

final animalStatusFilterProvider = StateProvider<AnimalStatus>(
  (ref) => AnimalStatus.active,
);

final searchedAnimalsProvider = FutureProvider<List<Animal>>((ref) async {
  final query = ref.watch(animalSearchQueryProvider);
  final status = ref.watch(animalStatusFilterProvider);
  final repo = ref.watch(animalRepositoryProvider);

  if (query.isEmpty) {
    return repo.getAnimalsByStatus(status);
  }

  return repo.searchAnimals(query, status: status);
});
