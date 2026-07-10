// lib/features/health/screens/health_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/animal_model.dart';
import '../../../../data/models/health_record_model.dart';
import '../../../../data/models/reminder_model.dart';
import '../../../../data/models/weight_record_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../weights/providers/weight_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_edit_health_record_screen.dart';
import 'add_edit_reminder_screen.dart';

final healthHistoryProvider = FutureProvider.family<List<HealthRecord>, int>((ref, animalId) {
  return ref.watch(healthRepositoryProvider).getHealthRecordsForAnimal(animalId);
});

final animalRemindersProvider = FutureProvider.family<List<Reminder>, int>((ref, animalId) {
  return ref.watch(reminderRepositoryProvider).getRemindersForAnimal(animalId);
});

class HealthDashboardScreen extends ConsumerStatefulWidget {
  final Animal animal;

  const HealthDashboardScreen({super.key, required this.animal});

  @override
  ConsumerState<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends ConsumerState<HealthDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to change FAB icon/action dynamically
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getTypeColor(ReminderType type) {
    switch (type) {
      case ReminderType.vaccination: return Colors.blue;
      case ReminderType.deworming: return Colors.green;
      case ReminderType.breeding: return Colors.pink;
      case ReminderType.kidding: return Colors.pinkAccent;
      case ReminderType.weigh: return Colors.orange;
      case ReminderType.vet: return Colors.red;
      case ReminderType.pasture: return Colors.teal;
      case ReminderType.testing: return Colors.indigo;
      case ReminderType.custom: return Colors.purple;
    }
  }

  IconData _getTypeIcon(ReminderType type) {
    switch (type) {
      case ReminderType.vaccination: return Icons.vaccines;
      case ReminderType.deworming: return Icons.bug_report;
      case ReminderType.breeding: return Icons.favorite;
      case ReminderType.kidding: return Icons.child_care;
      case ReminderType.weigh: return Icons.scale;
      case ReminderType.vet: return Icons.local_hospital;
      case ReminderType.pasture: return Icons.landscape;
      case ReminderType.testing: return Icons.biotech;
      case ReminderType.custom: return Icons.event;
    }
  }

