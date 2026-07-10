import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/animal_model.dart';
import '../../../data/models/health_constants.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../../shared/providers/animal_providers.dart';

class FecCalculatorScreen extends ConsumerStatefulWidget {
  final bool isSelectMode;
  final int? initialTab;
  final Animal? initialAnimal;
  final String? initialMedication;

  const FecCalculatorScreen({
    super.key,
    this.isSelectMode = false,
    this.initialTab,
    this.initialAnimal,
    this.initialMedication,
  });

  @override
  ConsumerState<FecCalculatorScreen> createState() => _FecCalculatorScreenState();
}

class _FecCalculatorScreenState extends ConsumerState<FecCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ─── McMaster FEC Variables ──────────────────────────────────────────────
  double _fecesWeight = 2.0; // grams
  double _flotationVolume = 28.0; // mL
  int _chambersCounted = 2; // standard McMaster slide has 2 grids
  int _eggsCounted = 0;
  bool _useCustomMcMaster = false;

  final TextEditingController _customFecesController =
      TextEditingController(text: '2.0');
  final TextEditingController _customVolumeController =
      TextEditingController(text: '28.0');
  final TextEditingController _eggsCountedController =
      TextEditingController(text: '0');

  // ─── FERC Variables ──────────────────────────────────────────────────────
  int _preTreatmentEpg = 0;
  int _postTreatmentEpg = 0;

  final TextEditingController _preEpgController =
      TextEditingController(text: '');
  final TextEditingController _postEpgController =
      TextEditingController(text: '');

  // ─── Dosage Variables ───────────────────────────────────────────────────
  Animal? _selectedAnimal;
  bool _isKg = false;
  String _selectedMedication = 'Valbazen (Albendazole)';
  String _dosageInstruction = '';
  double? _calculatedDose;
  String _doseUnit = 'mL (cc)';
  String _weightStatusText = 'No animal selected';

  final TextEditingController _animalWeightController =
      TextEditingController(text: '');
  final TextEditingController _customDoseVolumeController =
      TextEditingController(text: '1.0');
  final TextEditingController _customPerWeightController =
      TextEditingController(text: '25.0');

  @override
  void initState() {
    super.initState();
    // 3 tabs: McMaster FEC, FERC Reduction, and Medication Dosage
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab ?? 0,
    );
    if (widget.initialAnimal != null) {
      _selectedAnimal = widget.initialAnimal;
      if (_selectedAnimal!.id != null) {
        _loadLastWeight(_selectedAnimal!.id!);
      }
    }
    if (widget.initialMedication != null) {
      final matchedKey = HealthConstants.recommendedDosages.keys.firstWhere(
        (key) => key.toLowerCase().contains(widget.initialMedication!.toLowerCase()) ||
                 widget.initialMedication!.toLowerCase().contains(key.toLowerCase()),
        orElse: () => '',
      );
      if (matchedKey.isNotEmpty) {
        _selectedMedication = matchedKey;
      }
    }
    _calculateDosage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customFecesController.dispose();
    _customVolumeController.dispose();
    _eggsCountedController.dispose();
    _preEpgController.dispose();
    _postEpgController.dispose();
    _animalWeightController.dispose();
    _customDoseVolumeController.dispose();
    _customPerWeightController.dispose();
    super.dispose();
  }

  // Calculate EPG based on parameters
  double get _calculatedFactor {
    final gridVolume = _chambersCounted * 0.15;
    if (gridVolume == 0 || _fecesWeight == 0) return 0.0;
    final totalSuspension = _fecesWeight + _flotationVolume;
    return totalSuspension / (gridVolume * _fecesWeight);
  }

  int get _calculatedEpg {
    final factor = _calculatedFactor;
    return (_eggsCounted * factor).round();
  }

  String get _fecSeverity {
    final epg = _calculatedEpg;
    if (epg == 0) return 'None';
    if (epg < 500) return 'Low Infestation';
    if (epg < 1000) return 'Moderate Infestation';
    if (epg < 2000) return 'High Infestation';
    return 'Severe Infestation';
  }

  Color get _fecSeverityColor {
    final epg = _calculatedEpg;
    if (epg == 0) return Colors.grey;
    if (epg < 500) return Colors.green;
    if (epg < 1000) return Colors.amber;
    if (epg < 2000) return Colors.orange;
    return Colors.red;
  }

  // Calculate Fecal Egg Reduction percentage
  double? get _fercReduction {
    if (_preTreatmentEpg <= 0) return null;
    return ((_preTreatmentEpg - _postTreatmentEpg) / _preTreatmentEpg) * 100;
  }

  String get _fercEfficacy {
    final reduction = _fercReduction;
    if (reduction == null) return 'Enter pre-treatment EPG';
    if (reduction >= 95) return 'Highly Effective (Normal)';
    if (reduction >= 90) return 'Equivocal (Suspect Resistance)';
    return 'Ineffective (Confirmed Resistance)';
  }

  Color get _fercEfficacyColor {
    final reduction = _fercReduction;
    if (reduction == null) return Colors.grey;
    if (reduction >= 95) return Colors.green;
    if (reduction >= 90) return Colors.orange;
    return Colors.red;
  }

  // Retrieve last recorded weight for the selected animal
  Future<void> _loadLastWeight(int animalId) async {
    final latest = await WeightRepository().getLatestWeightForAnimal(animalId);
    setState(() {
      if (latest != null) {
        _animalWeightController.text = latest.weightLbs.toStringAsFixed(1);
        _weightStatusText =
            'Last weight: ${latest.weightLbs.toStringAsFixed(1)} lbs (weighed ${DateFormat.yMd().format(latest.weighDate)})';
      } else {
        _animalWeightController.text = '';
        _weightStatusText = 'No weight history found. Enter weight manually.';
      }
      _calculateDosage();
    });
  }

  // Calculate dosage in mL/cc or appropriate unit
  void _calculateDosage() {
    final weightVal = double.tryParse(_animalWeightController.text);
    if (weightVal == null || weightVal <= 0) {
      setState(() {
        _calculatedDose = null;
        _doseUnit = 'mL (cc)';
        _dosageInstruction = 'Please enter a valid weight.';
      });
      return;
    }

    double weightLbs = weightVal;
    if (_isKg) {
      weightLbs = weightVal * 2.20462;
    }

    double ratioVolume = 0.0;
    double ratioWeight = 0.0;
    String localDoseUnit = 'mL (cc)';

    if (_selectedMedication == 'Custom') {
      ratioVolume = double.tryParse(_customDoseVolumeController.text) ?? 1.0;
      ratioWeight = double.tryParse(_customPerWeightController.text) ?? 25.0;
      localDoseUnit = 'mL (cc)';
    } else {
      final desc = HealthConstants.recommendedDosages[_selectedMedication] ?? '';
      // Regex parsing: "X ml / Y lb", "45 gm / 100 lb", "2g per 50 lbs"
      final regExp = RegExp(
          r'(\d+(?:\.\d+)?)\s*(ml|cc|g|gm|mg|units)?\s*(?:\/|per|per\s*)\s*(\d+(?:\.\d+)?)\s*(?:lb|lbs|l|g|kg|bw)');
      final match = regExp.firstMatch(desc.toLowerCase());
      if (match != null) {
        ratioVolume = double.tryParse(match.group(1) ?? '') ?? 0.0;
        final rawUnit = match.group(2);
        if (rawUnit != null) {
          if (rawUnit == 'g') {
            localDoseUnit = 'g';
          } else if (rawUnit == 'gm') {
            localDoseUnit = 'gm';
          } else if (rawUnit == 'mg') {
            localDoseUnit = 'mg';
          } else if (rawUnit == 'units') {
            localDoseUnit = 'units';
          }
        }
        ratioWeight = double.tryParse(match.group(3) ?? '') ?? 0.0;
      } else {
        // Check if it is a fixed dosage (e.g., '2ml SQ', '5g (Oral)')
        final matchFixed = RegExp(r'^(\d+(?:\.\d+)?)\s*(ml|cc|g|gm|units|mg)').firstMatch(desc.toLowerCase());
        if (matchFixed != null && !desc.toLowerCase().contains(' or ')) {
          final fixedVal = double.tryParse(matchFixed.group(1) ?? '') ?? 0.0;
          final rawUnit = matchFixed.group(2);
          if (rawUnit != null) {
            if (rawUnit == 'g') {
              localDoseUnit = 'g';
            } else if (rawUnit == 'gm') {
              localDoseUnit = 'gm';
            } else if (rawUnit == 'mg') {
              localDoseUnit = 'mg';
            } else if (rawUnit == 'units') {
              localDoseUnit = 'units';
            }
          }
          setState(() {
            _calculatedDose = fixedVal;
            _doseUnit = localDoseUnit;
            _dosageInstruction = 'Fixed Dose: ${fixedVal.toStringAsFixed(1)} $localDoseUnit ($desc)';
          });
        } else {
          setState(() {
            _calculatedDose = null;
            _doseUnit = 'mL (cc)';
            _dosageInstruction = desc.isNotEmpty ? desc : 'No weight-based dosage rule available.';
          });
        }
        return;
      }
    }

    if (ratioWeight == 0) {
      setState(() {
        _calculatedDose = null;
        _doseUnit = 'mL (cc)';
        _dosageInstruction = 'Invalid weight specification.';
      });
      return;
    }

    final dose = (weightLbs * ratioVolume) / ratioWeight;
    setState(() {
      _calculatedDose = dose;
      _doseUnit = localDoseUnit;
      _dosageInstruction =
          'Rule: ${ratioVolume.toStringAsFixed(2)} $localDoseUnit per ${ratioWeight.toStringAsFixed(1)} lbs';
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranch Calculators'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          tabs: const [
            Tab(
              icon: Icon(Icons.biotech_outlined),
              text: 'McMaster FEC',
            ),
            Tab(
              icon: Icon(Icons.percent_outlined),
              text: 'FERC Reduction',
            ),
            Tab(
              icon: Icon(Icons.medication_outlined),
              text: 'Dosage Calc',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFecTab(primaryColor, isDark),
          _buildFercTab(primaryColor, isDark),
          _buildDosageTab(primaryColor, isDark),
        ],
      ),
    );
  }

  Widget _buildFecTab(Color primaryColor, bool isDark) {
    final epg = _calculatedEpg;
    final factor = _calculatedFactor;
    final severity = _fecSeverity;
    final severityColor = _fecSeverityColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header Card: Results ──────────────────────────────────────────
          Card(
            elevation: 4,
            shadowColor: severityColor.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: severityColor.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.grey[900]!, Colors.grey[850]!]
                      : [severityColor.withValues(alpha: 0.05), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    'Calculated Parasite Burden',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$epg EPG',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: severityColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Eggs Per Gram',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: severityColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      severity,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: severityColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Multiplication Factor: x${factor.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Input Fields ──────────────────────────────────────────────────
          Text(
            'McMaster Setup Options',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 10),

          // Presets or Custom Toggle
          Row(
            children: [
              const Text('Use Custom Dilution Ratio'),
              const Spacer(),
              Switch(
                value: _useCustomMcMaster,
                onChanged: (val) {
                  setState(() {
                    _useCustomMcMaster = val;
                    if (!val) {
                      _fecesWeight = 2.0;
                      _flotationVolume = 28.0;
                      _customFecesController.text = '2.0';
                      _customVolumeController.text = '28.0';
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (!_useCustomMcMaster) ...[
            // Presets Dropdown
            DropdownButtonFormField<String>(
              initialValue: '2.0 g feces + 28.0 mL solution (Factor 50)',
              decoration: const InputDecoration(
                labelText: 'Standard Dilution Presets',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: '2.0 g feces + 28.0 mL solution (Factor 50)',
                  child: Text('2g feces in 28mL solution (Multiplier 50)'),
                ),
                DropdownMenuItem(
                  value: '4.0 g feces + 26.0 mL solution (Factor 25)',
                  child: Text('4g feces in 26mL solution (Multiplier 25)'),
                ),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  if (val.startsWith('2.0 g feces + 28.0 mL')) {
                    _fecesWeight = 2.0;
                    _flotationVolume = 28.0;
                  } else if (val.startsWith('4.0 g feces + 26.0 mL')) {
                    _fecesWeight = 4.0;
                    _flotationVolume = 26.0;
                  }
                });
              },
            ),
          ] else ...[
            // Custom Inputs Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customFecesController,
                    decoration: const InputDecoration(
                      labelText: 'Feces Weight (g)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _fecesWeight = double.tryParse(val) ?? 2.0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _customVolumeController,
                    decoration: const InputDecoration(
                      labelText: 'Flotation Vol (mL)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _flotationVolume = double.tryParse(val) ?? 28.0;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Chambers/Grids Counted Dropdown
          DropdownButtonFormField<int>(
            initialValue: _chambersCounted,
            decoration: const InputDecoration(
              labelText: 'McMaster Grid Chambers Counted',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 Chamber / Grid (0.15 mL volume)')),
              DropdownMenuItem(value: 2, child: Text('2 Chambers / Grids (0.30 mL standard)')),
              DropdownMenuItem(value: 3, child: Text('3 Chambers / Grids (0.45 mL volume)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _chambersCounted = val);
              }
            },
          ),
          const SizedBox(height: 16),

          // Eggs Counted Input Field with Easy Plus/Minus Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _eggsCountedController,
                  decoration: const InputDecoration(
                    labelText: 'Total Eggs Counted',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (val) {
                    setState(() {
                      _eggsCounted = int.tryParse(val) ?? 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                onPressed: () {
                  setState(() {
                    if (_eggsCounted > 0) {
                      _eggsCounted--;
                      _eggsCountedController.text = _eggsCounted.toString();
                    }
                  });
                },
                child: const Icon(Icons.remove),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                onPressed: () {
                  setState(() {
                    _eggsCounted++;
                    _eggsCountedController.text = _eggsCounted.toString();
                  });
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Select Mode Callback Action Button ───────────────────────────
          if (widget.isSelectMode)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context, '$epg EPG');
              },
              icon: const Icon(Icons.check_circle_outline),
              label: Text('Use calculated EPG ($epg EPG)'),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modified McMaster formula: EPG = (Eggs / Chamber Vol) * (Total Vol / Feces Weight). Assumes density of feces is 1g/mL.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFercTab(Color primaryColor, bool isDark) {
    final reduction = _fercReduction;
    final efficacy = _fercEfficacy;
    final efficacyColor = _fercEfficacyColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header Card: Results ──────────────────────────────────────────
          Card(
            elevation: 4,
            shadowColor: efficacyColor.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: efficacyColor.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.grey[900]!, Colors.grey[850]!]
                      : [efficacyColor.withValues(alpha: 0.05), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    'Dewormer Efficacy',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reduction != null
                        ? '${reduction.toStringAsFixed(1)}%'
                        : '--%',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: efficacyColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Fecal Egg Count Reduction',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: efficacyColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: efficacyColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      efficacy,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: efficacyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Input Fields ──────────────────────────────────────────────────
          Text(
            'Fecal Egg Count Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _preEpgController,
            decoration: const InputDecoration(
              labelText: 'Pre-Treatment EPG Count',
              hintText: 'e.g. 1500',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (val) {
              setState(() {
                _preTreatmentEpg = int.tryParse(val) ?? 0;
              });
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _postEpgController,
            decoration: const InputDecoration(
              labelText: 'Post-Treatment EPG Count (10-14 days after)',
              hintText: 'e.g. 50',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (val) {
              setState(() {
                _postTreatmentEpg = int.tryParse(val) ?? 0;
              });
            },
          ),
          const SizedBox(height: 24),

          // ─── Select Mode Action Button ────────────────────────────────────
          if (widget.isSelectMode && reduction != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context,
                    'FERC: ${reduction.toStringAsFixed(1)}% (${reduction >= 95 ? "Normal" : "Resistant"})');
              },
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                  'Use calculated FERC (${reduction.toStringAsFixed(1)}%)'),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'FERC Efficacy Standards (Goat/Sheep)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• Highly Effective: 95% or higher reduction.\n'
                    '• Suspect/Equivocal: 90% to 94% reduction.\n'
                    '• Confirmed Resistance: Under 90% reduction.',
                    style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDosageTab(Color primaryColor, bool isDark) {
    final activeAnimalsAsync = ref.watch(activeAnimalsProvider);
    final isCalculated = _calculatedDose != null;

    return activeAnimalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading animals: $err')),
      data: (animals) {
        if (animals.isEmpty) {
          return const Center(child: Text('No active animals found in database.'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header Card: Calculated Dose ─────────────────────────────
              Card(
                elevation: 4,
                shadowColor: isCalculated ? primaryColor.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isCalculated ? primaryColor.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [Colors.grey[900]!, Colors.grey[850]!]
                          : [
                              isCalculated
                                  ? primaryColor.withValues(alpha: 0.05)
                                  : Colors.grey.withValues(alpha: 0.05),
                              Colors.white
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        'Calculated Dosage',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isCalculated
                            ? '${_calculatedDose!.toStringAsFixed(2)} $_doseUnit'
                            : '--',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: isCalculated ? primaryColor : Colors.grey,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: (isCalculated ? primaryColor : Colors.grey)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _dosageInstruction,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isCalculated ? primaryColor : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── Input Fields ──────────────────────────────────────────────
              Text(
                'Animal Selection & Weight',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 10),

              // Animal Dropdown
              DropdownButtonFormField<Animal>(
                initialValue: _selectedAnimal,
                decoration: const InputDecoration(
                  labelText: 'Select Animal',
                  border: OutlineInputBorder(),
                ),
                items: animals.map((a) {
                  final tagStr = a.earTag != null ? ' (Tag: ${a.earTag})' : '';
                  return DropdownMenuItem<Animal>(
                    value: a,
                    child: Text('${a.name}$tagStr'),
                  );
                }).toList(),
                onChanged: (animal) {
                  if (animal != null && animal.id != null) {
                    setState(() {
                      _selectedAnimal = animal;
                    });
                    _loadLastWeight(animal.id!);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Weight input + Unit Selector
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _animalWeightController,
                          decoration: const InputDecoration(
                            labelText: 'Animal Weight',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          onChanged: (val) {
                            _calculateDosage();
                          },
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            _weightStatusText,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ToggleButtons(
                    isSelected: [!_isKg, _isKg],
                    borderRadius: BorderRadius.circular(8),
                    constraints: const BoxConstraints(
                      minWidth: 50,
                      minHeight: 48,
                    ),
                    onPressed: (index) {
                      setState(() {
                        _isKg = index == 1;
                        _calculateDosage();
                      });
                    },
                    children: const [
                      Text('lbs'),
                      Text('kgs'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'Medication & Product Rule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 10),

              // Medication Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedMedication,
                decoration: const InputDecoration(
                  labelText: 'Select Medication',
                  border: OutlineInputBorder(),
                ),
                items: [
                  ...HealthConstants.recommendedDosages.keys,
                  'Custom',
                ].map((med) {
                  return DropdownMenuItem<String>(
                    value: med,
                    child: Text(med),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedMedication = val;
                      _calculateDosage();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Custom Medication Fields
              if (_selectedMedication == 'Custom') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customDoseVolumeController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Vol (mL)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => _calculateDosage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _customPerWeightController,
                        decoration: const InputDecoration(
                          labelText: 'Per Body Weight (lbs)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => _calculateDosage(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ─── Select Mode Button ────────────────────────────────────────
              if (widget.isSelectMode && isCalculated)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(
                      context,
                      '$_selectedMedication: ${_calculatedDose!.toStringAsFixed(2)} $_doseUnit ($_dosageInstruction)',
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                      'Use calculated dose (${_calculatedDose!.toStringAsFixed(2)} $_doseUnit)'),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 24, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Disclaimer: FlockKeeper calculations are suggestions based on manufacturer guidelines. Always consult a licensed veterinarian before treating livestock.',
                          style: TextStyle(fontSize: 11, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
