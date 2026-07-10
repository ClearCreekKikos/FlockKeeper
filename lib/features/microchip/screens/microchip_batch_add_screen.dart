import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../data/models/animal_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';

class MicrochipBatchAddScreen extends ConsumerStatefulWidget {
  const MicrochipBatchAddScreen({super.key});

  @override
  ConsumerState<MicrochipBatchAddScreen> createState() => _MicrochipBatchAddScreenState();
}

class _MicrochipBatchAddScreenState extends ConsumerState<MicrochipBatchAddScreen> {
  final _eidController = TextEditingController();
  final _earTagController = TextEditingController();
  final _sourceController = TextEditingController();
  final _priceController = TextEditingController();

  final _eidFocusNode = FocusNode();
  final _earTagFocusNode = FocusNode();

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSaving = false;

  // Presets
  String _selectedBreed = 'Kiko';
  Sex _selectedSex = Sex.doe;
  final DateTime _selectedDob = DateTime.now();

  // Allowed lists
  final List<String> _breeds = [
    'Kiko', 'Spanish', 'Boer', 'Myotonic', 'Crossbred', 'Other'
  ];

  // Session Log
  final List<Animal> _sessionAddedAnimals = [];

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
    _earTagController.dispose();
    _sourceController.dispose();
    _priceController.dispose();
    _eidFocusNode.dispose();
    _earTagFocusNode.dispose();
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
      _earTagController.clear();
    });

    await _speech.listen(
      onResult: (val) {
        setState(() {
          // Normalize voice digits (e.g. replace spaces or format spoken numbers)
          _earTagController.text = val.recognizedWords.replaceAll(' ', '');
        });
        if (val.finalResult) {
          _stopListening();
          // Short delay to let user see voice input before autosave
          Future.delayed(const Duration(milliseconds: 600), () {
            _saveAnimal();
          });
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  // Handle microchip scanned
  void _onEidSubmitted(String value) {
    if (value.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    // Auto-trigger voice for ear tag
    if (_speechAvailable) {
      _startListening();
    } else {
      _earTagFocusNode.requestFocus();
    }
  }

  Future<void> _saveAnimal() async {
    final eid = _eidController.text.trim();
    final earTag = _earTagController.text.trim();

    if (eid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan or enter a microchip EID.')),
      );
      _eidFocusNode.requestFocus();
      return;
    }

    setState(() => _isSaving = true);

    final repo = ref.read(animalRepositoryProvider);

    // Check if EID duplicate
    final exists = await repo.rfidTagExists(eid);
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: EID $eid already exists in database!')),
        );
        setState(() => _isSaving = false);
        _eidController.clear();
        _earTagController.clear();
        _eidFocusNode.requestFocus();
      }
      return;
    }

    final double? price = double.tryParse(_priceController.text);
    final String? source = _sourceController.text.isNotEmpty ? _sourceController.text.trim() : null;

    final newAnimal = Animal(
      name: earTag.isNotEmpty ? 'Goat $earTag' : 'Goat EID-${eid.substring(eid.length - 4)}',
      earTag: earTag.isNotEmpty ? earTag : null,
      rfidTag: eid,
      breed: _selectedBreed,
      sex: _selectedSex,
      dob: _selectedDob,
      status: AnimalStatus.active,
      purchasePrice: price,
      soldTo: source, // Save NKR seller details to soldTo
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final savedId = await repo.insertAnimal(newAnimal);
      final savedAnimal = newAnimal.copyWith(id: savedId);

      // Trigger standard provider invalidations
      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);
      ref.invalidate(searchedAnimalsProvider);

      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      setState(() {
        _sessionAddedAnimals.insert(0, savedAnimal);
        _eidController.clear();
        _earTagController.clear();
        _isSaving = false;
      });

      // Refocus microchip input for next loop
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
        title: const Text('Quick-Scan Batch Add'),
      ),
      body: Column(
        children: [
          // ─── Presets Card ─────────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.all(12),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: const Text(
                'Default Animal Presets',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedBreed,
                              decoration: const InputDecoration(labelText: 'Breed'),
                              items: _breeds.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                              onChanged: (val) => setState(() => _selectedBreed = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<Sex>(
                              initialValue: _selectedSex,
                              decoration: const InputDecoration(labelText: 'Sex'),
                              items: Sex.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))).toList(),
                              onChanged: (val) => setState(() => _selectedSex = val!),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sourceController,
                              decoration: const InputDecoration(labelText: 'Acquired From (Seller)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Purchase Price'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Active Scanning Session Loop ────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'SESSION CHUTE LOOP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Microchip Scan Input
                  TextField(
                    controller: _eidController,
                    focusNode: _eidFocusNode,
                    decoration: InputDecoration(
                      labelText: 'Scan Microchip (EID)',
                      prefixIcon: const Icon(Icons.sensors),
                      suffixIcon: _eidController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _eidController.clear(),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                    onSubmitted: _onEidSubmitted,
                  ),
                  const SizedBox(height: 20),

                  // Ear Tag Input with Voice Control trigger
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _earTagController,
                          focusNode: _earTagFocusNode,
                          decoration: const InputDecoration(
                            labelText: 'Ear Tag ID',
                            prefixIcon: Icon(Icons.tag),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.text,
                          onSubmitted: (_) => _saveAnimal(),
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
                          tooltip: 'Speak Ear Tag ID',
                        ),
                      ),
                    ],
                  ),
                  if (_isListening) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Listening for Ear Tag number...',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),

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
                    label: const Text('Save & Next Goat', style: TextStyle(fontSize: 16)),
                    onPressed: _isSaving ? null : _saveAnimal,
                  ),

                  const SizedBox(height: 32),

                  // ─── Session History Log ────────────────────────────────────
                  if (_sessionAddedAnimals.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ADDED THIS SESSION (${_sessionAddedAnimals.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _sessionAddedAnimals.clear()),
                          child: const Text('Clear Log'),
                        ),
                      ],
                    ),
                    const Divider(),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sessionAddedAnimals.length,
                      itemBuilder: (context, index) {
                        final animal = _sessionAddedAnimals[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.pets, color: Colors.white, size: 16),
                          ),
                          title: Text(animal.name),
                          subtitle: Text('EID: ${animal.rfidTag} • Breed: ${animal.breed} • ${animal.sex.name.toUpperCase()}'),
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
