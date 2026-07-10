import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/breeding_event_model.dart';
import '../../../shared/providers/providers.dart';
import '../providers/breeding_providers.dart';

class AddEditBreedingScreen extends ConsumerStatefulWidget {
  final BreedingEvent? breedingEvent;

  const AddEditBreedingScreen({super.key, this.breedingEvent});

  @override
  ConsumerState<AddEditBreedingScreen> createState() => _AddEditBreedingScreenState();
}

class _AddEditBreedingScreenState extends ConsumerState<AddEditBreedingScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedDoeId;
  int? _selectedBuckId;
  String? _externalBuckName;
  bool _useExternalBuck = false;

  DateTime _breedingDate = DateTime.now();
  DateTime? _expectedKidDate;
  BreedingMethod _selectedMethod = BreedingMethod.natural;

  bool _confirmedPregnant = false;
  DateTime? _confirmationDate;
  String? _selectedConfirmationMethod;
  BreedingOutcome? _selectedOutcome;
  final _notesController = TextEditingController();

  DateTime? _cidrInsertedDate;
  DateTime? _cidrRemovedDate;
  String? _selectedHormone;
  late TextEditingController _prepHormonesOtherController;

  static const List<String> _hormoneOptions = [
    'Lutalyse (Dinoprost)',
    'Estrumate (Cloprostenol)',
    'PG600 (eCG + hCG)',
    'GnRH (Cystorelin)',
    'GnRH (Factrel)',
    'CIDR + PGF2α Protocol',
    'MGA (Melengestrol Acetate)',
    'Melatonin Implant',
    'Lutalyse + GnRH',
    'PG600 + CIDR',
    'None',
    'Other',
  ];

  final List<String> _confirmationMethods = ['Ultrasound', 'Blood Test (BioPRYN)', 'Physical/Teasing', 'Other'];

  @override
  void initState() {
    super.initState();
    _prepHormonesOtherController = TextEditingController();

    if (widget.breedingEvent != null) {
      final e = widget.breedingEvent!;
      _selectedDoeId = e.doeId;
      _selectedBuckId = e.buckId;
      _externalBuckName = e.buckName;
      _useExternalBuck = e.buckId == null && e.buckName != null;
      _breedingDate = e.breedingDate;
      _expectedKidDate = e.expectedKidDate;
      _selectedMethod = e.method;
      _confirmedPregnant = e.confirmedPregnant;
      _confirmationDate = e.confirmationDate;
      _selectedConfirmationMethod = e.confirmationMethod;
      _selectedOutcome = e.outcome;

      final notesText = e.notes ?? '';
      final cidrInsertRegex = RegExp(r'CIDR Inserted:\s*([0-9\-]+)');
      final cidrInsertMatch = cidrInsertRegex.firstMatch(notesText);
      if (cidrInsertMatch != null) {
        _cidrInsertedDate = DateTime.tryParse(cidrInsertMatch.group(1)!);
      }

      final cidrRemoveRegex = RegExp(r'CIDR Removed:\s*([0-9\-]+)');
      final cidrRemoveMatch = cidrRemoveRegex.firstMatch(notesText);
      if (cidrRemoveMatch != null) {
        _cidrRemovedDate = DateTime.tryParse(cidrRemoveMatch.group(1)!);
      }

      final hormonesRegex = RegExp(r'Prep Hormones:\s*([^\n]+)');
      final hormonesMatch = hormonesRegex.firstMatch(notesText);
      if (hormonesMatch != null) {
        final parsed = hormonesMatch.group(1)?.trim() ?? '';
        if (_hormoneOptions.contains(parsed)) {
          _selectedHormone = parsed;
        } else if (parsed.isNotEmpty) {
          _selectedHormone = 'Other';
          _prepHormonesOtherController.text = parsed;
        }
      }

      String displayNotes = notesText;
      final prepBlockRegex = RegExp(r'=== BREEDING PREP ===[\s\S]*?=====================\n\n?');
      displayNotes = displayNotes.replaceAll(prepBlockRegex, '');
      _notesController.text = displayNotes.trim();
    } else {
      _calculateExpectedDate();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _prepHormonesOtherController.dispose();
    super.dispose();
  }

  void _calculateExpectedDate() {
    setState(() {
      _expectedKidDate = BreedingEvent.calculateExpectedKidDate(_breedingDate);
    });
  }

  Future<void> _selectBreedingDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _breedingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _breedingDate = picked;
        _calculateExpectedDate();
      });
    }
  }

  Future<void> _selectExpectedDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedKidDate ?? DateTime.now().add(const Duration(days: 150)),
      firstDate: _breedingDate,
      lastDate: _breedingDate.add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() {
        _expectedKidDate = picked;
      });
    }
  }

  Future<void> _selectConfirmationDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _confirmationDate ?? DateTime.now(),
      firstDate: _breedingDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _confirmationDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDoeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Doe (Dam)')),
      );
      return;
    }

    if (!_useExternalBuck && _selectedBuckId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Sire (Buck)')),
      );
      return;
    }

    final repo = ref.read(breedingRepositoryProvider);

    // Fetch names dynamically for local redundancy
    final does = ref.read(activeDoesProvider);
    final bucks = ref.read(activeBucksProvider);
    
    final doeName = does.firstWhere((d) => d.id == _selectedDoeId).name;
    final String buckName = _useExternalBuck 
        ? (_externalBuckName ?? 'External Sire') 
        : bucks.firstWhere((b) => b.id == _selectedBuckId).name;

    final breedingEvent = BreedingEvent(
      id: widget.breedingEvent?.id,
      doeId: _selectedDoeId!,
      buckId: _useExternalBuck ? null : _selectedBuckId,
      doeName: doeName,
      buckName: buckName,
      breedingDate: _breedingDate,
      expectedKidDate: _expectedKidDate,
      actualKidDate: widget.breedingEvent?.actualKidDate,
      method: _selectedMethod,
      confirmedPregnant: _confirmedPregnant,
      confirmationDate: _confirmationDate,
      confirmationMethod: _selectedConfirmationMethod,
      outcome: _confirmedPregnant 
          ? (_selectedOutcome == BreedingOutcome.kidded ? BreedingOutcome.kidded : null) 
          : _selectedOutcome,
      notes: () {
        String prepText = '';
        if (_cidrInsertedDate != null) {
          prepText += 'CIDR Inserted: ${DateFormat('yyyy-MM-dd').format(_cidrInsertedDate!)}\n';
        }
        if (_cidrRemovedDate != null) {
          prepText += 'CIDR Removed: ${DateFormat('yyyy-MM-dd').format(_cidrRemovedDate!)}\n';
        }
        final hormones = _selectedHormone == 'Other'
            ? _prepHormonesOtherController.text.trim()
            : (_selectedHormone ?? '');
        if (hormones.isNotEmpty && hormones != 'None') {
          prepText += 'Prep Hormones: $hormones\n';
        }
        if (prepText.isNotEmpty) {
          prepText = '=== BREEDING PREP ===\n$prepText=====================\n\n';
        }
        return '$prepText${_notesController.text.trim()}';
      }(),
      createdAt: widget.breedingEvent?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.breedingEvent == null) {
        await repo.insertBreedingEvent(breedingEvent);
      } else {
        await repo.updateBreedingEvent(breedingEvent);
      }
      ref.invalidate(breedingListProvider);
      ref.invalidate(breedingStatsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving breeding event: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final does = ref.watch(activeDoesProvider);
    final bucks = ref.watch(activeBucksProvider);
    final isEditing = widget.breedingEvent != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Breeding Event' : 'Log Breeding Event'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Doe Selection ────────────────────────────────────────────────
            DropdownButtonFormField<int>(
              initialValue: _selectedDoeId,
              decoration: const InputDecoration(labelText: 'Doe (Dam) *'),
              items: does.map((d) {
                return DropdownMenuItem(
                  value: d.id,
                  child: Text(d.displayName),
                );
              }).toList(),
              onChanged: isEditing ? null : (val) => setState(() => _selectedDoeId = val),
              validator: (v) => v == null ? 'Selection required' : null,
            ),
            const SizedBox(height: 16),

            // ─── Buck Option Switch ──────────────────────────────────────────
            SwitchListTile(
              title: const Text('Use External Buck / Semen Straw'),
              subtitle: const Text('Check this if the sire is not in your active herd'),
              value: _useExternalBuck,
              onChanged: (val) {
                setState(() {
                  _useExternalBuck = val;
                  if (val) {
                    _selectedBuckId = null;
                  } else {
                    _externalBuckName = null;
                  }
                });
              },
            ),
            const SizedBox(height: 8),

            // ─── Buck Selection ───────────────────────────────────────────────
            if (_useExternalBuck)
              TextFormField(
                initialValue: _externalBuckName,
                decoration: const InputDecoration(
                  labelText: 'External Buck Name / Tag / Straw ID *',
                  hintText: 'e.g. Ridgetop Sterling',
                ),
                onChanged: (v) => _externalBuckName = v,
                validator: (v) => _useExternalBuck && (v == null || v.isEmpty) ? 'Required' : null,
              )
            else
              DropdownButtonFormField<int>(
                initialValue: _selectedBuckId,
                decoration: const InputDecoration(labelText: 'Sire (Active Buck) *'),
                items: bucks.map((b) {
                  return DropdownMenuItem(
                    value: b.id,
                    child: Text(b.displayName),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedBuckId = val),
                validator: (v) => !_useExternalBuck && v == null ? 'Selection required' : null,
              ),
            const SizedBox(height: 16),

            // ─── Method ──────────────────────────────────────────────────────
            DropdownButtonFormField<BreedingMethod>(
              initialValue: _selectedMethod,
              decoration: const InputDecoration(labelText: 'Breeding Method'),
              items: BreedingMethod.values.map((m) {
                String label = 'Natural Service';
                if (m == BreedingMethod.ai) label = 'Artificial Insemination (AI)';
                if (m == BreedingMethod.embryoTransfer) label = 'Embryo Transfer (ET)';
                return DropdownMenuItem(
                  value: m,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedMethod = val!),
            ),
            const SizedBox(height: 16),

            // ─── Breeding Date ───────────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Breeding Date'),
              subtitle: Text(DateFormat.yMMMd().format(_breedingDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectBreedingDate(context),
            ),

            // ─── Expected Kidding Date ───────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expected Kidding Date'),
              subtitle: Text(_expectedKidDate == null 
                  ? 'Calculating...' 
                  : DateFormat.yMMMd().format(_expectedKidDate!)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () => _selectExpectedDate(context),
            ),
            const Divider(),
            const SizedBox(height: 8),

            // ─── Breeding Preparation ─────────────────────────────────────────
            const Text(
              'Breeding Preparation Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('CIDR Inserted', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(_cidrInsertedDate == null
                        ? 'Not set'
                        : DateFormat.yMMMd().format(_cidrInsertedDate!)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_cidrInsertedDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _cidrInsertedDate = null),
                          ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _cidrInsertedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() => _cidrInsertedDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('CIDR Removed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(_cidrRemovedDate == null
                        ? 'Not set'
                        : DateFormat.yMMMd().format(_cidrRemovedDate!)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_cidrRemovedDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _cidrRemovedDate = null),
                          ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _cidrRemovedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() => _cidrRemovedDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedHormone,
              decoration: const InputDecoration(
                labelText: 'Prep Hormones Administered',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services_outlined),
              ),
              isExpanded: true,
              items: _hormoneOptions.map((h) => DropdownMenuItem(
                value: h,
                child: Text(h, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (val) => setState(() => _selectedHormone = val),
            ),
            if (_selectedHormone == 'Other') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _prepHormonesOtherController,
                decoration: const InputDecoration(
                  labelText: 'Specify Hormone Treatment',
                  hintText: 'Enter custom hormone protocol',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ─── Pregnancy Confirmation ───────────────────────────────────────
            const Text(
              'Pregnancy Confirmation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Confirmed Pregnant'),
              value: _confirmedPregnant,
              onChanged: (val) {
                setState(() {
                  _confirmedPregnant = val;
                  if (val) {
                    _selectedOutcome = null; // Clear open status
                  }
                });
              },
            ),
            
            if (_confirmedPregnant) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedConfirmationMethod,
                decoration: const InputDecoration(labelText: 'Confirmation Method'),
                items: _confirmationMethods.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m));
                }).toList(),
                onChanged: (val) => setState(() => _selectedConfirmationMethod = val),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Confirmation Date'),
                subtitle: Text(_confirmationDate == null 
                    ? 'Not set' 
                    : DateFormat.yMMMd().format(_confirmationDate!)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () => _selectConfirmationDate(context),
              ),
            ] else ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<BreedingOutcome>(
                initialValue: _selectedOutcome,
                decoration: const InputDecoration(labelText: 'Outcome (If Not Pregnant)'),
                items: const [
                  DropdownMenuItem(value: BreedingOutcome.open, child: Text('Open / Missed')),
                  DropdownMenuItem(value: BreedingOutcome.aborted, child: Text('Aborted')),
                  DropdownMenuItem(value: BreedingOutcome.unknown, child: Text('Unknown / Pending')),
                ],
                onChanged: (val) => setState(() => _selectedOutcome = val),
              ),
            ],

            const Divider(),
            const SizedBox(height: 8),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Breeding Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _save,
              child: const Text('Save Breeding Record'),
            ),
          ],
        ),
      ),
    );
  }
}
