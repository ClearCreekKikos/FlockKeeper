// lib/features/inventory/screens/inventory_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/inventory_item_model.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../breeding/screens/voice_command_overlay.dart';
import '../providers/inventory_providers.dart';
import 'add_edit_inventory_screen.dart';
import 'inventory_detail_screen.dart';
import 'low_stock_alerts_screen.dart';
import 'supplier_list_screen.dart';

class InventoryDashboardScreen extends ConsumerWidget {
  const InventoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(inventoryStatsProvider);
    final filteredItemsAsync = ref.watch(filteredInventoryProvider);
    final selectedCategory = ref.watch(inventoryCategoryFilterProvider);
    final searchQuery = ref.watch(inventorySearchProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int lowStock = stats['lowStock'] as int? ?? 0;
    final int expiringSoon = stats['expiringSoon'] as int? ?? 0;
    final double totalValue = (stats['totalValue'] as num?)?.toDouble() ?? 0;
    final int totalItems = stats['totalItems'] as int? ?? 0;

    final showInactive = ref.watch(showInactiveInventoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Ranch Supplies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Voice Commands',
            onPressed: () => VoiceCommandOverlay.show(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'suppliers') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupplierListScreen()),
                );
              } else if (value == 'low_stock') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LowStockAlertsScreen()),
                );
              } else if (value == 'toggle_inactive') {
                ref.read(showInactiveInventoryProvider.notifier).update((s) => !s);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'suppliers', child: Text('Manage Suppliers')),
              PopupMenuItem(
                value: 'low_stock',
                child: Row(
                  children: [
                    const Text('Low Stock Alerts'),
                    if (lowStock > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$lowStock',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_inactive',
                child: Text(showInactive ? 'Hide Unstocked Items' : 'Show Unstocked Items'),
              ),
            ],
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'inventory'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(inventoryItemsProvider);
          ref.invalidate(lowStockItemsProvider);
          ref.invalidate(expiringItemsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ─── Summary Cards ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // Main summary card
                    Card(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.indigo.shade800, Colors.blue.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supply Inventory',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '\$${totalValue.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.inventory_2,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 36,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalItems items tracked',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Alert row
                    Row(
                      children: [
                        Expanded(
                          child: _AlertMiniCard(
                            icon: Icons.warning_amber_rounded,
                            label: 'Low Stock',
                            count: lowStock,
                            color: Colors.orange.shade700,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LowStockAlertsScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AlertMiniCard(
                            icon: Icons.timer_outlined,
                            label: 'Expiring Soon',
                            count: expiringSoon,
                            color: Colors.red.shade700,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LowStockAlertsScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search supplies...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () =>
                                    ref.read(inventorySearchProvider.notifier).state = '',
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                      ),
                      onChanged: (v) =>
                          ref.read(inventorySearchProvider.notifier).state = v,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ─── Category Filter Chips ───────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _CategoryChip(
                      label: 'All',
                      value: 'all',
                      selected: selectedCategory,
                      onTap: () =>
                          ref.read(inventoryCategoryFilterProvider.notifier).state = 'all',
                    ),
                    ...InventoryCategory.values.map((cat) => _CategoryChip(
                          label: InventoryItem.categoryLabel(cat),
                          value: _catKey(cat),
                          selected: selectedCategory,
                          onTap: () =>
                              ref.read(inventoryCategoryFilterProvider.notifier).state =
                                  _catKey(cat),
                        )),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ─── Item List ───────────────────────────────────────────────────
            filteredItemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('No items found.')),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return _InventoryItemTile(
                        item: item,
                        isDark: isDark,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InventoryDetailScreen(itemId: item.id!),
                            ),
                          );
                          ref.invalidate(inventoryItemsProvider);
                          ref.invalidate(lowStockItemsProvider);
                          ref.invalidate(expiringItemsProvider);
                        },
                      );
                    },
                    childCount: items.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 2,
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditInventoryScreen()),
              );
              ref.invalidate(inventoryItemsProvider);
              ref.invalidate(lowStockItemsProvider);
              ref.invalidate(expiringItemsProvider);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────────────────────

class _AlertMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _AlertMiniCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: count > 0 ? color : Colors.grey, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: count > 0 ? color : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}

class _InventoryItemTile extends StatelessWidget {
  final InventoryItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _InventoryItemTile({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qtyColor = !item.isActive
        ? Colors.grey
        : item.isOutOfStock
            ? Colors.red
            : item.isLowStock
                ? Colors.orange.shade700
                : Colors.green.shade700;

    final tile = Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: item.isActive ? cs.primaryContainer : Colors.grey.shade200,
          child: Icon(
            _categoryIcon(item.category),
            size: 20,
            color: item.isActive ? cs.primary : Colors.grey.shade600,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!item.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Unstocked',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              InventoryItem.categoryLabel(item.category),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            if (item.isActive && item.isExpiringSoon()) ...[
              const SizedBox(width: 6),
              Icon(Icons.timer, size: 13, color: Colors.red.shade400),
              Text(
                item.isExpired ? ' Expired' : ' Expiring',
                style: TextStyle(fontSize: 10, color: Colors.red.shade400),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.currentQuantity % 1 == 0 ? item.currentQuantity.toInt() : item.currentQuantity}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: qtyColor,
              ),
            ),
            Text(
              '${item.unit} (min ${item.minimumQuantity % 1 == 0 ? item.minimumQuantity.toInt() : item.minimumQuantity})',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );

    return Opacity(
      opacity: item.isActive ? 1.0 : 0.55,
      child: tile,
    );
  }
}

// ─── Utility ────────────────────────────────────────────────────────────────

String _catKey(InventoryCategory cat) {
  switch (cat) {
    case InventoryCategory.healthMedical: return 'health_medical';
    case InventoryCategory.hoofGrooming: return 'hoof_grooming';
    case InventoryCategory.kidding: return 'kidding';
    case InventoryCategory.workingChute: return 'working_chute';
    case InventoryCategory.cleaning: return 'cleaning';
    case InventoryCategory.feedNutrition: return 'feed_nutrition';
    case InventoryCategory.fencingPasture: return 'fencing_pasture';
    case InventoryCategory.generalTools: return 'general_tools';
    case InventoryCategory.paperwork: return 'paperwork';
  }
}

IconData _categoryIcon(InventoryCategory cat) {
  switch (cat) {
    case InventoryCategory.healthMedical: return Icons.medical_services;
    case InventoryCategory.hoofGrooming: return Icons.content_cut;
    case InventoryCategory.kidding: return Icons.child_friendly;
    case InventoryCategory.workingChute: return Icons.construction;
    case InventoryCategory.cleaning: return Icons.cleaning_services;
    case InventoryCategory.feedNutrition: return Icons.restaurant;
    case InventoryCategory.fencingPasture: return Icons.fence;
    case InventoryCategory.generalTools: return Icons.build;
    case InventoryCategory.paperwork: return Icons.description;
  }
}
