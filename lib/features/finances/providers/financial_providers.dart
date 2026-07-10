// lib/features/finances/providers/financial_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../data/models/financial_record_model.dart';
import '../../../shared/providers/providers.dart';

/// Provider for a list of all financial records, ordered newest first
final financialRecordsProvider = FutureProvider<List<FinancialRecord>>((
  ref,
) async {
  final repo = ref.watch(financialRepositoryProvider);
  return repo.getAllFinancialRecords();
});

/// Provider for financial records linked to a specific animal
final financialRecordsForAnimalProvider =
    FutureProvider.family<List<FinancialRecord>, int>((ref, animalId) async {
      final repo = ref.watch(financialRepositoryProvider);
      return repo.getFinancialRecordsForAnimal(animalId);
    });

/// Provider that calculates financial statistics reactively
final financialStatsProvider = Provider<Map<String, double>>((ref) {
  final recordsAsync = ref.watch(financialRecordsProvider);
  return recordsAsync.maybeWhen(
    data: (records) {
      double income = 0.0;
      double expense = 0.0;
      for (var r in records) {
        if (r.type == 'income') {
          income += r.amount;
        } else if (r.type == 'expense') {
          expense += r.amount;
        }
      }
      return {'income': income, 'expense': expense, 'net': income - expense};
    },
    orElse: () => {'income': 0.0, 'expense': 0.0, 'net': 0.0},
  );
});

/// StateProvider for current filter selected in UI dashboard: 'all', 'income', 'expense'
final financeFilterProvider = StateProvider<String>((ref) => 'all');

/// Filtered list of financial records based on financeFilterProvider
final filteredFinancialRecordsProvider =
    Provider<AsyncValue<List<FinancialRecord>>>((ref) {
      final recordsAsync = ref.watch(financialRecordsProvider);
      final filter = ref.watch(financeFilterProvider);

      return recordsAsync.whenData((records) {
        if (filter == 'all') return records;
        return records.where((r) => r.type == filter).toList();
      });
    });
