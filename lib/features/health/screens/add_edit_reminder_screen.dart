// lib/features/health/screens/add_edit_reminder_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/reminder_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';

class AddEditReminderScreen extends ConsumerStatefulWidget {
  final Reminder? reminder;
  final int? initialAnimalId;

  const AddEditReminderScreen({
    super.key,
    this.reminder,
    this.initialAnimalId,
  });

  @override
  ConsumerState<AddEditReminderScreen> createState() => _AddEditReminderScreenState();
}

class _AddEditReminderScreenState extends ConsumerState<AddEditReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _recurrenceDaysController;
  late TextEditingController _notifyDaysBeforeController;
  
  int? _selectedAnimalId;
  ReminderType _selectedType = ReminderType.vaccination;
  DateTime _reminderDate = DateTime.now().add(const Duration(days: 1));
  bool _isRecurring = false;

  @override
  void initState() {
    super.initState();
    
    final r = widget.reminder;
    _titleController = TextEditingController(text: r?.title ?? '');
    _descriptionController = TextEditingController(text: r?.description ?? '');
    _recurrenceDaysController = TextEditingController(text: r?.recurrenceDays?.toString() ?? '365');
    _notifyDaysBeforeController = TextEditingController(text: r?.notifyDaysBefore.toString() ?? '3');
    
    if (r != null) {
      _selectedAnimalId = r.animalId;
      _selectedType = r.reminderType;
      _reminderDate = r.reminderDate;
      _isRecurring = r.isRecurring;
    } else {
      _selectedAnimalId = widget.initialAnimalId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _recurrenceDaysController.dispose();
    _notifyDaysBeforeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final notifyDays = int.tryParse(_notifyDaysBeforeController.text) ?? 3;
    final recurrence = _isRecurring ? (int.tryParse(_recurrenceDaysController.text) ?? 365) : null;

    final reminder = Reminder(
      id: widget.reminder?.id,
      animalId: _selectedAnimalId,
      title: title,
      description: description.isEmpty ? null : description,
      reminderDate: _reminderDate,
      reminderType: _selectedType,
      isCompleted: widget.reminder?.isCompleted ?? false,
      completedDate: widget.reminder?.completedDate,
      isRecurring: _isRecurring,
      recurrenceDays: recurrence,
      notifyDaysBefore: notifyDays,
    );

    try {
      final repo = ref.read(reminderRepositoryProvider);
      if (widget.reminder != null) {
        await repo.updateReminder(reminder);
      } else {
        await repo.insertReminder(reminder);
      }

      // Invalidate providers
      ref.invalidate(reminderRepositoryProvider);
      
      // Trigger notification check immediately for newly added/updated reminder
      ref.read(notificationServiceProvider).checkRemindersAndNotify();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving reminder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalsAsync = ref.watch(activeAnimalsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reminder != null ? 'Edit Scheduled Event' : 'Schedule Health Event'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Event Title *',
                hintText: 'e.g. CD&T Vaccination Booster',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description / Notes',
                hintText: 'e.g. Dosage details, location, or provider',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Animal Selection (includes General Herd Reminder)
            animalsAsync.when(
              data: (animals) {
                return DropdownButtonFormField<int?>(
                  initialValue: _selectedAnimalId,
                  decoration: const InputDecoration(labelText: 'Target Animal'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('General Herd (All/No Specific Animal)'),
                    ),
                    ...animals.map((a) => DropdownMenuItem<int?>(
                          value: a.id,
                          child: Text('${a.name} (${a.sexDisplay} • ${a.ageString})'),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedAnimalId = val;
                    });
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading animals: $err'),
            ),
            const SizedBox(height: 16),

            // Event Type
            DropdownButtonFormField<ReminderType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'Event Type'),
              items: ReminderType.values
                  .map((t) => DropdownMenuItem<ReminderType>(
                        value: t,
                        child: Text(t.displayName),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedType = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Date Selection
            ListTile(
              title: const Text('Scheduled Date'),
              subtitle: Text(DateFormat.yMMMd().format(_reminderDate)),
              trailing: const Icon(Icons.calendar_today),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _reminderDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 1000)),
                );
                if (picked != null) {
                  setState(() {
                    _reminderDate = picked;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Notify Days Before
            TextFormField(
              controller: _notifyDaysBeforeController,
              decoration: const InputDecoration(
                labelText: 'Notify Days Before *',
                suffixText: 'days before event',
              ),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Required';
                final days = int.tryParse(val);
                if (days == null || days < 0) return 'Must be a positive number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Recurrence Switch
            SwitchListTile(
              title: const Text('Is Recurring Event?'),
              subtitle: const Text('Automatically reschedule event after completion'),
              value: _isRecurring,
              onChanged: (val) {
                setState(() {
                  _isRecurring = val;
                });
              },
            ),

            if (_isRecurring) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _recurrenceDaysController,
                decoration: const InputDecoration(
                  labelText: 'Recurrence Interval (Days) *',
                  suffixText: 'days',
                  hintText: 'e.g. 365 for annual, 30 for monthly',
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (!_isRecurring) return null;
                  if (val == null || val.trim().isEmpty) return 'Required';
                  final days = int.tryParse(val);
                  if (days == null || days <= 0) return 'Must be greater than 0';
                  return null;
                },
              ),
            ],

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Event'),
            ),
          ],
        ),
      ),
    );
  }
}
