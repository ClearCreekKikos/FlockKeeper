import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flockkeeper/data/models/animal_model.dart';
import 'package:flockkeeper/data/models/health_record_model.dart';
import 'package:flockkeeper/data/models/health_constants.dart';
import 'package:flockkeeper/shared/providers/providers.dart';
import 'health_dashboard_screen.dart';
import 'fec_calculator_screen.dart';
import 'add_edit_reminder_screen.dart';
import '../../../data/repositories/weight_repository.dart';

class AddEditHealthRecordScreen extends ConsumerStatefulWidget {
  final Animal animal;
  final HealthRecord? record;
  final HealthRecordType? initialType;
  final String? initialNotes;

  const AddEditHealthRecordScreen({
    super.key, 
    required this.animal,
    this.record,
    this.initialType,
    this.initialNotes,
  });

  @override
  ConsumerState<AddEditHealthRecordScreen> createState() => _AddEditHealthRecordScreenState();
}

class _AddEditHealthRecordScreenState extends ConsumerState<AddEditHealthRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  HealthRecordType _selectedType = HealthRecordType.famacha;
  List<String> _selectedProducts = [];
  int? _famachaScore;
  String? _actionTaken;
  String? _actionResult; 
  HealthRecordType? _treatmentDecision;
  double? _bcsScore;
  String? _selectedIllness;
  DateTime _recordDate = DateTime.now();
  final _notesController = TextEditingController();
  final _resultController = TextEditingController();
  final _dosageController = TextEditingController();
  final _withdrawalDaysController = TextEditingController();
  double? _animalWeight;
  int? _withdrawalDays;
  DateTime? _withdrawalDate;

  Future<void> _loadLatestWeight() async {
    try {
      final latest = await WeightRepository().getLatestWeightForAnimal(widget.animal.id!);
      if (latest != null && mounted) {
        setState(() {
          _animalWeight = latest.weightLbs;
        });
      }
    } catch (e) {
      debugPrint('Error loading latest weight: $e');
    }
  }

  String _calculateMedicationDose(String productName) {
    if (_animalWeight == null || _animalWeight! <= 0) return '';
    final desc = HealthConstants.recommendedDosages[productName] ?? '';
    if (desc.isEmpty) return '';

    // Regex parsing: "X ml / Y lb", "45 gm / 100 lb", "2g per 50 lbs"
    final regExp = RegExp(
        r'(\d+(?:\.\d+)?)\s*(ml|cc|g|gm|mg|units)?\s*(?:\/|per|per\s*)\s*(\d+(?:\.\d+)?)\s*(?:lb|lbs|l|g|kg|bw)');
    final match = regExp.firstMatch(desc.toLowerCase());
    if (match != null) {
      final ratioVolume = double.tryParse(match.group(1) ?? '') ?? 0.0;
      String doseUnit = 'mL (cc)';
      final rawUnit = match.group(2);
      if (rawUnit != null) {
        if (rawUnit == 'g') {
          doseUnit = 'g';
        } else if (rawUnit == 'gm') {
          doseUnit = 'gm';
        } else if (rawUnit == 'mg') {
          doseUnit = 'mg';
        } else if (rawUnit == 'units') {
          doseUnit = 'units';
        }
      }
      final ratioWeight = double.tryParse(match.group(3) ?? '') ?? 0.0;
      if (ratioWeight == 0) return '';

      final dose = (_animalWeight! * ratioVolume) / ratioWeight;
      return ' ➔ Recommended for ${widget.animal.name} (${_animalWeight!.toStringAsFixed(1)} lbs): ${dose.toStringAsFixed(2)} $doseUnit';
    } else {
      // Check if it is a fixed dosage (e.g., '2ml SQ', '5g (Oral)')
      final matchFixed = RegExp(r'^(\d+(?:\.\d+)?)\s*(ml|cc|g|gm|units|mg)').firstMatch(desc.toLowerCase());
      if (matchFixed != null && !desc.toLowerCase().contains(' or ')) {
        final fixedVal = double.tryParse(matchFixed.group(1) ?? '') ?? 0.0;
        final rawUnit = matchFixed.group(2);
        String doseUnit = 'mL (cc)';
        if (rawUnit != null) {
          if (rawUnit == 'g') {
            doseUnit = 'g';
          } else if (rawUnit == 'gm') {
            doseUnit = 'gm';
          } else if (rawUnit == 'mg') {
            doseUnit = 'mg';
          } else if (rawUnit == 'units') {
            doseUnit = 'units';
          }
        }
        return ' ➔ Fixed Dose: ${fixedVal.toStringAsFixed(1)} $doseUnit';
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadLatestWeight();
    if (widget.record != null) {
      final r = widget.record!;
      
      if (r.dosage != null) {
        _dosageController.text = r.dosage!;
      }
      
      // Parse notes and actions
      String rawNotes = r.notes ?? '';
      if (rawNotes.startsWith('Action: ')) {
        final actionEnd = rawNotes.indexOf('. ');
        if (actionEnd != -1) {
          _actionTaken = rawNotes.substring(8, actionEnd);
          rawNotes = rawNotes.substring(actionEnd + 2);
        }
      }
      if (rawNotes.startsWith('Result: ')) {
        final resultEnd = rawNotes.indexOf('. ');
        if (resultEnd != -1) {
          _actionResult = rawNotes.substring(8, resultEnd);
          _resultController.text = _actionResult!;
          rawNotes = rawNotes.substring(resultEnd + 2);
        }
      }
      _notesController.text = rawNotes;

      // Determine Event Type and Treatment Decision
      if (r.famachaScore != null) {
        _selectedType = HealthRecordType.famacha;
        _famachaScore = r.famachaScore;
        if (r.recordType != HealthRecordType.famacha) {
          _treatmentDecision = r.recordType;
        }
      } else if (r.bcsScore != null) {
        _selectedType = HealthRecordType.bcs;
        _bcsScore = r.bcsScore;
        if (r.recordType != HealthRecordType.bcs) {
          _treatmentDecision = r.recordType;
        }
      } else if (r.diagnosis != null) {
        _selectedType = HealthRecordType.illness;
        _selectedIllness = r.diagnosis;
        if (r.recordType != HealthRecordType.illness) {
          _treatmentDecision = r.recordType;
        }
      } else {
        _selectedType = r.recordType;
        // Check if there is treatment administered under general event
        if (r.treatment != null) {
          _treatmentDecision = r.recordType;
        }
      }

      // Fill in fallback helper actions if not parsed from notes
      if (_actionTaken == null && r.treatment != null) {
        if (_selectedType == HealthRecordType.famacha) {
          _actionTaken = 'Deworm immediately';
        } else {
          _actionTaken = 'Administer Treatment';
        }
      }
      if (_actionResult != null && _actionTaken == null) {
        if (_selectedType == HealthRecordType.famacha) {
          _actionTaken = 'Fecal Egg Count (FEC) Test';
        } else {
          _actionTaken = 'Perform Diagnostic Test';
        }
      }

      // Populate selected products
      if (r.treatment != null && r.treatment!.isNotEmpty) {
        _selectedProducts = r.treatment!.split(', ');
      }
      
      _recordDate = r.recordDate;
      _withdrawalDays = r.withdrawalDays;
      _withdrawalDate = r.withdrawalDate;
      if (_withdrawalDays != null) {
        _withdrawalDaysController.text = _withdrawalDays.toString();
      }
    } else {
      if (widget.initialType != null) {
        _selectedType = widget.initialType!;
      }
      if (widget.initialNotes != null) {
        _notesController.text = widget.initialNotes!;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _resultController.dispose();
    _dosageController.dispose();
    _withdrawalDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(widget.record == null ? 'Add Health Record' : 'Edit Health Record')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<HealthRecordType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'Event Type'),
              items: HealthRecordType.values.map((t) => 
                DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedType = val!;
                  _selectedProducts = [];
                  _actionResult = null;
                  _resultController.clear();
                  if (_selectedType == HealthRecordType.grooming) {
                    _actionTaken = 'Administer Treatment';
                    _treatmentDecision = HealthRecordType.grooming;
                  } else {
                    _actionTaken = null;
                    _treatmentDecision = null;
                  }
                  _selectedIllness = null;
                });
              },
            ),
            const SizedBox(height: 16),
            
            if (_selectedType == HealthRecordType.famacha)
              Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: [1, 2, 3, 4, 5].contains(_famachaScore) ? _famachaScore : null,
                    decoration: const InputDecoration(labelText: 'FAMACHA Score'),
                    items: [1, 2, 3, 4, 5]
                        .map((i) => DropdownMenuItem(value: i, child: Text('$i')))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _famachaScore = val;
                      });
                    },
                  ),
                ],
              ),

            if (_selectedType == HealthRecordType.bcs)
              DropdownButtonFormField<double>(
                initialValue: [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0].contains(_bcsScore) ? _bcsScore : null,
                decoration: const InputDecoration(labelText: 'BCS Score'),
                items: [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                onChanged: (val) => setState(() => _bcsScore = val),
              ),

            if (_selectedType == HealthRecordType.illness)
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: HealthConstants.illnessTypes.contains(_selectedIllness) ? _selectedIllness : null,
                    decoration: const InputDecoration(labelText: 'Common Illnesses'),
                    items: HealthConstants.illnessTypes
                        .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedIllness = val),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            if (_selectedType != HealthRecordType.grooming) ...[
              // ─── Phase 2: Action Taken (Always Required) ────────────────────
              DropdownButtonFormField<String>(
                initialValue: (_selectedType == HealthRecordType.famacha 
                    ? HealthConstants.famachaActions 
                    : HealthConstants.generalActions)
                  .contains(_actionTaken) ? _actionTaken : null,
                decoration: const InputDecoration(labelText: 'Action Taken *'),
                items: (_selectedType == HealthRecordType.famacha 
                    ? HealthConstants.famachaActions 
                    : HealthConstants.generalActions)
                  .map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (val) {
                  setState(() {
                    _actionTaken = val;
                    // Reset downstream
                    if (val != 'Perform Diagnostic Test') {
                      _resultController.clear();
                      _actionResult = null;
                    }
                    
                    // Conditional branching logic for treatments
                    if (val == 'Deworm immediately') {
                      _treatmentDecision = HealthRecordType.deworming;
                    } else if (val == 'Administer Treatment') {
                      // If the primary event is a category (Vaccine/Antibiotic), use it
                      _treatmentDecision = HealthConstants.categoryProducts.containsKey(_selectedType) 
                          ? _selectedType : null;
                    } else {
                      _treatmentDecision = null;
                      _selectedProducts = [];
                    }
                  });

                  if (val == 'Schedule Treatment') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditReminderScreen(initialAnimalId: widget.animal.id),
                      ),
                    );
                  }
                },
                validator: (v) => _selectedType == HealthRecordType.grooming ? null : (v == null ? 'Selection required' : null),
              ),
            ],

            // ─── Phase 2.5: Treatment Category (For Illness or General Treatment) ──
            if (_actionTaken == 'Administer Treatment' && 
                !HealthConstants.categoryProducts.containsKey(_selectedType))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: DropdownButtonFormField<dynamic>(
                  initialValue: [
                    HealthRecordType.antibiotic,
                    HealthRecordType.deworming,
                    HealthRecordType.vaccination,
                    HealthRecordType.supplement,
                    HealthRecordType.other,
                  ].contains(_treatmentDecision) ? _treatmentDecision : null,
                  decoration: const InputDecoration(labelText: 'Select Treatment Category'),
                  items: [
                    ...[
                      HealthRecordType.antibiotic,
                      HealthRecordType.deworming,
                      HealthRecordType.vaccination,
                      HealthRecordType.supplement,
                      HealthRecordType.other,
                    ].map((t) => DropdownMenuItem<dynamic>(
                      value: t, 
                      child: Text(t.name.toUpperCase())
                    )),
                    const DropdownMenuItem<dynamic>(
                      value: 'schedule',
                      child: Text('SCHEDULE TREATMENT...'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == 'schedule') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditReminderScreen(initialAnimalId: widget.animal.id),
                        ),
                      );
                      setState(() {
                        _treatmentDecision = null;
                        _selectedProducts = [];
                      });
                    } else {
                      setState(() {
                        _treatmentDecision = val as HealthRecordType?;
                        _selectedProducts = [];
                      });
                    }
                  },
                ),
              ),

            // ─── Phase 3: Action Details (e.g., FEC Results) ────────────────
            if (_actionTaken == 'Perform Diagnostic Test' || _actionTaken == 'Fecal Egg Count (FEC) Test')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _resultController,
                      decoration: InputDecoration(
                        labelText: 'Test Results (e.g. EPG count, Vet findings)',
                        suffixIcon: _actionTaken == 'Fecal Egg Count (FEC) Test'
                            ? IconButton(
                                icon: const Icon(Icons.calculate_outlined),
                                tooltip: 'Open FEC & FERC Calculator',
                                onPressed: () async {
                                  final result = await Navigator.push<String>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const FecCalculatorScreen(isSelectMode: true),
                                    ),
                                  );
                                  if (result != null) {
                                    setState(() {
                                      _resultController.text = result;
                                      _actionResult = result;
                                    });
                                  }
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _actionResult = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<dynamic>(
                      initialValue: [
                        HealthRecordType.other, // Represents "None" or "Monitor"
                        HealthRecordType.deworming,
                        HealthRecordType.antibiotic,
                        HealthRecordType.vaccination,
                        HealthRecordType.supplement,
                      ].contains(_treatmentDecision) ? _treatmentDecision : null,
                      decoration: const InputDecoration(labelText: 'Treatment Decision'),
                      items: [
                        ...[
                          HealthRecordType.other, // Represents "None" or "Monitor"
                          HealthRecordType.deworming,
                          HealthRecordType.antibiotic,
                          HealthRecordType.vaccination,
                          HealthRecordType.supplement,
                        ].map((t) => DropdownMenuItem<dynamic>(
                          value: t, 
                          child: Text(t == HealthRecordType.other ? 'None / Monitor' : 'Treat: ${t.name.toUpperCase()}')
                        )),
                        const DropdownMenuItem<dynamic>(
                          value: 'schedule',
                          child: Text('Schedule Treatment...'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == 'schedule') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditReminderScreen(initialAnimalId: widget.animal.id),
                            ),
                          );
                          setState(() {
                            _treatmentDecision = null;
                            _selectedProducts = [];
                          });
                        } else {
                          setState(() {
                            // If 'None / Monitor' is chosen (mapped to other), 
                            // we treat it as no specific treatment category.
                            _treatmentDecision = val == HealthRecordType.other ? null : (val as HealthRecordType?);
                            _selectedProducts = [];
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

            // ─── Phase 4: Product Selection ──────────────────────────────────
            if (_treatmentDecision != null && HealthConstants.categoryProducts.containsKey(_treatmentDecision))
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select ${_treatmentDecision!.name.toUpperCase()} Products:', 
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: HealthConstants.categoryProducts[_treatmentDecision]!
                        .map((p) => FilterChip(
                          label: Text(p),
                          selected: _selectedProducts.contains(p),
                          onSelected: (selected) {
                            setState(() {
                              selected ? _selectedProducts.add(p) : _selectedProducts.remove(p);
                              final dosageList = _selectedProducts
                                  .map((prod) => '$prod: ${HealthConstants.recommendedDosages[prod] ?? "N/A"}')
                                  .join(', ');
                              _dosageController.text = dosageList;

                              if (_selectedProducts.isNotEmpty) {
                                int maxWithdrawalDays = 0;
                                for (final prod in _selectedProducts) {
                                  final days = HealthConstants.recommendedWithdrawalDays[prod] ?? 0;
                                  if (days > maxWithdrawalDays) {
                                    maxWithdrawalDays = days;
                                  }
                                }
                                _withdrawalDays = maxWithdrawalDays;
                                _withdrawalDaysController.text = maxWithdrawalDays.toString();
                                _withdrawalDate = _recordDate.add(Duration(days: maxWithdrawalDays));
                              } else {
                                _withdrawalDays = null;
                                _withdrawalDaysController.clear();
                                _withdrawalDate = null;
                              }
                            });
                          },
                        )).toList(),
                    ),
                  ],
                ),
              ),

            if (_selectedProducts.isNotEmpty && _treatmentDecision != null) ...[
              Card(
                color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended Dosages:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.blue.shade900,
                        ),
                      ),
                      ..._selectedProducts.map((p) => Text(
                            '• $p: ${HealthConstants.recommendedDosages[p] ?? "N/A"}${_calculateMedicationDose(p)}',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dosageController,
                decoration: InputDecoration(
                  labelText: 'Administered Dosage',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calculate_outlined),
                    tooltip: 'Open Dosage Calculator',
                    onPressed: () async {
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FecCalculatorScreen(
                            isSelectMode: true,
                            initialTab: 2,
                            initialAnimal: widget.animal,
                            initialMedication: _selectedProducts.isNotEmpty ? _selectedProducts.first : null,
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          _dosageController.text = result;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],

            ListTile(
              title: const Text('Date of Event'),
              subtitle: Text(DateFormat.yMMMd().format(_recordDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _recordDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _recordDate = picked;
                    if (_withdrawalDays != null) {
                      _withdrawalDate = picked.add(Duration(days: _withdrawalDays!));
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _withdrawalDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Withdrawal Period (Days)',
                      hintText: '0',
                    ),
                    onChanged: (val) {
                      final days = int.tryParse(val);
                      setState(() {
                        _withdrawalDays = days;
                        if (days != null) {
                          _withdrawalDate = _recordDate.add(Duration(days: days));
                        } else {
                          _withdrawalDate = null;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Withdrawal Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(
                      _withdrawalDate != null
                          ? DateFormat.yMMMd().format(_withdrawalDate!)
                          : 'No Withdrawal',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _withdrawalDate ?? _recordDate,
                        firstDate: _recordDate,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _withdrawalDate = picked;
                          _withdrawalDays = picked.difference(_recordDate).inDays;
                          _withdrawalDaysController.text = _withdrawalDays.toString();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              child: Text(widget.record == null ? 'Save Health Record' : 'Save Changes'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    String notes = _notesController.text.trim();
    if (_actionTaken != null) notes = 'Action: $_actionTaken. $notes';
    if (_actionResult != null && _actionResult!.isNotEmpty) notes = 'Result: $_actionResult. $notes';

    final String? treatment = _selectedProducts.isEmpty ? null : _selectedProducts.join(', ');
    final String? dosage = _dosageController.text.trim().isEmpty ? null : _dosageController.text.trim();

    final HealthRecord record;
    if (widget.record != null) {
      record = widget.record!.copyWith(
        recordType: _treatmentDecision ?? _selectedType,
        recordDate: _recordDate,
        diagnosis: _selectedIllness,
        treatment: treatment,
        dosage: dosage,
        famachaScore: _famachaScore,
        bcsScore: _bcsScore,
        notes: notes,
        withdrawalDays: _withdrawalDays,
        withdrawalDate: _withdrawalDate,
        updatedAt: DateTime.now(),
      );
    } else {
      record = HealthRecord(
        animalId: widget.animal.id!,
        recordType: _treatmentDecision ?? _selectedType,
        recordDate: _recordDate,
        diagnosis: _selectedIllness,
        treatment: treatment,
        dosage: dosage,
        famachaScore: _famachaScore,
        bcsScore: _bcsScore,
        notes: notes,
        withdrawalDays: _withdrawalDays,
        withdrawalDate: _withdrawalDate,
      );
    }

    try {
      if (widget.record == null) {
        await ref.read(healthRepositoryProvider).insertHealthRecord(record);
      } else {
        await ref.read(healthRepositoryProvider).updateHealthRecord(record);
      }
      ref.invalidate(healthHistoryProvider(widget.animal.id!));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving record: $e')),
        );
      }
    }
  }
}