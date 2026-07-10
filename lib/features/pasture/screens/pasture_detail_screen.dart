// lib/features/pasture/screens/pasture_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/pasture_model.dart';
import '../../../data/models/animal_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';
import 'add_edit_pasture_screen.dart';

class PastureDetailScreen extends ConsumerStatefulWidget {
  final int pastureId;

  const PastureDetailScreen({super.key, required this.pastureId});

  @override
  ConsumerState<PastureDetailScreen> createState() => _PastureDetailScreenState();
}

class _PastureDetailScreenState extends ConsumerState<PastureDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _invalidateAll({List<int>? animalIds}) {
    ref.invalidate(pasturesListProvider);
    ref.invalidate(pastureDetailAnimalsProvider(widget.pastureId));
    ref.invalidate(pastureHistoryProvider(widget.pastureId));
    if (animalIds != null) {
      for (final id in animalIds) {
        ref.invalidate(animalPastureProvider(id));
      }
    }
  }

  // ─── Move Animal In Dialog ──────────────────────────────────────────────────
  Future<void> _showMoveInDialog(BuildContext context, List<Animal> currentGrazers) async {
    final activeAnimalsAsync = ref.read(activeAnimalsProvider);
    final activeAnimals = activeAnimalsAsync.value ?? [];

    // Filter out animals already in this pasture
    final currentIds = currentGrazers.map((a) => a.id).toSet();
    final availableAnimals = activeAnimals.where((a) => !currentIds.contains(a.id)).toList();

    if (availableAnimals.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Move Animals In'),
          content: const Text('All active animals are already grazing in this pasture.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final selectedAnimals = <int, bool>{};
    for (final a in availableAnimals) {
      selectedAnimals[a.id!] = false;
    }

    DateTime selectedDate = DateTime.now();
    String forageCondition = 'good';
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Move Animals In'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Date selection
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Move In Date'),
                      subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),

                    // Forage Condition Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: forageCondition,
                      decoration: const InputDecoration(
                        labelText: 'Forage Condition In',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'excellent', child: Text('Excellent')),
                        DropdownMenuItem(value: 'good', child: Text('Good')),
                        DropdownMenuItem(value: 'fair', child: Text('Fair')),
                        DropdownMenuItem(value: 'poor', child: Text('Poor')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          forageCondition = val;
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Notes Text Field
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Rotation Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Animals List
                    const Text(
                      'Select Herd Animals:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: availableAnimals.length,
                        itemBuilder: (context, idx) {
                          final animal = availableAnimals[idx];
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(animal.name),
                            subtitle: Text(
                              animal.earTag != null && animal.earTag!.isNotEmpty
                                  ? 'Ear Tag: ${animal.earTag}'
                                  : 'No Tag',
                            ),
                            value: selectedAnimals[animal.id],
                            onChanged: (val) {
                              setDialogState(() {
                                selectedAnimals[animal.id!] = val ?? false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final targetIds = selectedAnimals.entries
                        .where((e) => e.value)
                        .map((e) => e.key)
                        .toList();

                    if (targetIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select at least one animal.')),
                      );
                      return;
                    }

                    final repo = ref.read(pastureRepositoryProvider);
                    for (final animalId in targetIds) {
                      await repo.moveAnimalIntoPasture(
                        animalId: animalId,
                        pastureId: widget.pastureId,
                        moveInDate: selectedDate,
                        forageConditionIn: forageCondition,
                        notes: notesController.text.trim().isNotEmpty
                            ? notesController.text.trim()
                            : null,
                      );
                    }

                    _invalidateAll(animalIds: targetIds);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Move In'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Move Animal Out Dialog ─────────────────────────────────────────────────
  Future<void> _showMoveOutDialog(BuildContext context, Animal animal) async {
    DateTime selectedDate = DateTime.now();
    String forageCondition = 'good';
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Check Out ${animal.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Move Out Date'),
                    subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),

                  // Forage Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: forageCondition,
                    decoration: const InputDecoration(
                      labelText: 'Forage Condition Out',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'excellent', child: Text('Excellent')),
                      DropdownMenuItem(value: 'good', child: Text('Good')),
                      DropdownMenuItem(value: 'fair', child: Text('Fair')),
                      DropdownMenuItem(value: 'poor', child: Text('Poor')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        forageCondition = val;
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final repo = ref.read(pastureRepositoryProvider);
                    await repo.moveAnimalOutOfPasture(
                      animalId: animal.id!,
                      pastureId: widget.pastureId,
                      moveOutDate: selectedDate,
                      forageConditionOut: forageCondition,
                      notes: notesController.text.trim().isNotEmpty
                          ? notesController.text.trim()
                          : null,
                    );

                    _invalidateAll(animalIds: [animal.id!]);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Check Out'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pastureAsync = ref.watch(pasturesListProvider).whenData(
          (list) => list.firstWhere((p) => p.id == widget.pastureId),
        );
    final grazersAsync = ref.watch(pastureDetailAnimalsProvider(widget.pastureId));
    final historyAsync = ref.watch(pastureHistoryProvider(widget.pastureId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: pastureAsync.when(
          data: (p) => Text(p.name),
          loading: () => const Text('Loading Pasture...'),
          error: (_, _) => const Text('Pasture Details'),
        ),
        actions: [
          pastureAsync.when(
            data: (p) => IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Pasture Parameters',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditPastureScreen(pasture: p),
                  ),
                ).then((_) => _invalidateAll());
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          grazersAsync.when(
            data: (list) => IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Move Animals In',
              onPressed: () => _showMoveInDialog(context, list),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pets), text: 'Active Grazing'),
            Tab(icon: Icon(Icons.history), text: 'Rotation History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: Currently Grazing ──────────────────────────────────────
          RefreshIndicator(
            onRefresh: () async {
              _invalidateAll();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Info Summary Card
                SliverToBoxAdapter(
                  child: pastureAsync.when(
                    data: (pasture) => _buildPastureSummaryCard(context, pasture, isDark),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),

                const SliverToBoxAdapter(child: Divider(height: 1)),

                // Grazers List
                grazersAsync.when(
                  data: (grazers) {
                    if (grazers.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.grass, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'No animals are grazing in this pasture.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _showMoveInDialog(context, grazers),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Move Animals In'),
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
                          final animal = grazers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundImage: animal.photoPath != null && File(animal.photoPath!).existsSync()
                                    ? FileImage(File(animal.photoPath!))
                                    : null,
                                child: animal.photoPath == null || !File(animal.photoPath!).existsSync()
                                    ? const Icon(Icons.pets)
                                    : null,
                              ),
                              title: Text(
                                animal.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${animal.sexDisplay} • ${animal.ageString}${animal.earTag != null && animal.earTag!.isNotEmpty
                                        ? '\nTag: ${animal.earTag}'
                                        : ''}',
                              ),
                              isThreeLine: animal.earTag != null && animal.earTag!.isNotEmpty,
                              trailing: IconButton(
                                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                                tooltip: 'Check Out (Move Out)',
                                onPressed: () => _showMoveOutDialog(context, animal),
                              ),
                            ),
                          );
                        },
                        childCount: grazers.length,
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

          // ─── TAB 2: Rotation History ────────────────────────────────────────
          historyAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return const Center(child: Text('No rotation history logged for this pasture.'));
              }
              return RefreshIndicator(
                onRefresh: () async => ref.refresh(pastureHistoryProvider(widget.pastureId)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final moveIn = DateTime.parse(log['move_in_date'] as String);
                    final moveOutStr = log['move_out_date'] as String?;
                    final moveOut = moveOutStr != null ? DateTime.parse(moveOutStr) : null;
                    final isCurrent = moveOut == null;

                    final duration = isCurrent
                        ? DateTime.now().difference(moveIn).inDays
                        : moveOut.difference(moveIn).inDays;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  log['animal_name'] as String? ?? 'Herd Group',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: isDark ? 0.25 : 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: const Text(
                                      'Grazing',
                                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'In: ${DateFormat.yMMMd().format(moveIn)}${isCurrent
                                      ? ' • Present ($duration Days)'
                                      : ' • Out: ${DateFormat.yMMMd().format(moveOut)} ($duration Days)'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildHistoryConditionChip(
                                  context,
                                  'In: ${log['forage_condition_in']}',
                                  isDark,
                                ),
                                const SizedBox(width: 8),
                                if (!isCurrent && log['forage_condition_out'] != null)
                                  _buildHistoryConditionChip(
                                    context,
                                    'Out: ${log['forage_condition_out']}',
                                    isDark,
                                  ),
                              ],
                            ),
                            if (log['notes'] != null && (log['notes'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Note: ${log['notes']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading history: $err')),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryConditionChip(BuildContext context, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    );
  }

  Widget _buildPastureSummaryCard(BuildContext context, Pasture pasture, bool isDark) {
    final hasCap = pasture.carryingCapacity != null;
    final density = hasCap && pasture.carryingCapacity! > 0
        ? pasture.currentAnimalCount / pasture.carryingCapacity!
        : 0.0;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pasture.acreage ?? 0.0} Acres Field',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Forage: ${pasture.forageType ?? "Grass"}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(pasture.status).withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(pasture.status)),
                  ),
                  child: Text(
                    pasture.statusDisplay,
                    style: TextStyle(
                      color: isDark ? _getStatusColor(pasture.status).shade200 : _getStatusColor(pasture.status).shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Specs row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryIcon(Icons.water_drop, 'Water', pasture.waterSource ?? 'Water'),
                _buildSummaryIcon(Icons.fence, 'Fence', pasture.fencingType ?? 'Fence'),
                _buildSummaryIcon(Icons.timer_outlined, 'Target Rest', '${pasture.restDaysTarget} Days'),
              ],
            ),

            if (hasCap) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Carrying Capacity Density: ${(density * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: density > 1.0 ? FontWeight.bold : FontWeight.normal,
                      color: density > 1.0 ? Colors.red : Colors.grey,
                    ),
                  ),
                  Text(
                    '${pasture.currentAnimalCount} / ${pasture.carryingCapacity} Head',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: density.clamp(0.0, 1.0),
                  color: density > 1.0
                      ? Colors.red
                      : (density > 0.8 ? Colors.orange : Colors.green),
                  backgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                  minHeight: 8,
                ),
              ),
              if (density > 1.0) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Warning: Field is overstocked!',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],

            if (pasture.notes != null && pasture.notes!.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Pasture Notes:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                pasture.notes!,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryIcon(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value.length > 15 ? '${value.substring(0, 13)}...' : value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  MaterialColor _getStatusColor(PastureStatus status) {
    switch (status) {
      case PastureStatus.available:
        return Colors.green;
      case PastureStatus.occupied:
        return Colors.teal;
      case PastureStatus.resting:
        return Colors.purple;
      case PastureStatus.maintenance:
        return Colors.orange;
    }
  }
}
