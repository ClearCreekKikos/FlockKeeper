// lib/features/health/screens/herd_reminders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/reminder_model.dart';
import '../../../data/models/weight_record_model.dart';
import '../../../data/models/health_record_model.dart';
import '../../../shared/providers/providers.dart';
import '../../weights/providers/weight_providers.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../breeding/screens/voice_command_overlay.dart';
import 'add_edit_reminder_screen.dart';
import 'add_edit_health_record_screen.dart';

final herdRemindersProvider = FutureProvider<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).getAllReminders();
});

class HerdRemindersScreen extends ConsumerStatefulWidget {
  const HerdRemindersScreen({super.key});

  @override
  ConsumerState<HerdRemindersScreen> createState() => _HerdRemindersScreenState();
}

class _HerdRemindersScreenState extends ConsumerState<HerdRemindersScreen> {
  String _statusFilter = 'active'; // 'active', 'overdue', 'upcoming', 'completed', 'all'
  ReminderType? _typeFilter;

  Color _getTypeColor(ReminderType type) {
    switch (type) {
      case ReminderType.vaccination:
        return Colors.blue;
      case ReminderType.deworming:
        return Colors.green;
      case ReminderType.breeding:
        return Colors.pink;
      case ReminderType.kidding:
        return Colors.pinkAccent;
      case ReminderType.weigh:
        return Colors.orange;
      case ReminderType.vet:
        return Colors.red;
      case ReminderType.pasture:
        return Colors.teal;
      case ReminderType.testing:
        return Colors.indigo;
      case ReminderType.custom:
        return Colors.purple;
    }
  }

  IconData _getTypeIcon(ReminderType type) {
    switch (type) {
      case ReminderType.vaccination:
        return Icons.vaccines;
      case ReminderType.deworming:
        return Icons.bug_report;
      case ReminderType.breeding:
        return Icons.favorite;
      case ReminderType.kidding:
        return Icons.child_care;
      case ReminderType.weigh:
        return Icons.scale;
      case ReminderType.vet:
        return Icons.local_hospital;
      case ReminderType.pasture:
        return Icons.landscape;
      case ReminderType.testing:
        return Icons.biotech;
      case ReminderType.custom:
        return Icons.event;
    }
  }

