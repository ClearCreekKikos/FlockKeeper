import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/providers/animal_providers.dart';
import '../../../data/models/animal_model.dart';
import '../../../shared/providers/providers.dart';
import '../../weights/providers/weight_providers.dart';
import '../../../data/models/weight_record_model.dart';
import '../../weights/screens/weight_history_screen.dart';
import '../../health/screens/health_dashboard_screen.dart';
import 'package:flockkeeper/features/settings/screens/settings_screen.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../breeding/screens/breeding_dashboard_screen.dart';
import '../../breeding/screens/voice_command_overlay.dart';
import '../../export/screens/pdf_preview_screen.dart';
import '../../production/screens/milking_dashboard_screen.dart';
import '../../production/screens/meat_dashboard_screen.dart';
import '../../settings/screens/subscription_paywall_screen.dart';
import '../../microchip/widgets/scan_listener_dialog.dart';
import 'add_edit_animal_screen.dart';
import 'pedigree_tree_screen.dart';
import '../../../data/models/pasture_model.dart';
import '../../../shared/utils/path_resolver.dart';

class AnimalListScreen extends ConsumerWidget {
  const AnimalListScreen({super.key});

  void _showQuickAddWeightDialog(BuildContext context, WidgetRef ref, int animalId) {
    final weightController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: const Text('Record Weight'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Weight (lbs)', suffixText: 'lbs'),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Text(DateFormat.yMMMd().format(selectedDate)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final weight = double.tryParse(weightController.text);
                if (weight != null) {
                  await ref.read(weightRepositoryProvider).insertWeightRecord(
                        WeightRecord(
                          animalId: animalId,
                          weightLbs: weight,
                          weighDate: selectedDate,
                        ),
                      );
                  ref.invalidate(latestWeightProvider(animalId));
                  ref.invalidate(weightHistoryProvider(animalId));
                  ref.invalidate(lifetimeADGProvider(animalId));
                  ref.invalidate(recentADGProvider(animalId));
                  ref.invalidate(milestoneWeightsProvider(animalId));
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteAnimal(BuildContext context, WidgetRef ref, Animal animal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Animal'),
        content: Text(
          'Are you sure you want to permanently delete ${animal.name}? '
          'This will also delete all of their weight history, health records, '
          'breeding records, and notes.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(animalRepositoryProvider);
      await repo.deleteAnimal(animal.id!);
      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);
      ref.invalidate(searchedAnimalsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${animal.name} deleted successfully.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animalsAsync = ref.watch(searchedAnimalsProvider);
    final searchQuery = ref.watch(animalSearchQueryProvider);
    final settings = ref.watch(settingsStateProvider);
    final logoPath = PathResolver.resolvePath(settings['farm_logo_path']);

    return Scaffold(
      drawer: const AppDrawer(currentRoute: 'animals'),
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: (logoPath != null && File(logoPath).existsSync())
                    ? FileImage(File(logoPath)) as ImageProvider
                    : const AssetImage('assets/images/home_logo.png'),
                backgroundColor: Colors.transparent,
              ),
            ),
            Expanded(
              child: Text(
                settings['farm_name'] ?? 'FlockKeeper',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Voice Commands',
            onPressed: () => VoiceCommandOverlay.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Animal',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditAnimalScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Breeding Manager',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BreedingDashboardScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final isPremium = ref.read(settingsStateProvider)['is_premium'] == 'true';
          if (!isPremium) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
            );
          } else {
            ScanListenerDialog.show(context);
          }
        },
        backgroundColor: Colors.blueGrey,
        tooltip: 'Scan EID Microchip',
        child: const Icon(Icons.sensors, color: Colors.white),
      ),
      body: Column(
        children: [
          // ─── Search Bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search animals...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                ref.read(animalSearchQueryProvider.notifier).state = '';
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      ref.read(animalSearchQueryProvider.notifier).state = value;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<AnimalStatus>(
                    initialValue: ref.watch(animalStatusFilterProvider),
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: AnimalStatus.active, child: Text('Active')),
                      DropdownMenuItem(value: AnimalStatus.deceased, child: Text('Deceased')),
                      DropdownMenuItem(value: AnimalStatus.sold, child: Text('Sold')),
                      DropdownMenuItem(value: AnimalStatus.ancestor, child: Text('Ancestor')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(animalStatusFilterProvider.notifier).state = v;
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // ─── Animal List ───────────────────────────────────────────────────
          Expanded(
            child: animalsAsync.when(
              data: (animals) {
                if (animals.isEmpty) {
                  return const Center(
                    child: Text('No animals found'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(searchedAnimalsProvider);
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: animals.length,
                    itemBuilder: (context, index) {
                      final animal = animals[index];

                      return Dismissible(
                        key: ValueKey('animal_${animal.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24.0),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Animal'),
                              content: Text(
                                'Are you sure you want to permanently delete ${animal.name}? '
                                'This will also delete all of their weight history, health records, '
                                'breeding records, and notes.\n\nThis action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          final repo = ref.read(animalRepositoryProvider);
                          await repo.deleteAnimal(animal.id!);
                          ref.invalidate(animalsProvider);
                          ref.invalidate(activeAnimalsProvider);
                          ref.invalidate(searchedAnimalsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${animal.name} deleted successfully.',
                                ),
                              ),
                            );
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage: animal.photoPath != null && File(animal.photoPath!).existsSync()
                                  ? FileImage(File(animal.photoPath!))
                                  : null,
                              child: animal.photoPath == null || !File(animal.photoPath!).existsSync()
                                  ? const Icon(Icons.pets, size: 28)
                                  : null,
                            ),

                            title: Text(
                              animal.earTag != null && animal.earTag!.isNotEmpty
                                  ? '${animal.name} - ${animal.earTag}'
                                  : animal.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${animal.sexDisplay} • ${animal.ageString}',
                                ),
                                if (animal.earTag != null &&
                                    animal.earTag!.isNotEmpty)
                                  Text('Ear Tag: ${animal.earTag}'),
                                if (animal.tattoo != null &&
                                    animal.tattoo!.isNotEmpty)
                                  Text('Tattoo: ${animal.tattoo}'),
                                if (animal.rfidTag != null &&
                                    animal.rfidTag!.isNotEmpty)
                                  Text('EID: ${animal.rfidTag}'),

                                if (animal.nkrRegNumber != null &&
                                    animal.nkrRegNumber!.isNotEmpty)
                                  Text('${animal.registry ?? 'NKR'}: ${animal.nkrRegNumber}'),
                                if (animal.secondRegNumber != null &&
                                    animal.secondRegNumber!.isNotEmpty)
                                  Text('${animal.secondRegistry ?? 'Reg 2'}: ${animal.secondRegNumber}'),
                                ref.watch(latestWeightProvider(animal.id!)).when(
                                      data: (weight) => weight != null
                                          ? Text(
                                              'Weight: ${weight.weightLbs} lbs',
                                              style: const TextStyle(fontSize: 12),
                                            )
                                          : const SizedBox.shrink(),
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, _) => const SizedBox.shrink(),
                                    ),
                                ref.watch(animalPastureProvider(animal.id!)).when(
                                      data: (pasture) => pasture != null
                                          ? Padding(
                                              padding: const EdgeInsets.only(top: 2.0),
                                              child: Text(
                                                'Pasture: ${pasture.name}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal,
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, _) => const SizedBox.shrink(),
                                    ),
                              ],
                            ),

                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      animal.statusDisplay,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _statusColor(animal.statusDisplay),
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.account_tree_outlined),
                                  tooltip: 'View Pedigree',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PedigreeTreeScreen(animal: animal),
                                      ),
                                    );
                                  },
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  tooltip: 'Actions',
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'milking':
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MilkingDashboardScreen(animal: animal),
                                          ),
                                        );
                                        break;
                                      case 'meat':
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MeatDashboardScreen(animal: animal),
                                          ),
                                        );
                                        break;
                                      case 'pedigree':
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PedigreeTreeScreen(animal: animal),
                                          ),
                                        );
                                        break;
                                      case 'health':
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => HealthDashboardScreen(animal: animal),
                                          ),
                                        );
                                        break;
                                      case 'quick_weight':
                                        _showQuickAddWeightDialog(context, ref, animal.id!);
                                        break;
                                      case 'weight_history':
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => WeightDashboardScreen(animal: animal),
                                          ),
                                        );
                                        break;
                                      case 'export':
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PdfPreviewScreen(animal: animal),
                                          ),
                                        );
                                        break;
                                      case 'delete':
                                        _confirmAndDeleteAnimal(context, ref, animal);
                                        break;
                                      case 'move_pasture':
                                        _showMovePastureDialog(context, ref, animal);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (settings['module_milking_enabled'] == 'true')
                                      const PopupMenuItem(
                                        value: 'milking',
                                        child: Row(
                                          children: [
                                            Icon(Icons.opacity, size: 20),
                                            SizedBox(width: 8),
                                            Text('Milking Records'),
                                          ],
                                        ),
                                      ),
                                    if (settings['module_meat_enabled'] == 'true')
                                      const PopupMenuItem(
                                        value: 'meat',
                                        child: Row(
                                          children: [
                                            Icon(Icons.restaurant, size: 20),
                                            SizedBox(width: 8),
                                            Text('Meat Records'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'pedigree',
                                      child: Row(
                                        children: [
                                          Icon(Icons.account_tree_outlined, size: 20),
                                          SizedBox(width: 8),
                                          Text('View Pedigree'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'health',
                                      child: Row(
                                        children: [
                                          Icon(Icons.medical_information_outlined, size: 20),
                                          SizedBox(width: 8),
                                          Text('Health Records'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'quick_weight',
                                      child: Row(
                                        children: [
                                          Icon(Icons.add_chart, size: 20),
                                          SizedBox(width: 8),
                                          Text('Quick Add Weight'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'weight_history',
                                      child: Row(
                                        children: [
                                          Icon(Icons.scale_outlined, size: 20),
                                          SizedBox(width: 8),
                                          Text('Weight History'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'export',
                                      child: Row(
                                        children: [
                                          Icon(Icons.picture_as_pdf_outlined, size: 20),
                                          SizedBox(width: 8),
                                          Text('Export Certificate'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'move_pasture',
                                      child: Row(
                                        children: [
                                          Icon(Icons.landscape_outlined, size: 20),
                                          SizedBox(width: 8),
                                          Text('Move Pasture'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Delete Animal',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // ─── Tap to Edit ──────────────────────────────────
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddEditAnimalScreen(animal: animal),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },

              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),

              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditAnimalScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Goat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  // ─── Status Color Helper ──────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'sold':
        return Colors.blue;
      case 'deceased':
        return Colors.red;
      case 'culled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showMovePastureDialog(BuildContext context, WidgetRef ref, Animal animal) async {
    final repo = ref.read(pastureRepositoryProvider);
    final pasturesAsync = await repo.getAllPastures();
    if (pasturesAsync.isEmpty) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Move Pasture'),
            content: const Text('No pastures created yet. Please create a pasture first.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      DateTime selectedDate = DateTime.now();
      String forageCondition = 'good';
      Pasture? selectedPasture;

      // Find current pasture
      final currentPasture = await repo.getPastureForAnimal(animal.id!);

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text('Move ${animal.name}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<Pasture>(
                        initialValue: selectedPasture,
                        decoration: const InputDecoration(
                          labelText: 'Select Pasture',
                          border: OutlineInputBorder(),
                        ),
                        items: pasturesAsync.map((p) {
                          final isCurrent = currentPasture?.id == p.id;
                          return DropdownMenuItem<Pasture>(
                            value: p,
                            child: Text(isCurrent ? '${p.name} (Current)' : p.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedPasture = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Date'),
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
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (selectedPasture == null) return;
                        await repo.moveAnimalIntoPasture(
                          animalId: animal.id!,
                          pastureId: selectedPasture!.id!,
                          moveInDate: selectedDate,
                          forageConditionIn: forageCondition,
                        );
                        ref.invalidate(animalPastureProvider(animal.id!));
                        ref.invalidate(pasturesListProvider);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Move'),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    }
  }
}
