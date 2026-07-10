import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/animal_model.dart';
import '../../../data/models/meat_record_model.dart';
import '../../../data/repositories/production_repository.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../../shared/widgets/app_drawer.dart';

class MeatDashboardScreen extends ConsumerStatefulWidget {
  final Animal? animal;

  const MeatDashboardScreen({super.key, this.animal});

  @override
  ConsumerState<MeatDashboardScreen> createState() => _MeatDashboardScreenState();
}

class _MeatDashboardScreenState extends ConsumerState<MeatDashboardScreen> {
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
              ? 'Meat Production Ledger'
              : '${_selectedAnimal!.name} Meat Record',
        ),
      ),
      drawer: widget.animal == null ? const AppDrawer(currentRoute: 'meat') : null,
      body: activeAnimalsAsync.when(
        data: (animals) {
          final listToUse = animals;

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
                            hint: const Text('Select an Animal'),
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
                      'Please select an animal above to view meat production records.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final meatRecordsAsync = ref.watch(meatHistoryProvider(_selectedAnimal!.id!));

                      return meatRecordsAsync.when(
                        data: (records) {
                          if (records.isEmpty) {
                            return const Center(
                              child: Text(
                                'No meat production records found for this animal.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            );
                          }

                          // Calculations
                          final validLiveWeights = records.where((r) => r.liveWeightLbs != null && r.liveWeightLbs! > 0).toList();
                          final validHangingWeights = records.where((r) => r.hangingWeightLbs != null && r.hangingWeightLbs! > 0).toList();
                          final validDressing = records.where((r) => r.dressingPercent != null && r.dressingPercent! > 0).toList();

                          final avgLive = validLiveWeights.isNotEmpty
                              ? validLiveWeights.fold<double>(0, (sum, r) => sum + r.liveWeightLbs!) / validLiveWeights.length
                              : null;
                          final avgHanging = validHangingWeights.isNotEmpty
                              ? validHangingWeights.fold<double>(0, (sum, r) => sum + r.hangingWeightLbs!) / validHangingWeights.length
                              : null;
                          final avgDressing = validDressing.isNotEmpty
                              ? validDressing.fold<double>(0, (sum, r) => sum + r.dressingPercent!) / validDressing.length
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
                                        title: 'Avg Live Wt',
                                        value: avgLive != null ? '${avgLive.toStringAsFixed(1)} lbs' : 'N/A',
                                        icon: Icons.scale_outlined,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        title: 'Avg Hanging Wt',
                                        value: avgHanging != null ? '${avgHanging.toStringAsFixed(1)} lbs' : 'N/A',
                                        icon: Icons.kitchen,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        title: 'Avg Dressing %',
                                        value: avgDressing != null ? '${avgDressing.toStringAsFixed(1)}%' : 'N/A',
                                        icon: Icons.percent,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ─── Meat Log List ───
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
                                              DateFormat('MMM dd, yyyy').format(record.recordDate),
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            if (record.yieldGrade != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Grade: ${record.yieldGrade}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
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
                                                  if (record.liveWeightLbs != null) ...[
                                                    const Icon(Icons.scale_outlined, size: 16, color: Colors.blue),
                                                    const SizedBox(width: 4),
                                                    Text('Live: ${record.liveWeightLbs} lbs'),
                                                    const SizedBox(width: 16),
                                                  ],
                                                  if (record.hangingWeightLbs != null) ...[
                                                    const Icon(Icons.kitchen, size: 16, color: Colors.red),
                                                    const SizedBox(width: 4),
                                                    Text('Hanging: ${record.hangingWeightLbs} lbs'),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  if (record.dressingPercent != null) ...[
                                                    const Icon(Icons.percent, size: 16, color: Colors.green),
                                                    const SizedBox(width: 4),
                                                    Text('Dressing: ${record.dressingPercent!.toStringAsFixed(1)}%'),
                                                    const SizedBox(width: 16),
                                                  ],
                                                  if (record.cutYieldLbs != null) ...[
                                                    const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.orange),
                                                    const SizedBox(width: 4),
                                                    Text('Net Yield: ${record.cutYieldLbs} lbs'),
                                                  ],
                                                ],
                                              ),
                                              if (record.slaughterDate != null) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text('Slaughter Date: ${DateFormat('yyyy-MM-dd').format(record.slaughterDate!)}'),
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
                                              onPressed: () => _showAddEditMeatRecordDialog(context, record),
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
              onPressed: () => _showAddEditMeatRecordDialog(context, null),
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

  void _showAddEditMeatRecordDialog(BuildContext context, MeatRecord? existing) {
    final formKey = GlobalKey<FormState>();
    final liveController = TextEditingController(text: existing?.liveWeightLbs?.toString() ?? '');
    final hangingController = TextEditingController(text: existing?.hangingWeightLbs?.toString() ?? '');
    final cutController = TextEditingController(text: existing?.cutYieldLbs?.toString() ?? '');
    final gradeController = TextEditingController(text: existing?.yieldGrade ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    DateTime selectedDate = existing?.recordDate ?? DateTime.now();
    DateTime? selectedSlaughterDate = existing?.slaughterDate;

    double? currentDressingPercent = existing?.dressingPercent;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateDressing() {
              final live = double.tryParse(liveController.text);
              final hanging = double.tryParse(hangingController.text);
              if (live != null && hanging != null && live > 0) {
                setState(() {
                  currentDressingPercent = (hanging / live) * 100.0;
                });
              } else {
                setState(() {
                  currentDressingPercent = null;
                });
              }
            }

            return AlertDialog(
              title: Text(existing == null ? 'Add Meat Record' : 'Edit Meat Record'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date Picker
                      ListTile(
                        title: const Text('Record Date'),
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
                      // Slaughter Date Picker
                      ListTile(
                        title: const Text('Slaughter Date'),
                        subtitle: Text(selectedSlaughterDate != null ? DateFormat('yyyy-MM-dd').format(selectedSlaughterDate!) : 'Not set'),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedSlaughterDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedSlaughterDate = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      // Live weight input (lbs)
                      TextFormField(
                        controller: liveController,
                        decoration: const InputDecoration(
                          labelText: 'Live Weight (lbs)',
                          hintText: 'e.g. 95.0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => updateDressing(),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      // Hanging weight input (lbs)
                      TextFormField(
                        controller: hangingController,
                        decoration: const InputDecoration(
                          labelText: 'Hanging Carcass Weight (lbs)',
                          hintText: 'e.g. 48.5',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => updateDressing(),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Automatically Calculated Dressing Percentage
                      if (currentDressingPercent != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Dressing Percentage:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${currentDressingPercent!.toStringAsFixed(2)}%',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Net cut yield input (lbs)
                      TextFormField(
                        controller: cutController,
                        decoration: const InputDecoration(
                          labelText: 'Deboned/Cut Yield (lbs)',
                          hintText: 'e.g. 32.0',
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
                      // Yield Grade input
                      TextFormField(
                        controller: gradeController,
                        decoration: const InputDecoration(
                          labelText: 'Yield Grade / Quality',
                          hintText: 'e.g. Choice, USDA 1, USDA 2',
                        ),
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
                      final live = liveController.text.isNotEmpty ? double.parse(liveController.text) : null;
                      final hanging = hangingController.text.isNotEmpty ? double.parse(hangingController.text) : null;
                      final cut = cutController.text.isNotEmpty ? double.parse(cutController.text) : null;

                      final record = MeatRecord(
                        id: existing?.id,
                        animalId: _selectedAnimal!.id!,
                        recordDate: selectedDate,
                        slaughterDate: selectedSlaughterDate,
                        liveWeightLbs: live,
                        hangingWeightLbs: hanging,
                        dressingPercent: currentDressingPercent,
                        cutYieldLbs: cut,
                        yieldGrade: gradeController.text.isNotEmpty ? gradeController.text : null,
                        notes: notesController.text,
                      );

                      final repo = ref.read(productionRepositoryProvider);
                      if (existing == null) {
                        await repo.insertMeatRecord(record);
                      } else {
                        await repo.updateMeatRecord(record);
                      }

                      ref.invalidate(meatHistoryProvider(_selectedAnimal!.id!));
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

  void _confirmDeleteRecord(BuildContext context, MeatRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this meat record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await ref.read(productionRepositoryProvider).deleteMeatRecord(record.id!);
              ref.invalidate(meatHistoryProvider(_selectedAnimal!.id!));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
