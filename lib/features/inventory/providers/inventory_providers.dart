// lib/features/inventory/providers/inventory_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../data/models/inventory_item_model.dart';
import '../../../data/models/inventory_usage_model.dart';
import '../../../data/models/supplier_model.dart';
import '../../../shared/providers/providers.dart';

/// Whether to include inactive (ignored/disabled) inventory items in the main views.
final showInactiveInventoryProvider = StateProvider<bool>((ref) => false);

/// All inventory items, ordered by category then name.
final inventoryItemsProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final showInactive = ref.watch(showInactiveInventoryProvider);
  return repo.getAllItems(includeInactive: showInactive);
});

/// Items at or below their minimum stock level.
final lowStockItemsProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getLowStockItems();
});

/// Items expiring within 30 days.
final expiringItemsProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.getExpiringItems(30);
});

/// All suppliers.
final suppliersListProvider = FutureProvider<List<Supplier>>((ref) async {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.getAllSuppliers();
});

/// Usage history for a specific item.
final inventoryUsageHistoryProvider =
    FutureProvider.family<List<InventoryUsage>, int>((ref, itemId) async {
      final repo = ref.watch(inventoryRepositoryProvider);
      return repo.getUsageHistory(itemId);
    });

/// Current category filter for the dashboard.
final inventoryCategoryFilterProvider = StateProvider<String>((ref) => 'all');

/// Search query for the dashboard.
final inventorySearchProvider = StateProvider<String>((ref) => '');

/// Inventory items grouped by category.
final inventoryByCategoryProvider =
    Provider<AsyncValue<Map<InventoryCategory, List<InventoryItem>>>>((ref) {
      final itemsAsync = ref.watch(inventoryItemsProvider);
      return itemsAsync.whenData((items) {
        final grouped = <InventoryCategory, List<InventoryItem>>{};
        for (final item in items) {
          grouped.putIfAbsent(item.category, () => []).add(item);
        }
        return grouped;
      });
    });

/// Filtered + searched inventory items based on category filter and search.
final filteredInventoryProvider =
    Provider<AsyncValue<List<InventoryItem>>>((ref) {
      final itemsAsync = ref.watch(inventoryItemsProvider);
      final filter = ref.watch(inventoryCategoryFilterProvider);
      final search = ref.watch(inventorySearchProvider).toLowerCase().trim();

      return itemsAsync.whenData((items) {
        var filtered = items;

        // Category filter
        if (filter != 'all') {
          filtered = filtered
              .where((i) => _categoryToFilterKey(i.category) == filter)
              .toList();
        }

        // Search filter
        if (search.isNotEmpty) {
          filtered = filtered
              .where((i) => i.name.toLowerCase().contains(search))
              .toList();
        }

        return filtered;
      });
    });

/// Summary stats: total items, total value, low-stock count, expiring count.
final inventoryStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final itemsAsync = ref.watch(inventoryItemsProvider);
  return itemsAsync.maybeWhen(
    data: (items) {
      int totalItems = 0;
      double totalValue = 0;
      int lowStock = 0;
      int expiringSoon = 0;
      int outOfStock = 0;

      for (final item in items) {
        if (!item.isActive) continue;
        totalItems++;
        totalValue += item.totalValue;
        if (item.isLowStock) lowStock++;
        if (item.isExpiringSoon()) expiringSoon++;
        if (item.isOutOfStock) outOfStock++;
      }

      return {
        'totalItems': totalItems,
        'totalValue': totalValue,
        'lowStock': lowStock,
        'expiringSoon': expiringSoon,
        'outOfStock': outOfStock,
      };
    },
    orElse: () => {
      'totalItems': 0,
      'totalValue': 0.0,
      'lowStock': 0,
      'expiringSoon': 0,
      'outOfStock': 0,
    },
  );
});

// ─── Helpers ──────────────────────────────────────────────────────────────

String _categoryToFilterKey(InventoryCategory cat) {
  switch (cat) {
    case InventoryCategory.healthMedical:
      return 'health_medical';
    case InventoryCategory.hoofGrooming:
      return 'hoof_grooming';
    case InventoryCategory.kidding:
      return 'kidding';
    case InventoryCategory.workingChute:
      return 'working_chute';
    case InventoryCategory.cleaning:
      return 'cleaning';
    case InventoryCategory.feedNutrition:
      return 'feed_nutrition';
    case InventoryCategory.fencingPasture:
      return 'fencing_pasture';
    case InventoryCategory.generalTools:
      return 'general_tools';
    case InventoryCategory.paperwork:
      return 'paperwork';
  }
}
