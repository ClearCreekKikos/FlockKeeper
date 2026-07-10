import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/animal_model.dart';
import '../../../data/models/pasture_model.dart';
import '../../../shared/providers/providers.dart';

class MicrochipAuditScreen extends ConsumerStatefulWidget {
  const MicrochipAuditScreen({super.key});

  @override
  ConsumerState<MicrochipAuditScreen> createState() => _MicrochipAuditScreenState();
}

class _MicrochipAuditScreenState extends ConsumerState<MicrochipAuditScreen> {
  final _eidController = TextEditingController();
  final _eidFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isCompleting = false;

  List<Pasture> _pastures = [];
  Pasture? _selectedPasture;

  // Audit Lists
  List<Animal> _expectedAnimals = []; // Animals expected in this pasture
  final List<Animal> _scannedExpected = []; // Expected and scanned
  final List<Animal> _scannedWrongPasture = []; // Scanned but expected elsewhere
  final Map<int, Pasture?> _wrongPastureCurrentMap = {}; // Maps wrong pasture animal ID to their current pasture

  @override
  void initState() {
    super.initState();
    _loadPastures();
  }

  @override
  void dispose() {
    _eidController.dispose();
    _eidFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPastures() async {
    setState(() => _isLoading = true);
    final repo = ref.read(pastureRepositoryProvider);
    final list = await repo.getAllPastures();
    setState(() {
      _pastures = list;
      if (list.isNotEmpty) {
        _selectedPasture = list.first;
      }
      _isLoading = false;
    });

    if (_selectedPasture != null) {
      _loadExpectedAnimals();
    }
  }

  Future<void> _loadExpectedAnimals() async {
    if (_selectedPasture == null) return;
    setState(() => _isLoading = true);

    final repo = ref.read(pastureRepositoryProvider);
    final expected = await repo.getAnimalsInPasture(_selectedPasture!.id!);

    setState(() {
      _expectedAnimals = expected;
      _scannedExpected.clear();
      _scannedWrongPasture.clear();
      _wrongPastureCurrentMap.clear();
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _eidFocusNode.requestFocus();
    });
  }

  Future<void> _onEidSubmitted(String value) async {
    final scanned = value.trim();
    if (scanned.isEmpty || _isSearching || _selectedPasture == null) return;

    // Check if already scanned
    final alreadyScanned = _scannedExpected.any((g) => g.rfidTag == scanned) ||
        _scannedWrongPasture.any((g) => g.rfidTag == scanned);

    if (alreadyScanned) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goat is already scanned in this audit session.')),
      );
      setState(() {
        _eidController.clear();
        _eidFocusNode.requestFocus();
      });
      return;
    }

    setState(() => _isSearching = true);

    final repo = ref.read(animalRepositoryProvider);
    final pastureRepo = ref.read(pastureRepositoryProvider);
    final animal = await repo.getAnimalByRfidTag(scanned);

    if (!mounted) return;

    if (animal == null) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('EID "$scanned" not found in database.')),
      );
    } else {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);

      // Check if animal belongs to this pasture
      final belongsHere = _expectedAnimals.any((g) => g.id == animal.id);

      if (belongsHere) {
        setState(() {
          _scannedExpected.add(animal);
        });
      } else {
        // Fetch where they are currently supposed to be
        final currentPasture = await pastureRepo.getPastureForAnimal(animal.id!);
        if (mounted) {
          setState(() {
            _scannedWrongPasture.add(animal);
            _wrongPastureCurrentMap[animal.id!] = currentPasture;
          });
        }
      }
    }

    setState(() {
      _isSearching = false;
      _eidController.clear();
      _eidFocusNode.requestFocus();
    });
  }

  Future<void> _completeAudit() async {
    if (_selectedPasture == null) return;

    setState(() => _isCompleting = true);

    final pastureRepo = ref.read(pastureRepositoryProvider);
    final now = DateTime.now();

    try {
      // Move any "wrong pasture" animals that were scanned into this pasture
      for (var animal in _scannedWrongPasture) {
        await pastureRepo.moveAnimalIntoPasture(
          animalId: animal.id!,
          pastureId: _selectedPasture!.id!,
          moveInDate: now,
          notes: 'Auto-transferred during microchip audit.',
        );
      }

      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      if (mounted) {
        final totalScanned = _scannedExpected.length + _scannedWrongPasture.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Audit Complete! Scanned: $totalScanned, '
              'Accounted: ${_scannedExpected.length}, '
              'Transferred: ${_scannedWrongPasture.length}.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audit Error: $e')),
        );
        setState(() => _isCompleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Expected but missing list
    final List<Animal> missingAnimals = _expectedAnimals
        .where((exp) => !_scannedExpected.any((scan) => scan.id == exp.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasture Audit Check'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ─── Pasture Selection Card ──────────────────────────────────
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Pasture to Audit',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 8),
                        _pastures.isEmpty
                            ? const Text('No pastures registered in database.')
                            : DropdownButtonFormField<Pasture>(
                                initialValue: _selectedPasture,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                items: _pastures
                                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedPasture = val;
                                  });
                                  _loadExpectedAnimals();
                                },
                              ),
                      ],
                    ),
                  ),
                ),

                if (_selectedPasture != null) ...[
                  // ─── Scanner Input ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _eidController,
                      focusNode: _eidFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Scan Animal Microchip',
                        prefixIcon: const Icon(Icons.sensors),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: _onEidSubmitted,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Comparison Lists ──────────────────────────────────────
                  Expanded(
                    child: DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: Theme.of(context).primaryColor,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Theme.of(context).primaryColor,
                            tabs: [
                              Tab(text: 'Accounted (${_scannedExpected.length})'),
                              Tab(text: 'Missing (${missingAnimals.length})'),
                              Tab(text: 'Wrong Pasture (${_scannedWrongPasture.length})'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // 1. Scanned expected (Accounted)
                                _buildGoatListView(
                                  _scannedExpected,
                                  emptyText: 'No expected goats scanned yet.',
                                  iconColor: Colors.green,
                                ),
                                // 2. Expected but missing (Missing)
                                _buildGoatListView(
                                  missingAnimals,
                                  emptyText: 'All expected goats have been scanned!',
                                  iconColor: Colors.grey,
                                ),
                                // 3. Wrong pasture
                                _buildWrongPastureView(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ─── Confirm / Save button ───────────────────────────────────
                if (_selectedPasture != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isCompleting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.fact_check),
                      label: const Text(
                        'Complete Audit Session',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isCompleting ? null : _completeAudit,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildGoatListView(List<Animal> list, {required String emptyText, required Color iconColor}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(emptyText, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final animal = list[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: 0.1),
            child: Icon(Icons.pets, color: iconColor, size: 16),
          ),
          title: Text(animal.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('EID: ${animal.rfidTag} • Breed: ${animal.breed}'),
          dense: true,
        );
      },
    );
  }

  Widget _buildWrongPastureView() {
    if (_scannedWrongPasture.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No animals from other pastures scanned here.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: _scannedWrongPasture.length,
      itemBuilder: (context, index) {
        final animal = _scannedWrongPasture[index];
        final currentPasture = _wrongPastureCurrentMap[animal.id!];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          ),
          title: Text(animal.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            'Expected: ${currentPasture?.name ?? "No Pasture"} • EID: ${animal.rfidTag}',
          ),
          trailing: const Text(
            'Will Transfer',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          dense: true,
        );
      },
    );
  }
}
