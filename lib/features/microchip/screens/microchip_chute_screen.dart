import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../data/models/animal_model.dart';
import '../../../data/models/weight_record_model.dart';
import '../../../data/models/health_record_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';
import 'package:intl/intl.dart';

class MicrochipChuteScreen extends ConsumerStatefulWidget {
  const MicrochipChuteScreen({super.key});

  @override
  ConsumerState<MicrochipChuteScreen> createState() => _MicrochipChuteScreenState();
}

class _MicrochipChuteScreenState extends ConsumerState<MicrochipChuteScreen> {
  final _eidController = TextEditingController();
  final _weightController = TextEditingController();
  final _productController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  final _eidFocusNode = FocusNode();
  final _weightFocusNode = FocusNode();

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSaving = false;

  // Active Goat State
  Animal? _scannedAnimal;
  WeightRecord? _latestWeight;
  bool _isSearchingAnimal = false;

  // Presets
  bool _recordWeight = true;
  bool _recordTreatment = false;
  HealthRecordType _selectedTreatmentType = HealthRecordType.deworming;

  // Session Log
  final List<String> _sessionLogs = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _eidFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _eidController.dispose();
    _weightController.dispose();
    _productController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    _eidFocusNode.dispose();
    _weightFocusNode.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onError: (val) => debugPrint('🎤 Speech Error: ${val.errorMsg}'),
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (e) {
      debugPrint('🎤 Speech initialization failed: $e');
    }
    if (mounted) setState(() {});
  }

  void _startListening() async {
    if (!_speechAvailable || _isListening) return;
    setState(() {
      _isListening = true;
      _weightController.clear();
    });

    await _speech.listen(
      onResult: (val) {
        // Clean up spoken numbers (extract numeric digits only)
        final words = val.recognizedWords.replaceAll(RegExp(r'[^0-9\.]'), '');
        setState(() {
          _weightController.text = words;
        });
        if (val.finalResult) {
          _stopListening();
          Future.delayed(const Duration(milliseconds: 600), () {
            _saveChuteRecord();
          });
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 5),
        onDevice: true,
      ),
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  // Handle microchip scanned
  Future<void> _onEidSubmitted(String value) async {
    final scanned = value.trim();
    if (scanned.isEmpty || _isSearchingAnimal) return;

    setState(() {
      _isSearchingAnimal = true;
      _scannedAnimal = null;
      _latestWeight = null;
    });

    final repo = ref.read(animalRepositoryProvider);
    final weightRepo = ref.read(weightRepositoryProvider);

    final animal = await repo.getAnimalByRfidTag(scanned);

    if (!mounted) return;

    if (animal == null) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Goat with EID "$scanned" not registered.')),
      );
      setState(() {
        _isSearchingAnimal = false;
        _eidController.clear();
        _eidFocusNode.requestFocus();
      });
      return;
    }

    // Found animal! Fetch latest weight
    final latestWeight = await weightRepo.getLatestWeightForAnimal(animal.id!);

    if (!mounted) return;

    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    setState(() {
      _scannedAnimal = animal;
      _latestWeight = latestWeight;
      _isSearchingAnimal = false;
    });

    // Auto-trigger weight input
    if (_recordWeight) {
      if (_speechAvailable) {
        _startListening();
      } else {
        _weightFocusNode.requestFocus();
      }
    } else if (_recordTreatment) {
      _saveChuteRecord(); // If weight is off but treatment is on, auto save immediately
    }
  }

  Future<void> _saveChuteRecord() async {
    final animal = _scannedAnimal;
    if (animal == null) return;

    setState(() => _isSaving = true);

    final now = DateTime.now();
    String logMsg = '${animal.name}: ';

    try {
      // 1. Save Weight Record if checked
      if (_recordWeight) {
        final double? weight = double.tryParse(_weightController.text.trim());
        if (weight == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid weight input. Please re-enter.')),
          );
          setState(() => _isSaving = false);
          _weightFocusNode.requestFocus();
          return;
        }

        final weightRecord = WeightRecord(
          animalId: animal.id!,
          weighDate: now,
          weightLbs: weight,
          notes: _notesController.text.isNotEmpty ? _notesController.text.trim() : null,
        );

        await ref.read(weightRepositoryProvider).insertWeightRecord(weightRecord);
        logMsg += 'Weight: $weight lbs';
      }

      // 2. Save Health/Treatment Record if checked
      if (_recordTreatment) {
        final product = _productController.text.trim();
        final dosage = _dosageController.text.trim();

        if (product.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a product name for the treatment.')),
            );
          }
          setState(() => _isSaving = false);
          return;
        }

        final healthRecord = HealthRecord(
          animalId: animal.id!,
          recordType: _selectedTreatmentType,
          recordDate: now,
          treatment: product,
          dosage: dosage.isNotEmpty ? dosage : null,
          notes: _notesController.text.isNotEmpty ? _notesController.text.trim() : null,
          resolved: true,
        );

        await ref.read(healthRepositoryProvider).insertHealthRecord(healthRecord);
        logMsg += '${_recordWeight ? ", " : ""}${_selectedTreatmentType.name.toUpperCase()}: $product';
      }

      // Play success audio
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);

      setState(() {
        _sessionLogs.insert(0, '$logMsg at ${TimeOfDay.fromDateTime(now).format(context)}');
        _scannedAnimal = null;
        _latestWeight = null;
        _eidController.clear();
        _weightController.clear();
        _isSaving = false;
      });

      _eidFocusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chute Weight & Meds'),
      ),
      body: Column(
        children: [
          // ─── Settings / Configuration card ────────────────────────────────
          Card(
            margin: const EdgeInsets.all(12),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: const Text(
                'Chute Session Configuration',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _recordWeight,
                            onChanged: (val) => setState(() => _recordWeight = val ?? false),
                          ),
                          const Text('Record Weight'),
                          const Spacer(),
                          Checkbox(
                            value: _recordTreatment,
                            onChanged: (val) => setState(() => _recordTreatment = val ?? false),
                          ),
                          const Text('Record Treatment/Product'),
                        ],
                      ),
                      if (_recordTreatment) ...[
                        const Divider(),
                        DropdownButtonFormField<HealthRecordType>(
                          initialValue: _selectedTreatmentType,
                          decoration: const InputDecoration(labelText: 'Treatment Type'),
                          items: HealthRecordType.values
                              .map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase())))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedTreatmentType = val!),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _productController,
                                decoration: const InputDecoration(labelText: 'Product/Medication'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _dosageController,
                                decoration: const InputDecoration(labelText: 'Dosage'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Scanner Workspace Loop ───────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // EID Scan input field
                  TextField(
                    controller: _eidController,
                    focusNode: _eidFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Scan Goat Tag (EID)',
                      prefixIcon: const Icon(Icons.sensors),
                      suffixIcon: _isSearchingAnimal
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                    onSubmitted: _onEidSubmitted,
                  ),
                  const SizedBox(height: 24),

                  // Searched Active Goat Info Card
                  if (_scannedAnimal != null) ...[
                    Card(
                      color: Colors.blueGrey[900],
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _scannedAnimal!.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _scannedAnimal!.sex.name.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Breed: ${_scannedAnimal!.breed} • EID: ${_scannedAnimal!.rfidTag}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            if (_latestWeight != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Last Weight: ${_latestWeight!.weightLbs} lbs (recorded on ${DateFormat('yyyy-MM-dd').format(_latestWeight!.weighDate)})',
                                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ] else ...[
                              const SizedBox(height: 6),
                              const Text('Last Weight: N/A', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Weight Entry (Voice / Manual Input)
                  if (_scannedAnimal != null && _recordWeight) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            focusNode: _weightFocusNode,
                            decoration: const InputDecoration(
                              labelText: 'New Weight (lbs)',
                              prefixIcon: Icon(Icons.scale),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onSubmitted: (_) => _saveChuteRecord(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: _isListening ? Colors.red : Colors.blueGrey,
                          child: IconButton(
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                            ),
                            onPressed: _isListening ? _stopListening : _startListening,
                            tooltip: 'Speak Weight',
                          ),
                        ),
                      ],
                    ),
                    if (_isListening) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Listening for weight digits...',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  if (_scannedAnimal != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Save & Next Chute Animal', style: TextStyle(fontSize: 16)),
                      onPressed: _isSaving ? null : _saveChuteRecord,
                    ),

                  const SizedBox(height: 32),

                  // ─── Session History Log ────────────────────────────────────
                  if (_sessionLogs.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CHUTE SESSION HISTORY (${_sessionLogs.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _sessionLogs.clear()),
                          child: const Text('Clear Log'),
                        ),
                      ],
                    ),
                    const Divider(),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sessionLogs.length,
                      itemBuilder: (context, index) {
                        final log = _sessionLogs[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Icon(Icons.done, color: Colors.white, size: 16),
                          ),
                          title: Text(log),
                          dense: true,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
