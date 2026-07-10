import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/animal_model.dart';
import '../../../data/models/milking_record_model.dart';
import '../../../data/repositories/production_repository.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../../shared/widgets/app_drawer.dart';

class MilkingDashboardScreen extends ConsumerStatefulWidget {
  final Animal? animal;

  const MilkingDashboardScreen({super.key, this.animal});

  @override
  ConsumerState<MilkingDashboardScreen> createState() => _MilkingDashboardScreenState();
}

class _MilkingDashboardScreenState extends ConsumerState<MilkingDashboardScreen> {
  Animal? _selectedAnimal;

  @override
  void initState() {
    super.initState();
    _selectedAnimal = widget.animal;
  }

  @override
  Widget build(BuildContext context) {
    final activeAnimalsAsync = ref.watch(activeAnimalsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          _selectedAnimal == null
              ? 'Milking Production Ledger'
              : '${_selectedAnimal!.name} Milking Log',
        ),
      ),
      drawer: widget.animal == null ? const AppDrawer(currentRoute: 'milking') : null,
      body: activeAnimalsAsync.when(
        data: (animals) {
          // If we have no preselected animal, try to pick the first one if list is not empty,
          // or let the user select.
          final dairyAnimals = animals.where((a) => a.sexDisplay.toLowerCase() == 'doe' || a.sexDisplay.toLowerCase() == 'female').toList();
          final listToUse = dairyAnimals.isNotEmpty ? dairyAnimals : animals;

          return Column(
            children: [
              // ─── Animal Selector ───
              Card(
                margin: const EdgeInsets.all(16),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.pets, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Animal>(
                            hint: const Text('Select a Doe/Animal'),
                            value: _selectedAnimal != null && listToUse.any((a) => a.id == _selectedAnimal!.id)
                                ? listToUse.firstWhere((a) => a.id == _selectedAnimal!.id)
                                : null,
                            isExpanded: true,
                            items: listToUse.map((a) {
                              return DropdownMenuItem<Animal>(
                                value: a,
                                child: Text('${a.name} (${a.earTag?.isNotEmpty == true ? a.earTag : 'No Tag'})'),
                              );
                            }).toList(),
                            onChanged: (animal) {
                              setState(() {
                                _selectedAnimal = animal;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_selectedAnimal == null)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Please select an animal above to view milking records.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final milkingRecordsAsync = ref.watch(milkingHistoryProvider(_selectedAnimal!.id!));

                      return milkingRecordsAsync.when(
                        data: (records) {
                          if (records.isEmpty) {
                            return const Center(
                              child: Text(
                                'No milking records found for this animal.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            );
                          }

                          // Calculations
                          final totalYield = records.fold<double>(0, (sum, r) => sum + r.yieldLbs);
                          final avgYield = totalYield / records.length;
                          final recordsWithScc = records.where((r) => r.scc != null).toList();
                          final avgScc = recordsWithScc.isNotEmpty
                              ? recordsWithScc.fold<int>(0, (sum, r) => sum + r.scc!) ~/ recordsWithScc.length
                              : null;

                          return Column(
                            children: [
                              // ─── Stats Summary Cards ───
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        title: 'Avg Yield',
                                        value: '${avgYield.toStringAsFixed(2)} lbs',
                                        icon: Icons.opacity,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        title: 'Avg SCC',
                                        value: avgScc != null ? NumberFormat('#,###').format(avgScc) : 'N/A',
                                        icon: Icons.biotech,
                                        color: Colors.purple,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        title: 'Total entries',
                                        value: '${records.length}',
                                        icon: Icons.summarize,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ─── Milking Log List ───
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: records.length,
                                  itemBuilder: (context, index) {
                                    final record = records[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        title: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              DateFormat('MMM dd, yyyy').format(record.milkingDate),
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                record.session ?? 'Overall',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.opacity, size: 16, color: Colors.blue),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Yield: ${record.yieldLbs} lbs',
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                  if (record.fatPercent != null || record.proteinPercent != null) ...[
                                                    const SizedBox(width: 16),
                                                    const Icon(Icons.percent, size: 16, color: Colors.orange),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'F: ${record.fatPercent ?? 0}% | P: ${record.proteinPercent ?? 0}%',
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if (record.scc != null) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.biotech, size: 16, color: Colors.purple),
                                                    const SizedBox(width: 4),
                                                    Text('SCC: ${NumberFormat('#,###').format(record.scc)} cells/mL'),
                                                  ],
                                                ),
                                              ],
                                              if (record.notes?.isNotEmpty == true) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Notes: ${record.notes}',
                                                  style: const TextStyle(fontStyle: FontStyle.italic),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined),
                                              onPressed: () => _showAddEditMilkingRecordDialog(context, record),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                                              onPressed: () => _confirmDeleteRecord(context, record),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(child: Text('Error: $err')),
                      );
                    },
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: _selectedAnimal == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddEditMilkingRecordDialog(context, null),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditMilkingRecordDialog(BuildContext context, MilkingRecord? existing) {
    final formKey = GlobalKey<FormState>();
    final yieldController = TextEditingController(text: existing?.yieldLbs.toString() ?? '');
    final fatController = TextEditingController(text: existing?.fatPercent?.toString() ?? '');
    final proteinController = TextEditingController(text: existing?.proteinPercent?.toString() ?? '');
    final sccController = TextEditingController(text: existing?.scc?.toString() ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    String selectedSession = existing?.session ?? 'AM';
    DateTime selectedDate = existing?.milkingDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Milking Record' : 'Edit Milking Record'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date Picker
                      ListTile(
                        title: const Text('Date'),
                        subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                      // Session Dropdown
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Session'),
                        initialValue: selectedSession,
                        items: ['AM', 'PM', 'Overall'].map((session) {
                          return DropdownMenuItem<String>(
                            value: session,
                            child: Text(session),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedSession = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      // Yield input (lbs)
                      TextFormField(
                        controller: yieldController,
                        decoration: const InputDecoration(
                          labelText: 'Milk Yield (lbs)',
                          hintText: 'e.g. 3.2',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Yield is required';
                          if (double.tryParse(val) == null) return 'Enter a valid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // Fat % input
                      TextFormField(
                        controller: fatController,
                        decoration: const InputDecoration(
                          labelText: 'Milk Fat (%)',
                          hintText: 'e.g. 3.8',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // Protein % input
                      TextFormField(
                        controller: proteinController,
                        decoration: const InputDecoration(
                          labelText: 'Milk Protein (%)',
                          hintText: 'e.g. 3.1',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // SCC input
                      TextFormField(
                        controller: sccController,
                        decoration: const InputDecoration(
                          labelText: 'Somatic Cell Count (cells/mL)',
                          hintText: 'e.g. 200000',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val != null && val.isNotEmpty && int.tryParse(val) == null) {
                            return 'Enter a valid integer';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // Notes
                      TextFormField(
                        controller: notesController,
                        decoration: const InputDecoration(labelText: 'Notes'),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final yieldVal = double.parse(yieldController.text);
                      final fat = fatController.text.isNotEmpty ? double.parse(fatController.text) : null;
                      final protein = proteinController.text.isNotEmpty ? double.parse(proteinController.text) : null;
                      final scc = sccController.text.isNotEmpty ? int.parse(sccController.text) : null;

                      final record = MilkingRecord(
                        id: existing?.id,
                        animalId: _selectedAnimal!.id!,
                        milkingDate: selectedDate,
                        session: selectedSession,
                        yieldLbs: yieldVal,
                        fatPercent: fat,
                        proteinPercent: protein,
                        scc: scc,
                        notes: notesController.text,
                      );

                      final repo = ref.read(productionRepositoryProvider);
                      if (existing == null) {
                        await repo.insertMilkingRecord(record);
                      } else {
                        await repo.updateMilkingRecord(record);
                      }

                      // Invalidate provider to reload records
                      ref.invalidate(milkingHistoryProvider(_selectedAnimal!.id!));
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteRecord(BuildContext context, MilkingRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this milking record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await ref.read(productionRepositoryProvider).deleteMilkingRecord(record.id!);
              ref.invalidate(milkingHistoryProvider(_selectedAnimal!.id!));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
