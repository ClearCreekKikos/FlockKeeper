import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../data/models/animal_model.dart';
import '../../../data/models/weight_record_model.dart';
import '../providers/weight_providers.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../../shared/providers/providers.dart';

class WeightDashboardScreen extends ConsumerWidget {
  final Animal animal;

  const WeightDashboardScreen({super.key, required this.animal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentAnimal = ref.watch(animalByIdProvider(animal.id!)).value ?? animal;
    final weightsAsync = ref.watch(weightHistoryProvider(animal.id!));
    final adgAsync = ref.watch(lifetimeADGProvider(animal.id!));
    final recentAdgAsync = ref.watch(recentADGProvider(animal.id!));
    final milestonesAsync = ref.watch(milestoneWeightsProvider(animal.id!));

    return Scaffold(
      appBar: AppBar(
        title: Text('${currentAnimal.name} Weight Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Weight',
            onPressed: () => _showAddWeightDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Growth Trend Chart ───────────────────────────────────────────
          weightsAsync.when(
            data: (weights) => weights.length >= 2
                ? Container(
                    height: 200,
                    padding: const EdgeInsets.fromLTRB(16, 24, 32, 8),
                    child: _buildWeightChart(weights),
                  )
                : const SizedBox(
                    height: 100,
                    child: Center(child: Text('Add more weights to see growth trend')),
                  ),
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // ─── Milestone Section ─────────────────────────────────────────────
          milestonesAsync.when(
            data: (m) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Growth Milestones', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMilestoneCard(context, ref, currentAnimal, 'Birth', m['birth'], 0),
                        _buildMilestoneCard(context, ref, currentAnimal, '30 Day', m['30'], 30),
                        _buildMilestoneCard(context, ref, currentAnimal, '90 Day', m['90'], 90),
                        _buildMilestoneCard(context, ref, currentAnimal, '120 Day', m['120'], 120),
                        _buildMilestoneCard(context, ref, currentAnimal, '150 Day', m['150'], 150),
                        _buildMilestoneCard(context, ref, currentAnimal, '365 Day', m['365'], 365),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // ─── ADG Stats ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: adgAsync.when(
                    data: (adg) => _buildStatCard('Lifetime ADG', adg, isDark ? Colors.green.shade900 : Colors.green.shade50, isDark),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: recentAdgAsync.when(
                    data: (adg) => _buildStatCard('Recent (Last 3)', adg, isDark ? Colors.blue.shade900 : Colors.blue.shade50, isDark),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Weight History', style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: weightsAsync.when(
              data: (weights) => ListView.builder(
                itemCount: weights.length,
                itemBuilder: (context, index) {
                  final record = weights[index];
                  return ListTile(
                    title: Text('${record.weightLbs} lbs'),
                    subtitle: Text(DateFormat.yMMMd().format(record.weighDate)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref
                            .read(weightRepositoryProvider)
                            .deleteWeightRecord(record.id!);
                        ref.invalidate(weightHistoryProvider(animal.id!));
                        ref.invalidate(latestWeightProvider(animal.id!));
                        ref.invalidate(lifetimeADGProvider(animal.id!));
                        ref.invalidate(recentADGProvider(animal.id!));
                        ref.invalidate(milestoneWeightsProvider(animal.id!));
                      },
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 2,
            ),
            onPressed: () => _showAddWeightDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Weight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildWeightChart(List<WeightRecord> weights) {
    // Sort weights chronologically for the chart
    final chartData = List<WeightRecord>.from(weights)..sort((a, b) => a.weighDate.compareTo(b.weighDate));
    
    final spots = chartData.map((record) {
      return FlSpot(
        record.weighDate.millisecondsSinceEpoch.toDouble(),
        record.weightLbs,
      );
    }).toList();

    if (spots.isEmpty) return const SizedBox.shrink();

    final minX = spots.first.x;
    final maxX = spots.last.x;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (maxX - minX) / 3 > 0 ? (maxX - minX) / 3 : 1,
              getTitlesWidget: (value, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Text(
                  DateFormat('MMM d').format(date),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              reservedSize: 28,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (touchedSpot) => Colors.green.shade800,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final date = DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt());
                return LineTooltipItem(
                  '${DateFormat.yMMMd().format(date)}\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: '${barSpot.y} lbs',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneCard(BuildContext context, WidgetRef ref, Animal currentAnimal, String label, double? value, int days) {
    final targetDate = currentAnimal.dob?.add(Duration(days: days));
    
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: () => _showMilestoneInput(context, ref, currentAnimal, label, days),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                if (value != null)
                  Text(value.toStringAsFixed(1), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                else if (targetDate == null && days > 0)
                  const Icon(Icons.help_outline, size: 16, color: Colors.orange)
                else
                  const Icon(Icons.add, size: 20, color: Colors.green),
                const Text('lbs', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMilestoneInput(BuildContext context, WidgetRef ref, Animal currentAnimal, String label, int days) {
    if (currentAnimal.dob == null && days > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set Date of Birth first to track age milestones.'))
      );
      return;
    }

    final targetDate = days == 0 ? (currentAnimal.dob ?? DateTime.now()) : currentAnimal.dob!.add(Duration(days: days));
    
    if (days == 0) {
      _showBirthWeightDialog(context, ref, currentAnimal);
    } else {
      _showAddWeightDialog(context, ref, initialDate: targetDate, isFixedDate: true);
    }
  }

  Widget _buildStatCard(String label, double? value, Color color, bool isDark) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            Text(
              value != null ? '${value.toStringAsFixed(2)} lbs/d' : 'N/A',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBirthWeightDialog(BuildContext context, WidgetRef ref, Animal currentAnimal) {
    final controller = TextEditingController(text: currentAnimal.birthWeightLbs?.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Birth Weight'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Weight (lbs)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final weight = double.tryParse(controller.text);
              if (weight != null) {
                final updatedAnimal = currentAnimal.copyWith(birthWeightLbs: weight);
                await ref.read(animalRepositoryProvider).updateAnimal(updatedAnimal);
                
                ref.invalidate(animalByIdProvider(animal.id!));
                ref.invalidate(animalsProvider);
                ref.invalidate(searchedAnimalsProvider);
                ref.invalidate(lifetimeADGProvider(animal.id!));
                
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAddWeightDialog(BuildContext context, WidgetRef ref, {DateTime? initialDate, bool isFixedDate = false}) {
    final weightController = TextEditingController();
    DateTime selectedDate = initialDate ?? DateTime.now();
    
    if (!isFixedDate && selectedDate.isAfter(DateTime.now())) {
      selectedDate = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          title: Text(isFixedDate ? 'Record Milestone' : 'Add Weight'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight (lbs)'),
                autofocus: true,
              ),
              if (!isFixedDate)
                ListTile(
                  title: Text(DateFormat.yMMMd().format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.event, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Date: ${DateFormat.yMMMd().format(selectedDate)}',
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final weight = double.tryParse(weightController.text);
                if (weight != null) {
                  await ref.read(weightRepositoryProvider).insertWeightRecord(
                        WeightRecord(
                          animalId: animal.id!,
                          weightLbs: weight,
                          weighDate: selectedDate,
                        ),
                      );
                  ref.invalidate(weightHistoryProvider(animal.id!));
                  ref.invalidate(latestWeightProvider(animal.id!));
                  ref.invalidate(lifetimeADGProvider(animal.id!));
                  ref.invalidate(recentADGProvider(animal.id!));
                  ref.invalidate(milestoneWeightsProvider(animal.id!));
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}