  List<Reminder> _filterReminders(List<Reminder> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return list.where((r) {
      // 1. Type Filter
      if (_typeFilter != null && r.reminderType != _typeFilter) {
        return false;
      }

      // 2. Status Filter
      final reminderDateOnly = DateTime(r.reminderDate.year, r.reminderDate.month, r.reminderDate.day);
      switch (_statusFilter) {
        case 'active':
          return !r.isCompleted;
        case 'overdue':
          return !r.isCompleted && reminderDateOnly.isBefore(today);
        case 'upcoming':
          return !r.isCompleted && !reminderDateOnly.isBefore(today);
        case 'completed':
          return r.isCompleted;
        case 'all':
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _handleCompleteReminder(Reminder reminder) async {
    final hasAnimal = reminder.animalId != null;

    showDialog(
      context: context,
      builder: (context) {
        final weightController = TextEditingController();
        bool createRecord = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Complete Scheduled Event'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mark "${reminder.title}" as completed?'),
                  const SizedBox(height: 16),
                  if (reminder.reminderType == ReminderType.weigh && hasAnimal) ...[
                    Text('Record Weight:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: weightController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Weight (lbs)',
                        suffixText: 'lbs',
                      ),
                    ),
                  ] else if (hasAnimal) ...[
                    CheckboxListTile(
                      title: const Text('Log Health Record'),
                      subtitle: const Text('Pre-fill health record screen'),
                      value: createRecord,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          createRecord = val ?? true;
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final repo = ref.read(reminderRepositoryProvider);
                    final completedDate = DateTime.now();

                    // 1. Mark reminder as completed
                    await repo.completeReminder(reminder.id!, completedDate);

                    // 2. Perform weight record logging if weight-in reminder
                    if (reminder.reminderType == ReminderType.weigh && hasAnimal) {
                      final weight = double.tryParse(weightController.text);
                      if (weight != null) {
                        await ref.read(weightRepositoryProvider).insertWeightRecord(
                          WeightRecord(
                            animalId: reminder.animalId!,
                            weightLbs: weight,
                            weighDate: completedDate,
                            notes: 'Recorded from completed reminder: "${reminder.title}"',
                          ),
                        );
                        // Invalidate weight providers
                        ref.invalidate(latestWeightProvider(reminder.animalId!));
                        ref.invalidate(weightHistoryProvider(reminder.animalId!));
                        ref.invalidate(lifetimeADGProvider(reminder.animalId!));
                        ref.invalidate(recentADGProvider(reminder.animalId!));
                        ref.invalidate(milestoneWeightsProvider(reminder.animalId!));
                      }
                    }

                    ref.invalidate(herdRemindersProvider);
                    ref.invalidate(reminderRepositoryProvider);

                    if (context.mounted) {
                      Navigator.pop(context);

                      // 3. For other types, open prefilled health record if checkmark selected
                      if (reminder.reminderType != ReminderType.weigh && hasAnimal && createRecord) {
                        final animal = await ref.read(animalRepositoryProvider).getAnimalById(reminder.animalId!);
                        if (animal != null && context.mounted) {
                          // Map ReminderType to HealthRecordType
                          HealthRecordType hType;
                          switch (reminder.reminderType) {
                            case ReminderType.vaccination:
                              hType = HealthRecordType.vaccination;
                              break;
                            case ReminderType.deworming:
                              hType = HealthRecordType.deworming;
                              break;
                            case ReminderType.vet:
                              hType = HealthRecordType.vetVisit;
                              break;
                            case ReminderType.testing:
                              final tLower = reminder.title.toLowerCase();
                              if (tLower.contains('famacha')) {
                                hType = HealthRecordType.famacha;
                              } else if (tLower.contains('bcs')) {
                                hType = HealthRecordType.bcs;
                              } else if (tLower.contains('fec') || tLower.contains('fecal')) {
                                hType = HealthRecordType.famacha;
                              } else {
                                hType = HealthRecordType.labTest;
                              }
                              break;
                            default:
                              hType = HealthRecordType.other;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditHealthRecordScreen(
                                animal: animal,
                                initialType: hType,
                                initialNotes: 'Completed scheduled event: ${reminder.title}. ${reminder.description ?? ""}',
                              ),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Complete'),
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
    final remindersAsync = ref.watch(herdRemindersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(currentRoute: 'reminders'),
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Herd Schedule & Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Voice Commands',
            onPressed: () => VoiceCommandOverlay.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Schedule Event',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditReminderScreen()),
              );
              if (result == true) {
                ref.invalidate(herdRemindersProvider);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Filter Section ────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Active Only', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Overdue', 'overdue'),
                const SizedBox(width: 8),
                _buildFilterChip('Upcoming', 'upcoming'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed'),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 16),
                DropdownButton<ReminderType?>(
                  value: _typeFilter,
                  hint: const Text('All Types'),
                  underline: const SizedBox(),
                  onChanged: (val) {
                    setState(() {
                      _typeFilter = val;
                    });
                  },
                  items: [
                    const DropdownMenuItem<ReminderType?>(
                      value: null,
                      child: Text('All Types'),
                    ),
                    ...ReminderType.values.map((t) => DropdownMenuItem<ReminderType?>(
                          value: t,
                          child: Text(t.displayName),
                        )),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          // ─── Timeline/List Section ─────────────────────────────────────────
          Expanded(
            child: remindersAsync.when(
              data: (reminders) {
                final filtered = _filterReminders(reminders);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.checklist, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No scheduled events found.',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    final dateColor = r.isCompleted
                        ? Colors.green
                        : (r.reminderDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _getTypeColor(r.reminderType).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: _getTypeColor(r.reminderType).withValues(alpha: 0.15),
                          child: Icon(_getTypeIcon(r.reminderType), color: _getTypeColor(r.reminderType)),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: r.isCompleted ? TextDecoration.lineThrough : null,
                                  color: r.isCompleted ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ),
                            if (r.isRecurring)
                              const Icon(Icons.sync, size: 16, color: Colors.grey),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (r.description != null && r.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(r.description!, style: const TextStyle(fontSize: 13)),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_month, size: 14, color: dateColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat.yMMMd().format(r.reminderDate),
                                      style: TextStyle(
                                        color: dateColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    r.animalName != null && r.animalName!.isNotEmpty
                                        ? 'Goat: ${r.animalName}'
                                        : 'Herd-wide',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!r.isCompleted)
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                tooltip: 'Mark Completed',
                                onPressed: () => _handleCompleteReminder(r),
                              ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddEditReminderScreen(reminder: r),
                                    ),
                                  );
                                  if (result == true) {
                                    ref.invalidate(herdRemindersProvider);
                                  }
                                } else if (val == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Event'),
                                      content: const Text('Are you sure you want to delete this scheduled event?'),
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

                                  if (confirm == true) {
                                    await ref.read(reminderRepositoryProvider).deleteReminder(r.id!);
                                    ref.invalidate(herdRemindersProvider);
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading schedule: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    final primary = Theme.of(context).colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _statusFilter = value;
          });
        }
      },
      selectedColor: primary.withValues(alpha: 0.2),
      checkmarkColor: primary,
    );
  }
}
