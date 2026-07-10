// lib/features/finances/screens/finances_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/financial_record_model.dart';
import '../../../data/models/animal_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../animals/screens/add_edit_animal_screen.dart';
import '../../breeding/screens/voice_command_overlay.dart';
import '../providers/financial_providers.dart';
import 'add_edit_finance_screen.dart';

class FinancesDashboardScreen extends ConsumerWidget {
  const FinancesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(financialStatsProvider);
    final filteredRecordsAsync = ref.watch(filteredFinancialRecordsProvider);
    final selectedFilter = ref.watch(financeFilterProvider);
    final animalsAsync = ref.watch(animalsProvider);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Map of animalId -> Animal for easy name lookup and navigation
    final Map<int, Animal> animalsMap = animalsAsync.maybeWhen(
      data: (list) => {for (var a in list) a.id!: a},
      orElse: () => <int, Animal>{},
    );

    final netFlow = stats['net'] ?? 0.0;
    final totalIncome = stats['income'] ?? 0.0;
    final totalExpense = stats['expense'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Cash Flow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Voice Commands',
            onPressed: () => VoiceCommandOverlay.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Transaction',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditFinanceScreen()),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'finances'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financialRecordsProvider);
          ref.invalidate(animalsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // ─── Summary Section ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // Net Balance Card
                    Card(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: netFlow >= 0
                                ? [Colors.teal.shade800, Colors.green.shade600]
                                : [Colors.deepOrange.shade800, Colors.red.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Net Cash Flow',
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
                                    '${netFlow >= 0 ? "+" : ""}\$${netFlow.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Icon(
                                  netFlow >= 0 ? Icons.trending_up : Icons.trending_down,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 36,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Income & Expenses Row
                    Row(
                      children: [
                        // Income Card
                        Expanded(
                          child: Card(
                            elevation: 1,
                            color: isDark
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.green.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.green.withValues(alpha: 0.2),
                                    child: const Icon(Icons.arrow_upward,
                                        color: Colors.green, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Sales (Income)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? Colors.white70 : Colors.black54,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '+\$${totalIncome.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Expense Card
                        Expanded(
                          child: Card(
                            elevation: 1,
                            color: isDark
                                ? Colors.deepOrange.withValues(alpha: 0.15)
                                : Colors.deepOrange.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: Colors.deepOrange.withValues(alpha: 0.3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.deepOrange.withValues(alpha: 0.2),
                                    child: const Icon(Icons.arrow_downward,
                                        color: Colors.deepOrange, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Costs (Expenses)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? Colors.white70 : Colors.black54,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '-\$${totalExpense.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? Colors.deepOrange.shade300 : Colors.deepOrange.shade800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ─── Filter Section ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: selectedFilter == 'all',
                      onSelected: (_) =>
                          ref.read(financeFilterProvider.notifier).state = 'all',
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Sales'),
                      selected: selectedFilter == 'income',
                      onSelected: (_) =>
                          ref.read(financeFilterProvider.notifier).state = 'income',
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Costs'),
                      selected: selectedFilter == 'expense',
                      onSelected: (_) =>
                          ref.read(financeFilterProvider.notifier).state = 'expense',
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Divider(height: 1),
              ),
            ),

            // ─── List Section ────────────────────────────────────────────────
            filteredRecordsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions logged.',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to add your first transaction.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final record = records[index];
                      final animal = record.animalId != null
                          ? animalsMap[record.animalId]
                          : null;
                      return _buildTransactionCard(
                          context, ref, record, animal, isDark);
                    },
                    childCount: records.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Error: $err')),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditFinanceScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Transaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  // ─── Transaction Item Builder ────────────────────────────────────────────
  Widget _buildTransactionCard(
    BuildContext context,
    WidgetRef ref,
    FinancialRecord record,
    Animal? animal,
    bool isDark,
  ) {
    final recordColor = _getCategoryColor(record.type);
    final categoryIcon = _getCategoryIcon(record.category);
    final categoryLabel = _formatCategory(record.category);

    return Dismissible(
      key: ValueKey('finance_${record.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: Text(
              'Are you sure you want to delete this transaction for \$${record.amount.toStringAsFixed(2)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        final repo = ref.read(financialRepositoryProvider);
        await repo.deleteFinancialRecord(record.id!);
        ref.invalidate(financialRecordsProvider);
        if (record.animalId != null) {
          ref.invalidate(financialRecordsForAnimalProvider(record.animalId!));
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditFinanceScreen(record: record),
              ),
            );
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: recordColor.withValues(alpha: 0.15),
            child: Icon(categoryIcon, color: recordColor),
          ),
          title: Text(
            record.description?.isNotEmpty == true
                ? record.description!
                : categoryLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMd().format(record.recordDate),
                style: const TextStyle(fontSize: 12),
              ),
              if (record.vendorBuyer?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    record.type == 'income'
                        ? 'Buyer: ${record.vendorBuyer}'
                        : 'Vendor: ${record.vendorBuyer}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              if (animal != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEditAnimalScreen(animal: animal),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pets,
                                size: 12,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              animal.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${record.type == 'income' ? '+' : '-'}\$${record.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: recordColor,
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) async {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditFinanceScreen(record: record),
                      ),
                    );
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Transaction'),
                        content: const Text(
                            'Are you sure you want to delete this transaction?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final repo = ref.read(financialRepositoryProvider);
                      await repo.deleteFinancialRecord(record.id!);
                      ref.invalidate(financialRecordsProvider);
                      if (record.animalId != null) {
                        ref.invalidate(financialRecordsForAnimalProvider(record.animalId!));
                      }
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Icon and Color Helpers ──────────────────────────────────────────────
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'purchase':
        return Icons.shopping_bag_outlined;
      case 'sale':
        return Icons.sell_outlined;
      case 'feed':
        return Icons.grass;
      case 'medication':
        return Icons.medical_services_outlined;
      case 'veterinary':
        return Icons.local_hospital_outlined;
      case 'equipment':
        return Icons.construction_outlined;
      case 'pasture':
        return Icons.landscape_outlined;
      case 'registration':
        return Icons.badge_outlined;
      case 'other':
      default:
        return Icons.more_horiz_outlined;
    }
  }

  Color _getCategoryColor(String type) {
    return type == 'income' ? Colors.green : Colors.deepOrange;
  }

  String _formatCategory(String category) {
    if (category.isEmpty) return '';
    return category[0].toUpperCase() + category.substring(1);
  }
}
