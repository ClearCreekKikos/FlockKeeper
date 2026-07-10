import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/animal_model.dart';
import '../../../data/models/breeding_event_model.dart';
import '../../../data/models/kidding_record_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';
import '../providers/breeding_providers.dart';

class KidFormState {
  final nameController = TextEditingController();
  final earTagController = TextEditingController();
  final tattooController = TextEditingController();
  final weightController = TextEditingController();
  KidSex sex = KidSex.doe;
  Presentation presentation = Presentation.normal;
  SurvivalStatus survivalStatus = SurvivalStatus.alive;
  bool receivedColostrum = true;
  bool bottleFed = false;

  void dispose() {
    nameController.dispose();
    earTagController.dispose();
    tattooController.dispose();
    weightController.dispose();
  }
}

class RecordKiddingScreen extends ConsumerStatefulWidget {
  final BreedingEvent? breedingEvent;

  const RecordKiddingScreen({super.key, this.breedingEvent});

  @override
  ConsumerState<RecordKiddingScreen> createState() => _RecordKiddingScreenState();
}

class _RecordKiddingScreenState extends ConsumerState<RecordKiddingScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _kiddingDate = DateTime.now();
  int _litterSize = 1;
  int? _damConditionScore;
  final _complicationsController = TextEditingController();
  final _notesController = TextEditingController();

  final List<KidFormState> _kids = [KidFormState()];

  int? _selectedDoeId;
  int? _selectedBuckId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.breedingEvent != null) {
      _selectedDoeId = widget.breedingEvent!.doeId;
      _selectedBuckId = widget.breedingEvent!.buckId;
    }
  }

  @override
  void dispose() {
    _complicationsController.dispose();
    _notesController.dispose();
    for (var kid in _kids) {
      kid.dispose();
    }
    super.dispose();
  }

  void _updateLitterSize(int newSize) {
    setState(() {
      _litterSize = newSize;
      while (_kids.length < newSize) {
        _kids.add(KidFormState());
      }
      while (_kids.length > newSize) {
        final removed = _kids.removeLast();
        removed.dispose();
      }
    });
  }

  Future<void> _selectKiddingDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _kiddingDate,
      firstDate: widget.breedingEvent?.breedingDate ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _kiddingDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final breedingRepo = ref.read(breedingRepositoryProvider);
    final kiddingRepo = ref.read(kiddingRepositoryProvider);
    final animalRepo = ref.read(animalRepositoryProvider);

    if (_selectedDoeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Dam (Doe).')),
      );
      return;
    }

    // Guard against re-recording a kidding for an event that has already
    // been marked kidded, which would duplicate kid animals and records.
    if (widget.breedingEvent?.outcome == BreedingOutcome.kidded) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kidding already recorded'),
          content: const Text(
            'This breeding event is already marked as kidded. Saving again '
            'will create duplicate kid animals and kidding records. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);
    try {
      // 1. Update breeding event status to kidded if present
      if (widget.breedingEvent != null) {
        final updatedBreedingEvent = widget.breedingEvent!.copyWith(
          actualKidDate: _kiddingDate,
          outcome: BreedingOutcome.kidded,
          updatedAt: DateTime.now(),
        );
        await breedingRepo.updateBreedingEvent(updatedBreedingEvent);
      }

      // Fetch names of doe and buck for kid registration
      final doeRecord = await animalRepo.getAnimalById(_selectedDoeId!);
      final doeName = doeRecord?.name ?? 'Doe #$_selectedDoeId';

      String? buckName;
      if (_selectedBuckId != null) {
        final buckRecord = await animalRepo.getAnimalById(_selectedBuckId!);
        buckName = buckRecord?.name;
      }

      // 2. Loop through and create animal records + kidding records
      for (int i = 0; i < _kids.length; i++) {
        final kidForm = _kids[i];
        int? kidAnimalId;

        // If alive, register this kid as a new Animal in the herd database!
        if (kidForm.survivalStatus == SurvivalStatus.alive ||
            kidForm.survivalStatus == SurvivalStatus.sold) {
          final now = DateTime.now();
          final kidAnimal = Animal(
            name: kidForm.nameController.text.trim().isNotEmpty 
                ? kidForm.nameController.text.trim()
                : 'Kid ${i + 1} of $doeName',
            earTag: kidForm.earTagController.text.trim().isNotEmpty
                ? kidForm.earTagController.text.trim()
                : null,
            tattoo: kidForm.tattooController.text.trim().isNotEmpty
                ? kidForm.tattooController.text.trim()
                : null,
            dob: _kiddingDate,
            sex: kidForm.sex == KidSex.doe
                ? Sex.doe
                : kidForm.sex == KidSex.buck
                    ? Sex.buck
                    : Sex.unknown,
            damId: _selectedDoeId,
            sireId: _selectedBuckId,
            damName: doeName,
            sireName: buckName,
            birthWeightLbs: double.tryParse(kidForm.weightController.text.trim()),
            createdAt: now,
            updatedAt: now,
          );
          
          kidAnimalId = await animalRepo.insertAnimal(kidAnimal);
        }

        // Save kidding record
        final kiddingRecord = KiddingRecord(
          breedingEventId: widget.breedingEvent?.id,
          doeId: _selectedDoeId!,
          buckId: _selectedBuckId,
          kidId: kidAnimalId,
          kidName: kidForm.nameController.text.trim(),
          kiddingDate: _kiddingDate,
          birthOrder: i + 1,
          litterSize: _litterSize,
          birthWeightLbs: double.tryParse(kidForm.weightController.text.trim()),
          sex: kidForm.sex,
          birthType: _getBirthType(_litterSize),
          presentation: kidForm.presentation,
          survivalStatus: kidForm.survivalStatus,
          receivedColostrum: kidForm.receivedColostrum,
          bottleFed: kidForm.bottleFed,
          damConditionScore: _damConditionScore,
          complications: _complicationsController.text.trim(),
          notes: _notesController.text.trim(),
          createdAt: DateTime.now(),
        );

        await kiddingRepo.insertKiddingRecord(kiddingRecord);
      }

      // Invalidate providers so lists refresh
      ref.invalidate(breedingListProvider);
      ref.invalidate(kiddingRecordsListProvider);
      ref.invalidate(breedingStatsProvider);
      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);
      ref.invalidate(searchedAnimalsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kidding successfully recorded and kids registered.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording kidding: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  BirthType _getBirthType(int size) {
    if (size == 1) return BirthType.single;
    if (size == 2) return BirthType.twin;
    if (size == 3) return BirthType.triplet;
    if (size == 4) return BirthType.quad;
    return BirthType.other;
  }

  @override
  Widget build(BuildContext context) {
    final activeDoes = ref.watch(activeDoesProvider);
    final activeBucks = ref.watch(activeBucksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Kidding Event'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Dam Details Summary (if breedingEvent is present) or Selectors (if direct log)
            widget.breedingEvent != null
                ? Card(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dam: ${widget.breedingEvent!.doeName ?? "Doe #${widget.breedingEvent!.doeId}"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text('Sire: ${widget.breedingEvent!.buckName ?? "Buck #${widget.breedingEvent!.buckId}"}'),
                          Text('Bred On: ${DateFormat.yMMMd().format(widget.breedingEvent!.breedingDate)}'),
                        ],
                      ),
                    ),
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log Kidding Directly',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedDoeId,
                            decoration: const InputDecoration(
                              labelText: 'Select Dam (Doe) *',
                              border: OutlineInputBorder(),
                            ),
                            items: activeDoes.map((doe) {
                              return DropdownMenuItem<int>(
                                value: doe.id,
                                child: Text(doe.displayName),
                              );
                            }).toList(),
                            validator: (v) => v == null ? 'Dam (Doe) is required' : null,
                            onChanged: (val) {
                              setState(() {
                                _selectedDoeId = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedBuckId,
                            decoration: const InputDecoration(
                              labelText: 'Select Sire (Buck) - Optional',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<int>(
                                value: null,
                                child: Text('Unknown / Not Listed'),
                              ),
                              ...activeBucks.map((buck) {
                                return DropdownMenuItem<int>(
                                  value: buck.id,
                                  child: Text(buck.displayName),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedBuckId = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 16),

            // Kidding Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kidding Date *'),
              subtitle: Text(DateFormat.yMMMd().format(_kiddingDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectKiddingDate(context),
            ),
            const SizedBox(height: 8),

            // Litter Size Selection
            DropdownButtonFormField<int>(
              initialValue: _litterSize,
              decoration: const InputDecoration(labelText: 'Litter Size (Number of Kids) *'),
              items: [1, 2, 3, 4, 5].map((s) {
                return DropdownMenuItem(value: s, child: Text('$s'));
              }).toList(),
              onChanged: (val) {
                if (val != null) _updateLitterSize(val);
              },
            ),
            const SizedBox(height: 12),

            // Dam BCS
            DropdownButtonFormField<int>(
              initialValue: _damConditionScore,
              decoration: const InputDecoration(labelText: 'Dam Condition Score at Kidding'),
              items: [1, 2, 3, 4, 5].map((s) {
                return DropdownMenuItem(value: s, child: Text('$s'));
              }).toList(),
              onChanged: (val) => setState(() => _damConditionScore = val),
            ),
            const SizedBox(height: 24),

            // ─── Kid Details List ─────────────────────────────────────────────
            const Text(
              'Kids Information',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
            ),
            const Divider(),
            const SizedBox(height: 8),

            ...List.generate(_litterSize, (index) {
              final kidForm = _kids[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kid #${index + 1} Details',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
                      ),
                      const SizedBox(height: 8),
                      
                      // Kid name (conditional on survival)
                      if (kidForm.survivalStatus == SurvivalStatus.alive ||
                          kidForm.survivalStatus == SurvivalStatus.sold)
                        TextFormField(
                          controller: kidForm.nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Registered Name *',
                            hintText: 'e.g. Blue Ridge Sterling II',
                          ),
                          validator: (v) => (kidForm.survivalStatus == SurvivalStatus.alive ||
                                  kidForm.survivalStatus == SurvivalStatus.sold) &&
                                  (v == null || v.isEmpty)
                              ? 'Required for active records'
                              : null,
                        ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: kidForm.earTagController,
                              decoration: const InputDecoration(labelText: 'Ear Tag'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: kidForm.tattooController,
                              decoration: const InputDecoration(labelText: 'Tattoo'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: kidForm.weightController,
                        decoration: const InputDecoration(labelText: 'Birth Weight (lbs)', suffixText: 'lbs'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 8),

                      DropdownButtonFormField<KidSex>(
                        initialValue: kidForm.sex,
                        decoration: const InputDecoration(labelText: 'Sex'),
                        items: const [
                          DropdownMenuItem(value: KidSex.doe, child: Text('Doe (Female)')),
                          DropdownMenuItem(value: KidSex.buck, child: Text('Buck (Male)')),
                          DropdownMenuItem(value: KidSex.unknown, child: Text('Unknown')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => kidForm.sex = val);
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Presentation>(
                        initialValue: kidForm.presentation,
                        decoration: const InputDecoration(labelText: 'Presentation'),
                        items: const [
                          DropdownMenuItem(value: Presentation.normal, child: Text('Normal')),
                          DropdownMenuItem(value: Presentation.malpresentation, child: Text('Malpresentation')),
                          DropdownMenuItem(value: Presentation.assisted, child: Text('Assisted')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => kidForm.presentation = val);
                        },
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 8),

                      DropdownButtonFormField<SurvivalStatus>(
                        initialValue: kidForm.survivalStatus,
                        decoration: const InputDecoration(labelText: 'Survival Status'),
                        items: SurvivalStatus.values.map((status) {
                          String label = 'Alive';
                          if (status == SurvivalStatus.diedAtBirth) label = 'Died at Birth';
                          if (status == SurvivalStatus.diedWithin24h) label = 'Died within 24 Hours';
                          if (status == SurvivalStatus.diedWithinWeek) label = 'Died within a Week';
                          if (status == SurvivalStatus.diedLater) label = 'Died Later';
                          if (status == SurvivalStatus.sold) label = 'Sold';
                          return DropdownMenuItem(value: status, child: Text(label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => kidForm.survivalStatus = val);
                        },
                      ),
                      const SizedBox(height: 8),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Wrap(
                          spacing: 16.0,
                          runSpacing: 4.0,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: kidForm.receivedColostrum,
                                  onChanged: (val) => setState(() => kidForm.receivedColostrum = val ?? true),
                                ),
                                const Text('Received Colostrum', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: kidForm.bottleFed,
                                  onChanged: (val) => setState(() => kidForm.bottleFed = val ?? false),
                                ),
                                const Text('Bottle Fed', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const Divider(),
            const SizedBox(height: 8),

            TextFormField(
              controller: _complicationsController,
              decoration: const InputDecoration(labelText: 'Birth Complications (If Any)'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'General Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Kidding Records'),
            ),
          ],
        ),
      ),
    );
  }
}
