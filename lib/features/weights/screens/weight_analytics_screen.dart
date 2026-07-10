// lib/features/weights/screens/weight_analytics_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../data/models/animal_model.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../providers/weight_providers.dart';
import '../../../shared/providers/providers.dart';
import 'weight_history_screen.dart';

class WeightAnalyticsScreen extends ConsumerStatefulWidget {
  const WeightAnalyticsScreen({super.key});

  @override
  ConsumerState<WeightAnalyticsScreen> createState() => _WeightAnalyticsScreenState();
}

class _WeightAnalyticsScreenState extends ConsumerState<WeightAnalyticsScreen> with SingleTickerProviderStateMixin {
  String _selectedTab = 'Kids';
  bool _sortAscending = true;
  int _sortColumnIndex = 0;

  late TabController _tabController;
  final List<String> _tabs = ['Kids', 'Weanlings', 'Yearlings', 'Young Adults', 'Mature Adults'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _tabs[_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getAgeGroupRangeLabel(String group) {
    switch (group) {
      case 'Kids': return '0 - 90 Days';
      case 'Weanlings': return '91 - 180 Days';
      case 'Yearlings': return '181 - 365 Days';
      case 'Young Adults': return '1 - 2 Years';
      case 'Mature Adults': return '2+ Years';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(weightAnalyticsProvider);
    final settings = ref.watch(settingsStateProvider);
    final targetHigh = double.tryParse(settings['target_adg_high'] ?? '0.45') ?? 0.45;
    final targetMin = double.tryParse(settings['target_adg_min'] ?? '0.25') ?? 0.25;

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Weight & Growth Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configure ADG Targets',
            onPressed: () => _showConfigureTargetsDialog(context, targetHigh, targetMin),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'weight_analytics'),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading analytics: $err')),
        data: (allData) {
          // Filter data for selected group
          final groupData = allData.where((d) => d.ageGroup == _selectedTab).toList();

          // Calculate summary metrics
          final totalAnimals = groupData.length;
          
          double avgWeight = 0.0;
          double avgADG = 0.0;
          int highCount = 0;
          int targetCount = 0;
          int lowCount = 0;
          int maleCount = 0;
          int femaleCount = 0;

          double sumWeight = 0.0;
          int weightCount = 0;
          double sumADG = 0.0;
          int adgCount = 0;

          for (final item in groupData) {
            if (item.currentWeight != null) {
              sumWeight += item.currentWeight!;
              weightCount++;
            }
            if (item.lifetimeADG != null) {
              sumADG += item.lifetimeADG!;
              adgCount++;
            }

            if (item.performanceTier == 'High') {
              highCount++;
            } else if (item.performanceTier == 'Target') {
              targetCount++;
            } else {
              lowCount++;
            }

            if (item.animal.sex == Sex.buck) {
              maleCount++;
            } else if (item.animal.sex == Sex.doe) {
              femaleCount++;
            }
          }

          if (weightCount > 0) avgWeight = sumWeight / weightCount;
          if (adgCount > 0) avgADG = sumADG / adgCount;

          // ─── Chart Calculations ─────────────────────────────────────────────
          // 1. Pie Chart Performance Band Segments
          final double highPercent = totalAnimals > 0 ? (highCount / totalAnimals) * 100 : 0.0;
          final double targetPercent = totalAnimals > 0 ? (targetCount / totalAnimals) * 100 : 0.0;
          final double lowPercent = totalAnimals > 0 ? (lowCount / totalAnimals) * 100 : 0.0;

          // 2. Line Chart Growth Trend Calculations
          final Map<int, List<double>> weekWeights = {};
          // Calculate historical weights binned by week of age
          for (final item in groupData) {
            final dob = item.animal.dob;
            if (dob == null) continue;

            if (item.animal.birthWeightLbs != null) {
              weekWeights.putIfAbsent(0, () => []).add(item.animal.birthWeightLbs!);
            }
          }

          // Fetch all weight records from repo to rebuild curve accurately
          // We'll query weight records for this curve. But for in-memory, we can approximate
          // or collect from current animal's known weights if they are cached,
          // or construct from the latest weigh in and dob as two data points to show a trend.
          // To make it look incredibly realistic and functional, let's gather all weight records
          // for the filtered animals. We can load them from the db helper in this widget or pass them in.
          // Since the provider queries tableWeightRecords, we can extract historical records.
          // Let's get the weight records map from provider if we cache it, or fetch it.
          // Wait! The weightAnalyticsProvider queries all records from the db and groups them!
          // We can write a custom line spot builder from the animal's dob and weigh dates.
          
          return Column(
            children: [
              // ─── Age Group Tabs ────────────────────────────────────────────────
              Material(
                elevation: 1,
                color: Theme.of(context).colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
                ),
              ),
              
              // ─── Analytics Body ────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Subtitle with Label
                      Text(
                        'Performance Comparison for ${_getAgeGroupRangeLabel(_selectedTab)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ─── Stat Summary Cards ────────────────────────────────────────
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 600;
                          final cardWidth = isNarrow
                              ? (constraints.maxWidth - 12) / 2
                              : (constraints.maxWidth - 24) / 3;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: isNarrow ? constraints.maxWidth : cardWidth,
                                child: _buildSummaryCard(
                                  context,
                                  'Total Goats',
                                  '$totalAnimals',
                                  'Males: $maleCount • Females: $femaleCount',
                                  Icons.group,
                                  Colors.blue,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  context,
                                  'Avg Weight',
                                  '${avgWeight.toStringAsFixed(1)} lbs',
                                  'Group Average',
                                  Icons.scale,
                                  Colors.orange,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  context,
                                  'Avg ADG',
                                  avgADG.toStringAsFixed(3),
                                  'lbs/day gained',
                                  Icons.trending_up,
                                  Colors.green,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // ─── Charts Row ────────────────────────────────────────────────
                      if (totalAnimals > 0) ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 600;

                            final pieCard = Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ADG Performance Distribution',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      height: 180,
                                      child: PieChart(
                                        PieChartData(
                                          sectionsSpace: 4,
                                          centerSpaceRadius: 40,
                                          sections: [
                                            if (highCount > 0)
                                              PieChartSectionData(
                                                color: Colors.green,
                                                value: highPercent,
                                                title: '${highPercent.toStringAsFixed(0)}%',
                                                radius: 50,
                                                titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                                              ),
                                            if (targetCount > 0)
                                              PieChartSectionData(
                                                color: Colors.orange,
                                                value: targetPercent,
                                                title: '${targetPercent.toStringAsFixed(0)}%',
                                                radius: 50,
                                                titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                                              ),
                                            if (lowCount > 0)
                                              PieChartSectionData(
                                                color: Colors.red,
                                                value: lowPercent,
                                                title: '${lowPercent.toStringAsFixed(0)}%',
                                                radius: 50,
                                                titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Legend
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildLegendItem('High (>= ${targetHigh.toStringAsFixed(2)})', Colors.green),
                                        _buildLegendItem('Target (${targetMin.toStringAsFixed(2)} - ${targetHigh.toStringAsFixed(2)})', Colors.orange),
                                        _buildLegendItem('Low (< ${targetMin.toStringAsFixed(2)})', Colors.red),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );

                            final barCard = Card(
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Average ADG by Breed (lbs/day)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildBreedADGBarChart(groupData),
                                  ],
                                ),
                              ),
                            );

                            if (isMobile) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  pieCard,
                                  const SizedBox(height: 16),
                                  barCard,
                                ],
                              );
                            } else {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 4, child: pieCard),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 5, child: barCard),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        const Card(
                          margin: EdgeInsets.symmetric(vertical: 24),
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                'No animals matching this age group found in the active herd.',
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // ─── Goats Performance List ────────────────────────────────────
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Goats Performance Details (${groupData.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 12),
                              if (groupData.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Center(child: Text('No data to list.')),
                                )
                              else
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    sortAscending: _sortAscending,
                                    sortColumnIndex: _sortColumnIndex,
                                    headingTextStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                    ),
                                    columns: [
                                      DataColumn(
                                        label: const Text('Animal Name'),
                                        onSort: (columnIndex, ascending) => _sortList(columnIndex, ascending, groupData),
                                      ),
                                      DataColumn(
                                        label: const Text('Sex'),
                                        onSort: (columnIndex, ascending) => _sortList(columnIndex, ascending, groupData),
                                      ),
                                      DataColumn(
                                        label: const Text('Age (Days)'),
                                        numeric: true,
                                        onSort: (columnIndex, ascending) => _sortList(columnIndex, ascending, groupData),
                                      ),
                                      DataColumn(
                                        label: const Text('Current Wt'),
                                        numeric: true,
                                        onSort: (columnIndex, ascending) => _sortList(columnIndex, ascending, groupData),
                                      ),
                                      DataColumn(
                                        label: const Text('Lifetime ADG'),
                                        numeric: true,
                                        onSort: (columnIndex, ascending) => _sortList(columnIndex, ascending, groupData),
                                      ),
                                      DataColumn(
                                        label: const Text('Performance'),
                                        onSort: (columnIndex, ascending) => _sortList(columnIndex, ascending, groupData),
                                      ),
                                    ],
                                    rows: groupData.map((item) {
                                      return DataRow(
                                        onSelectChanged: (_) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => WeightDashboardScreen(animal: item.animal),
                                            ),
                                          );
                                        },
                                        cells: [
                                          DataCell(
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(item.animal.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Text(item.animal.earTag ?? item.animal.scrapieTag ?? 'No Tag', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          DataCell(Text(item.animal.sex.name.toUpperCase())),
                                          DataCell(Text('${item.ageInDays}')),
                                          DataCell(Text(item.currentWeight != null ? '${item.currentWeight!.toStringAsFixed(1)} lbs' : 'N/A')),
                                          DataCell(Text(item.lifetimeADG != null ? item.lifetimeADG!.toStringAsFixed(3) : 'N/A')),
                                          DataCell(
                                            Chip(
                                              label: Text(item.performanceTier, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                              backgroundColor: _getPerformanceColor(item.performanceTier),
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _getPerformanceColor(String tier) {
    if (tier == 'High') return Colors.green;
    if (tier == 'Target') return Colors.orange;
    return Colors.red;
  }

  Widget _buildBreedADGBarChart(List<AnimalWeightAnalytics> groupData) {
    // Group ADG averages by Breed
    final Map<String, List<double>> breedADGs = {};
    for (final item in groupData) {
      if (item.lifetimeADG != null) {
        breedADGs.putIfAbsent(item.animal.breed, () => []).add(item.lifetimeADG!);
      }
    }

    if (breedADGs.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text('Not enough ADG data to display breed comparisons.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
        ),
      );
    }

    final List<String> breedsList = breedADGs.keys.toList();
    final List<double> avgADGsList = breedsList.map((b) {
      final list = breedADGs[b]!;
      return list.reduce((a, b) => a + b) / list.length;
    }).toList();

    double maxAdg = avgADGsList.reduce(math.max);
    maxAdg = maxAdg > 0 ? maxAdg * 1.2 : 0.6; // add 20% breathing room

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAdg,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < breedsList.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(breedsList[idx], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 8)),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(breedsList.length, (idx) {
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: avgADGsList[idx],
                  color: Colors.green.shade400,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _sortList(int columnIndex, bool ascending, List<AnimalWeightAnalytics> list) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      list.sort((a, b) {
        dynamic valA;
        dynamic valB;

        switch (columnIndex) {
          case 0:
            valA = a.animal.name;
            valB = b.animal.name;
            break;
          case 1:
            valA = a.animal.sex.name;
            valB = b.animal.sex.name;
            break;
          case 2:
            valA = a.ageInDays;
            valB = b.ageInDays;
            break;
          case 3:
            valA = a.currentWeight ?? -1.0;
            valB = b.currentWeight ?? -1.0;
            break;
          case 4:
            valA = a.lifetimeADG ?? -1.0;
            valB = b.lifetimeADG ?? -1.0;
            break;
          case 5:
            valA = a.performanceTier;
            valB = b.performanceTier;
            break;
        }

        if (ascending) {
          return Comparable.compare(valA, valB);
        } else {
          return Comparable.compare(valB, valA);
        }
      });
    });
  }

  void _showConfigureTargetsDialog(BuildContext context, double currentHigh, double currentMin) {
    final formKey = GlobalKey<FormState>();
    final highController = TextEditingController(text: currentHigh.toStringAsFixed(2));
    final minController = TextEditingController(text: currentMin.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configure ADG Targets'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Average Daily Gain (ADG) thresholds in lbs/day are used to categorize animals into performance tiers.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: highController,
                  decoration: const InputDecoration(
                    labelText: 'High Performer Threshold (lbs/day)',
                    border: OutlineInputBorder(),
                    helperText: 'e.g. 0.45',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: minController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Target Threshold (lbs/day)',
                    border: OutlineInputBorder(),
                    helperText: 'e.g. 0.25',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed <= 0) return 'Enter a valid positive number';
                    final highVal = double.tryParse(highController.text) ?? 0.0;
                    if (parsed >= highVal) {
                      return 'Must be less than High threshold';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final newHigh = highController.text.trim();
                  final newMin = minController.text.trim();
                  
                  await ref.read(settingsStateProvider.notifier).updateSetting('target_adg_high', newHigh);
                  await ref.read(settingsStateProvider.notifier).updateSetting('target_adg_min', newMin);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ADG target thresholds updated successfully!')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
