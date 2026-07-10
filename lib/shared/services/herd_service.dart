// lib/shared/services/herd_service.dart

import '../../data/repositories/animal_repository.dart';
import '../../data/repositories/health_repository.dart';

class HerdService {
  final AnimalRepository _animalRepo = AnimalRepository();
  final HealthRepository _healthRepo = HealthRepository();

  /// Dashboard summary
  Future<Map<String, dynamic>> getDashboardStats() async {
    final total = await _animalRepo.getAnimalCount();
    final active = await _animalRepo.getAnimalCount(
      status: null,
    );

    final withdrawal = await _healthRepo.getAnimalsInWithdrawal();

    return {
      'totalAnimals': total,
      'activeAnimals': active,
      'animalsInWithdrawal': withdrawal.length,
    };
  }
}