  Future<void> _handleCompleteReminder(Reminder reminder) async {
    showDialog(
      context: context,
      builder: (context) {
        final weightController = TextEditingController();
        bool createRecord = true;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Complete Scheduled Event'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mark "${reminder.title}" as completed?'),
                  const SizedBox(height: 16),
                  if (reminder.reminderType == ReminderType.weigh) ...[
                    const Text('Record Weight:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Weight (lbs)',
                        suffixText: 'lbs',
                      ),
                    ),
                  ] else ...[
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

                    // 2. Log weight if weigh-in type
                    if (reminder.reminderType == ReminderType.weigh) {
                      final weight = double.tryParse(weightController.text);
                      if (weight != null) {
                        await ref.read(weightRepositoryProvider).insertWeightRecord(
                          WeightRecord(
                            animalId: widget.animal.id!,
                            weightLbs: weight,
                            weighDate: completedDate,
                            notes: 'Recorded from completed reminder: "${reminder.title}"',
                          ),
                        );
                        ref.invalidate(latestWeightProvider(widget.animal.id!));
                        ref.invalidate(weightHistoryProvider(widget.animal.id!));
                        ref.invalidate(lifetimeADGProvider(widget.animal.id!));
                        ref.invalidate(recentADGProvider(widget.animal.id!));
                        ref.invalidate(milestoneWeightsProvider(widget.animal.id!));
                      }
                    }

                    ref.invalidate(animalRemindersProvider(widget.animal.id!));
                    ref.invalidate(reminderRepositoryProvider);

                    if (context.mounted) {
                      Navigator.pop(context);

                      // 3. Navigate to pre-filled health record
                      if (reminder.reminderType != ReminderType.weigh && createRecord) {
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
                              animal: widget.animal,
                              initialType: hType,
                              initialNotes: 'Completed scheduled event: ${reminder.title}. ${reminder.description ?? ""}',
                            ),
                          ),
                        ).then((_) {
                          ref.invalidate(healthHistoryProvider(widget.animal.id!));
                        });
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
    final healthRecordsAsync = ref.watch(healthHistoryProvider(widget.animal.id!));
    final remindersAsync = ref.watch(animalRemindersProvider(widget.animal.id!));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.animal.name} Health'),
        actions: [
          IconButton(
            icon: Icon(_tabController.index == 0 ? Icons.add : Icons.add_task),
            tooltip: _tabController.index == 0 ? 'Add Health Record' : 'Schedule Event',
            onPressed: () async {
              if (_tabController.index == 0) {
                // Add Health Record
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditHealthRecordScreen(animal: widget.animal),
                  ),
                );
                ref.invalidate(healthHistoryProvider(widget.animal.id!));
              } else {
                // Add Scheduled Reminder
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditReminderScreen(initialAnimalId: widget.animal.id),
                  ),
                );
                if (result == true) {
                  ref.invalidate(animalRemindersProvider(widget.animal.id!));
                }
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'Health History'),
            Tab(icon: Icon(Icons.checklist), text: 'Scheduled Events'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: Health History ─────────────────────────────────────────
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade800,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade900),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Disclaimer: FlockKeeper is a management tool. Dosages and protocols are suggestions based on public data and should NOT be considered professional medical advice. Always consult a licensed veterinarian before treating livestock.\n\n',
                              ),
                              const TextSpan(
                                text: 'Dewormer dosage suggestions are based on the Dewormer Chart for Goats provided by the American Consortium for Small Ruminant Parasite Control. For more information visit ',
                              ),
                              TextSpan(
                                text: 'www.wormx.info',
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () async {
                                    final url = Uri.parse('https://www.wormx.info');
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    }
                                  },
                              ),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: healthRecordsAsync.when(
                  data: (records) {
                    if (records.isEmpty) {
                      return const Center(child: Text('No health records found.'));
                    }
                    return ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: _getRecordIcon(record.recordType),
                            title: Text(record.recordType.name.toUpperCase()),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat.yMMMd().format(record.recordDate)),
                                if (record.treatment != null) Text('Product: ${record.treatment}'),
                                if (record.famachaScore != null) Text('FAMACHA: ${record.famachaScore}'),
                                if (record.bcsScore != null) Text('BCS: ${record.bcsScore}'),
                                if (record.labName != null) Text('Lab: ${record.labName}'),
                                if (record.labReferenceNumber != null) Text('Ref #: ${record.labReferenceNumber}'),
                                if (record.withdrawalDate != null)
                                  Text(
                                    'Withdrawal: ${DateFormat.yMMMd().format(record.withdrawalDate!)} (${record.withdrawalDays ?? 0} days)',
                                    style: TextStyle(
                                      color: record.withdrawalDate!.isAfter(DateTime.now())
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (record.withdrawalDate != null && record.withdrawalDate!.isAfter(DateTime.now()))
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: Chip(label: Text('WITHDRAWAL'), backgroundColor: Colors.red),
                                  ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (val) async {
                                    if (val == 'edit') {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddEditHealthRecordScreen(
                                            animal: widget.animal,
                                            record: record,
                                          ),
                                        ),
                                      );
                                      ref.invalidate(healthHistoryProvider(widget.animal.id!));
                                    } else if (val == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Health Record'),
                                          content: const Text('Are you sure you want to delete this health record? This action cannot be undone.'),
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
                                        await ref.read(healthRepositoryProvider).deleteHealthRecord(record.id!);
                                        ref.invalidate(healthHistoryProvider(widget.animal.id!));
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
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),

          // ─── TAB 2: Scheduled Events ───────────────────────────────────────
          remindersAsync.when(
            data: (reminders) {
              if (reminders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No scheduled events for this animal.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final r = reminders[index];
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          Row(
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
                                  ref.invalidate(animalRemindersProvider(widget.animal.id!));
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
                                  ref.invalidate(animalRemindersProvider(widget.animal.id!));
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
            error: (err, _) => Center(child: Text('Error loading events: $err')),
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
            onPressed: () async {
              if (_tabController.index == 0) {
                // Add Health Record
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditHealthRecordScreen(animal: widget.animal),
                  ),
                );
                ref.invalidate(healthHistoryProvider(widget.animal.id!));
              } else {
                // Add Scheduled Reminder
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditReminderScreen(initialAnimalId: widget.animal.id),
                  ),
                );
                if (result == true) {
                  ref.invalidate(animalRemindersProvider(widget.animal.id!));
                }
              }
            },
            icon: Icon(_tabController.index == 0 ? Icons.add : Icons.add_task),
            label: Text(
              _tabController.index == 0 ? 'Add Record' : 'Schedule Event',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getRecordIcon(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.famacha: return const Icon(Icons.remove_red_eye, color: Colors.pink);
      case HealthRecordType.bcs: return const Icon(Icons.fitness_center, color: Colors.brown);
      case HealthRecordType.vaccination: return const Icon(Icons.vaccines, color: Colors.blue);
      case HealthRecordType.deworming: return const Icon(Icons.bug_report, color: Colors.green);
      case HealthRecordType.antibiotic: return const Icon(Icons.medical_services, color: Colors.orange);
      case HealthRecordType.supplement: return const Icon(Icons.add_moderator, color: Colors.purple);
      case HealthRecordType.labTest: return const Icon(Icons.biotech, color: Colors.teal);
      case HealthRecordType.grooming: return const Icon(Icons.content_cut, color: Colors.blueGrey);
      case HealthRecordType.pregnancyCheck: return const Icon(Icons.child_care, color: Colors.pinkAccent);
      default: return const Icon(Icons.history_edu);
    }
  }
}