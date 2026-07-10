import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/animal_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../finances/providers/financial_providers.dart';

class MicrochipLoadingScreen extends ConsumerStatefulWidget {
  const MicrochipLoadingScreen({super.key});

  @override
  ConsumerState<MicrochipLoadingScreen> createState() => _MicrochipLoadingScreenState();
}

class _MicrochipLoadingScreenState extends ConsumerState<MicrochipLoadingScreen> {
  final _eidController = TextEditingController();
  final _buyerController = TextEditingController();
  final _defaultPriceController = TextEditingController();

  final _eidFocusNode = FocusNode();

  bool _isSearching = false;
  bool _isSaving = false;

  // Loading List
  final List<_LoadedGoatRow> _loadedGoats = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _eidFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _eidController.dispose();
    _buyerController.dispose();
    _defaultPriceController.dispose();
    _eidFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onEidSubmitted(String value) async {
    final scanned = value.trim();
    if (scanned.isEmpty || _isSearching) return;

    // Check if already in loading list
    final alreadyLoaded = _loadedGoats.any((g) => g.animal.rfidTag == scanned);
    if (alreadyLoaded) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This goat is already on the loading list.')),
      );
      setState(() {
        _eidController.clear();
        _eidFocusNode.requestFocus();
      });
      return;
    }

    setState(() => _isSearching = true);

    final repo = ref.read(animalRepositoryProvider);
    final animal = await repo.getAnimalByRfidTag(scanned);

    if (!mounted) return;

    if (animal == null) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('EID "$scanned" not registered in database.')),
      );
    } else if (animal.status != AnimalStatus.active) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${animal.name} status is ${animal.status.name.toUpperCase()}, not ACTIVE.')),
      );
    } else {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);

      final priceController = TextEditingController(text: _defaultPriceController.text);
      setState(() {
        _loadedGoats.insert(0, _LoadedGoatRow(
          animal: animal,
          priceController: priceController,
        ));
      });
    }

    setState(() {
      _isSearching = false;
      _eidController.clear();
      _eidFocusNode.requestFocus();
    });
  }

  Future<void> _saveBulkSale() async {
    if (_loadedGoats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan at least one goat to load.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final repo = ref.read(animalRepositoryProvider);
    final buyer = _buyerController.text.trim().isNotEmpty ? _buyerController.text.trim() : null;
    final now = DateTime.now();

    try {
      for (var row in _loadedGoats) {
        final double? price = double.tryParse(row.priceController.text.trim());
        final updatedAnimal = row.animal.copyWith(
          status: AnimalStatus.sold,
          soldDate: now,
          soldPrice: price,
          soldTo: buyer,
        );
        await repo.updateAnimal(updatedAnimal);
      }

      // Invalidate core providers
      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);
      ref.invalidate(searchedAnimalsProvider);
      ref.invalidate(financialRecordsProvider);
      for (var row in _loadedGoats) {
        if (row.animal.id != null) {
          ref.invalidate(financialRecordsForAnimalProvider(row.animal.id!));
        }
      }

      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully sold ${_loadedGoats.length} goats!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  void _removeRow(int index) {
    setState(() {
      _loadedGoats[index].priceController.dispose();
      _loadedGoats.removeAt(index);
    });
    _eidFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trailer Loading (Bulk Sale)'),
      ),
      body: Column(
        children: [
          // ─── Default Sale Presets Card ─────────────────────────────────────
          Card(
            margin: const EdgeInsets.all(12),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: const Text(
                'Sale Presets & Buyer Info',
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
                            child: TextField(
                              controller: _buyerController,
                              decoration: const InputDecoration(labelText: 'Buyer / Location (Sold To)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _defaultPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Default Sale Price'),
                              onChanged: (val) {
                                // Sync default price to rows that don't have overrides yet
                                for (var row in _loadedGoats) {
                                  row.priceController.text = val;
                                }
                              },
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

          // ─── Scanner Input ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _eidController,
              focusNode: _eidFocusNode,
              decoration: InputDecoration(
                labelText: 'Scan Microchip (Loading Trailer)',
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

          // ─── Loaded Checklist ──────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _loadedGoats.isEmpty
                  ? const Center(
                      child: Text(
                        'No goats loaded. Scan microchips to start.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      itemCount: _loadedGoats.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = _loadedGoats[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.amber,
                            child: Icon(Icons.local_shipping, color: Colors.white, size: 16),
                          ),
                          title: Text(
                            row.animal.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('EID: ${row.animal.rfidTag} • Breed: ${row.animal.breed}'),
                          trailing: SizedBox(
                            width: 140,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: row.priceController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      prefixText: '\$',
                                      labelText: 'Price',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeRow(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // ─── Footer Action Button ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.amber[800]!,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(
                'Complete Sale of ${_loadedGoats.length} Goats',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _isSaving || _loadedGoats.isEmpty ? null : _saveBulkSale,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadedGoatRow {
  final Animal animal;
  final TextEditingController priceController;

  _LoadedGoatRow({
    required this.animal,
    required this.priceController,
  });
}
