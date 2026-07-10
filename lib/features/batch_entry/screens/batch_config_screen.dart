// lib/features/batch_entry/screens/batch_config_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/animal_model.dart';
import '../../../data/models/weight_record_model.dart';
import '../../../data/models/health_record_model.dart';
import '../../../data/models/kidding_record_model.dart';
import '../../../data/models/health_constants.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../breeding/providers/breeding_providers.dart';
import '../../weights/providers/weight_providers.dart';
import '../../animals/screens/animal_list_screen.dart';
import '../../health/screens/health_dashboard_screen.dart';
import '../../finances/providers/financial_providers.dart';

class BatchKidState {
  String name = '';
  String earTag = '';
  String tattoo = '';
  double? weightLbs;
  KidSex sex = KidSex.doe;
  SurvivalStatus survivalStatus = SurvivalStatus.alive;
  Presentation presentation = Presentation.normal;
  bool receivedColostrum = true;
  bool bottleFed = false;
  String notes = '';
}

enum BatchMode {
  recordEvents,
  addAnimals,
}

class BatchEntryRowState {
  final Animal animal;
  final bool isNew;
  
  // New animal fields (addAnimals mode)
  final TextEditingController nameController = TextEditingController();
  final TextEditingController earTagController = TextEditingController();
  final TextEditingController tattooController = TextEditingController();
  final TextEditingController breedController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  Sex sex;
  DateTime? dob;
  int? rowSireId;
  int? rowDamId;
  final TextEditingController purchasePriceController = TextEditingController();
  final TextEditingController purchaseFromController = TextEditingController();
  String? herdBook;

  // Weight fields
  final TextEditingController weightController = TextEditingController();
  final TextEditingController weightNotesController = TextEditingController();
  
  // Health fields
  int? famachaScore;
  double? bcsScore;
  
  String? actionTaken;
  HealthRecordType? treatmentDecision;
  String? selectedProduct;
  final TextEditingController dosageController = TextEditingController();
  final TextEditingController testResultController = TextEditingController();
  final TextEditingController healthNotesController = TextEditingController();
  
  // Kidding fields
  List<BatchKidState> kids = [];
  int? sireId;
  int? damConditionScore;
  final TextEditingController complicationsController = TextEditingController();
  final TextEditingController kiddingNotesController = TextEditingController();

  // Removal/Status fields (recordEvents mode removal flow)
  AnimalStatus removalStatus = AnimalStatus.active;
  final TextEditingController soldToController = TextEditingController();
  final TextEditingController soldPriceController = TextEditingController();
  final TextEditingController deceasedReasonController = TextEditingController();

  BatchEntryRowState(this.animal) : isNew = false, sex = animal.sex, herdBook = animal.herdBook;

  BatchEntryRowState.forAddition(Sex defaultSex, {String? defaultHerdBook})
      : isNew = true,
        sex = defaultSex,
        herdBook = defaultHerdBook,
        animal = Animal(
          name: '',
          sex: defaultSex,
          breed: '',
          status: AnimalStatus.active,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  
  void dispose() {
    nameController.dispose();
    earTagController.dispose();
    tattooController.dispose();
    breedController.dispose();
    colorController.dispose();
    purchasePriceController.dispose();
    purchaseFromController.dispose();
    weightController.dispose();
    weightNotesController.dispose();
    dosageController.dispose();
    testResultController.dispose();
    healthNotesController.dispose();
    complicationsController.dispose();
    kiddingNotesController.dispose();
    soldToController.dispose();
    soldPriceController.dispose();
    deceasedReasonController.dispose();
  }
}

class BatchConfigScreen extends ConsumerStatefulWidget {
  const BatchConfigScreen({super.key});

  @override
  ConsumerState<BatchConfigScreen> createState() => _BatchConfigScreenState();
}

class _BatchConfigScreenState extends ConsumerState<BatchConfigScreen> {
  final _configFormKey = GlobalKey<FormState>();

  // Mode Selection
  BatchMode _batchMode = BatchMode.recordEvents;

  // Event Categories
  bool _recordWeight = true;
  bool _recordHealth = false;
  bool _recordKidding = false;
  bool _recordRemoval = false;

  // Event Date
  DateTime _batchDate = DateTime.now();

  // Shared Health Configuration
  HealthRecordType _sharedHealthType = HealthRecordType.vaccination;
  String? _sharedActionTaken;
  HealthRecordType? _sharedTreatmentDecision;
  String? _sharedProduct;
  final _sharedDiagnosisController = TextEditingController();
  final _sharedDosageController = TextEditingController();
  final _sharedCostController = TextEditingController();
  final _sharedAdminController = TextEditingController();
  final _sharedTestResultController = TextEditingController();

  // Shared Removal Configuration
  AnimalStatus _sharedRemovalStatus = AnimalStatus.sold;
  final _sharedSoldToController = TextEditingController();
  final _sharedSoldPriceController = TextEditingController();
  final _sharedDeceasedReasonController = TextEditingController();

  // Batch Add Animals Configuration
  int _addCount = 5;
  String _sharedAddBreed = 'Kiko';
  String? _sharedAddHerdBook = '100% New Zealand';
  Sex _sharedAddSex = Sex.doe;
  final _sharedAddPurchasePriceController = TextEditingController();
  final _sharedAddPurchaseFromController = TextEditingController();
  final _sharedAddInitialWeightController = TextEditingController();
  DateTime? _sharedAddPurchaseDate = DateTime.now();

  // Filters
  String _selectedBreed = 'All';
  String _selectedSex = 'All';
  DateTime? _dobStart;
  DateTime? _dobEnd;

  // Grid Data
  List<BatchEntryRowState> _rowStates = [];
  bool _loaded = false;
  bool _showConfig = true;
  bool _isSaving = false;

  List<Animal> _activeBucks = [];
  List<String> _availableBreeds = ['All'];

  @override
  void dispose() {
    _sharedDiagnosisController.dispose();
    _sharedDosageController.dispose();
    _sharedCostController.dispose();
    _sharedAdminController.dispose();
    _sharedTestResultController.dispose();
    _sharedSoldToController.dispose();
    _sharedSoldPriceController.dispose();
    _sharedDeceasedReasonController.dispose();
    _sharedAddPurchasePriceController.dispose();
    _sharedAddPurchaseFromController.dispose();
    _sharedAddInitialWeightController.dispose();
    for (var row in _rowStates) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _selectBatchDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _batchDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _batchDate = picked;
      });
    }
  }

  void _syncSharedRemovalToRows() {
    setState(() {
      for (var row in _rowStates) {
        row.removalStatus = _sharedRemovalStatus;
        row.soldToController.text = _sharedSoldToController.text;
        row.soldPriceController.text = _sharedSoldPriceController.text;
        row.deceasedReasonController.text = _sharedDeceasedReasonController.text;
      }
    });
  }

  void _syncSharedAddDetailsToRows() {
    setState(() {
      for (var row in _rowStates) {
        if (row.isNew) {
          row.breedController.text = _sharedAddBreed;
          row.sex = _sharedAddSex;
          row.herdBook = _sharedAddHerdBook;
          row.purchasePriceController.text = _sharedAddPurchasePriceController.text;
          row.purchaseFromController.text = _sharedAddPurchaseFromController.text;
          row.weightController.text = _sharedAddInitialWeightController.text;
        }
      }
    });
  }

  Future<void> _selectSharedPurchaseDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sharedAddPurchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _sharedAddPurchaseDate = picked;
        for (var row in _rowStates) {
          if (row.isNew) {
            row.dob = picked;
          }
        }
      });
    }
  }

  void _prepareAddList() {
    setState(() {
      for (var row in _rowStates) {
        row.dispose();
      }
      _rowStates = List.generate(_addCount, (index) {
        final row = BatchEntryRowState.forAddition(_sharedAddSex, defaultHerdBook: _sharedAddHerdBook);
        row.breedController.text = _sharedAddBreed;
        row.purchasePriceController.text = _sharedAddPurchasePriceController.text;
        row.purchaseFromController.text = _sharedAddPurchaseFromController.text;
        row.weightController.text = _sharedAddInitialWeightController.text;
        row.dob = _sharedAddPurchaseDate;
        return row;
      });
      _loaded = true;
      _showConfig = false;
    });
  }

  List<String> _getHerdBooksForBreed(String? breed) {
    switch (breed) {
      case 'Kiko':
        return const ['100% New Zealand', 'Percentage', 'Purebred', 'Commercial'];
      case 'Boer':
        return const ['Fullblood', 'Purebred', 'Percentage', 'Commercial'];
      case 'Spanish':
        return const ['Purebred Spanish', 'Crossbred'];
      case 'Myotonic (Fainting)':
        return const ['Purebred Myotonic', 'Percentage', 'Commercial'];
      case 'Nubian':
      case 'Alpine':
      case 'LaMancha':
      case 'Saanen':
      case 'Toggenburg':
      case 'Oberhasli':
      case 'Nigerian Dwarf':
        return const ['Purebred', 'Recorded Grade', 'Experimental'];
      case 'Pygmy':
        return const ['Registered Pygmy', 'Unregistered/Grade'];
      case 'Angora':
        return const ['Purebred Angora', 'Grade'];
      case 'Savanna':
        return const ['Fullblood Savanna', 'Percentage', 'Commercial'];
      case 'Texmaster':
        return const ['Purebred Texmaster', 'Percentage'];
      default:
        return const ['Purebred', 'Percentage', 'Commercial', 'Other'];
    }
  }

  Future<void> _selectDobStart(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dobStart ?? DateTime.now().subtract(const Duration(days: 365 * 3)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobStart = picked;
      });
    }
  }

  Future<void> _selectDobEnd(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dobEnd ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobEnd = picked;
      });
    }
  }

  String _healthTypeLabel(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.famacha: return 'FAMACHA';
      case HealthRecordType.bcs: return 'BCS';
      case HealthRecordType.vaccination: return 'Vaccination';
      case HealthRecordType.deworming: return 'Deworming';
      case HealthRecordType.antibiotic: return 'Antibiotic';
      case HealthRecordType.supplement: return 'Supplement';
      case HealthRecordType.labTest: return 'Lab Test';
      case HealthRecordType.grooming: return 'Grooming';
      case HealthRecordType.pregnancyCheck: return 'Pregnancy Check';
      case HealthRecordType.illness: return 'Illness';
      case HealthRecordType.injury: return 'Injury';
      case HealthRecordType.surgery: return 'Surgery';
      case HealthRecordType.vetVisit: return 'Vet Visit';
      case HealthRecordType.other: return 'Other';
    }
  }

  BirthType _getBirthType(int size) {
    if (size == 1) return BirthType.single;
    if (size == 2) return BirthType.twin;
    if (size == 3) return BirthType.triplet;
    if (size == 4) return BirthType.quad;
    return BirthType.other;
  }

  List<String> _getAvailableActions(HealthRecordType type) {
    return type == HealthRecordType.famacha 
        ? HealthConstants.famachaActions 
        : HealthConstants.generalActions;
  }

  List<String> _getCategoryProducts(HealthRecordType? type) {
    if (type == null) return [];
    return HealthConstants.categoryProducts[type] ?? [];
  }

  void _onSharedProductChanged(String? product) {
    if (product != null) {
      _sharedProduct = product;
      _sharedDosageController.text = HealthConstants.recommendedDosages[product] ?? '';
      _syncSharedHealthToRows();
    }
  }

  void _onRowProductChanged(BatchEntryRowState row, String? product) {
    setState(() {
      row.selectedProduct = product;
      if (product != null) {
        row.dosageController.text = HealthConstants.recommendedDosages[product] ?? '';
      }
    });
  }

  void _loadAnimals(List<Animal> allActiveAnimals) {
    final breeds = allActiveAnimals.map((a) => a.breed).toSet().toList();
    breeds.sort();
    
    setState(() {
      _availableBreeds = ['All', ...breeds];
      _activeBucks = allActiveAnimals.where((a) => a.sex == Sex.buck).toList();
      
      // Clean up previous states
      for (var row in _rowStates) {
        row.dispose();
      }
      _rowStates = [];

      // Filter animals in memory
      final filtered = allActiveAnimals.where((animal) {
        if (_selectedBreed != 'All' && animal.breed != _selectedBreed) {
          return false;
        }
        if (_selectedSex != 'All' && animal.sex.name.toLowerCase() != _selectedSex.toLowerCase()) {
          return false;
        }
        if (animal.dob != null) {
          if (_dobStart != null && animal.dob!.isBefore(_dobStart!)) {
            return false;
          }
          if (_dobEnd != null && animal.dob!.isAfter(_dobEnd!)) {
            return false;
          }
        } else if (_dobStart != null || _dobEnd != null) {
          return false;
        }
        return true;
      }).toList();

      // Build row states
      _rowStates = filtered.map((animal) {
        final row = BatchEntryRowState(animal);
        
        // Pre-populate with shared health configurations
        row.actionTaken = _sharedActionTaken;
        row.treatmentDecision = _sharedTreatmentDecision;
        row.selectedProduct = _sharedProduct;
        row.dosageController.text = _sharedDosageController.text;
        row.testResultController.text = _sharedTestResultController.text;
        
        return row;
      }).toList();

      _loaded = true;
      _showConfig = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded ${_rowStates.length} animals matching criteria.')),
    );
  }

  void _syncSharedHealthToRows() {
    for (var row in _rowStates) {
      row.actionTaken ??= _sharedActionTaken;
      row.treatmentDecision ??= _sharedTreatmentDecision;
      row.selectedProduct ??= _sharedProduct;
      if (row.dosageController.text.isEmpty) {
        row.dosageController.text = _sharedDosageController.text;
      }
      if (row.testResultController.text.isEmpty) {
        row.testResultController.text = _sharedTestResultController.text;
      }
    }
  }

  void _showKiddingDialog(BatchEntryRowState row) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _KiddingDetailsDialog(
          doe: row.animal,
          activeBucks: _activeBucks,
          initialKids: row.kids,
          initialSireId: row.sireId,
          initialDamConditionScore: row.damConditionScore,
          initialComplications: row.complicationsController.text,
          initialNotes: row.kiddingNotesController.text,
          onConfirm: (kids, sireId, conditionScore, complications, notes) {
            setState(() {
              row.kids = kids;
              row.sireId = sireId;
              row.damConditionScore = conditionScore;
              row.complicationsController.text = complications;
              row.kiddingNotesController.text = notes;
            });
          },
        );
      },
    );
  }

  Future<void> _saveBatch(List<Animal> allActiveAnimals) async {
    if (_batchMode == BatchMode.recordEvents && !_recordWeight && !_recordHealth && !_recordKidding && !_recordRemoval) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one event category to record.')),
      );
      return;
    }

    if (_rowStates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data loaded to record.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final weightRepo = ref.read(weightRepositoryProvider);
    final healthRepo = ref.read(healthRepositoryProvider);
    final kiddingRepo = ref.read(kiddingRepositoryProvider);
    final animalRepo = ref.read(animalRepositoryProvider);

    int addedCount = 0;
    int weightsCount = 0;
    int healthsCount = 0;
    int kiddingsCount = 0;
    int kidsCount = 0;
    int removalsCount = 0;

    try {
      if (_batchMode == BatchMode.addAnimals) {
        for (final row in _rowStates) {
          final name = row.nameController.text.trim();
          if (name.isEmpty) continue;

          final breed = row.breedController.text.trim().isNotEmpty ? row.breedController.text.trim() : 'Kiko';
          final sex = row.sex;
          final dob = row.dob;
          final color = row.colorController.text.trim();
          final purchasePrice = double.tryParse(row.purchasePriceController.text.trim());
          final purchaseFrom = row.purchaseFromController.text.trim();
          final sireId = row.rowSireId;
          final damId = row.rowDamId;

          String? sireName;
          if (sireId != null) {
            sireName = allActiveAnimals.firstWhere((b) => b.id == sireId, orElse: () => row.animal).name;
          }
          String? damName;
          if (damId != null) {
            damName = allActiveAnimals.firstWhere((a) => a.id == damId, orElse: () => row.animal).name;
          }

          final newAnimal = Animal(
            name: name,
            sex: sex,
            dob: dob,
            breed: breed,
            herdBook: row.herdBook,
            color: color.isNotEmpty ? color : null,
            earTag: row.earTagController.text.trim().isNotEmpty ? row.earTagController.text.trim() : null,
            tattoo: row.tattooController.text.trim().isNotEmpty ? row.tattooController.text.trim() : null,
            purchaseDate: dob, // Set dob as purchase/acquisition date
            purchasePrice: purchasePrice,
            soldTo: purchaseFrom.isNotEmpty ? purchaseFrom : null, // soldTo stores seller
            sireId: sireId,
            damId: damId,
            sireName: sireName,
            damName: damName,
            status: AnimalStatus.active,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          final newId = await animalRepo.insertAnimal(newAnimal);
          addedCount++;

          // Record initial weight
          final wText = row.weightController.text.trim();
          final wLbs = double.tryParse(wText);
          if (wLbs != null) {
            final record = WeightRecord(
              animalId: newId,
              weightLbs: wLbs,
              weighDate: dob ?? DateTime.now(),
              notes: 'Initial weight recorded at acquisition',
            );
            await weightRepo.insertWeightRecord(record);
            weightsCount++;
          }
        }
      } else {
        // Record Events Mode
        for (final row in _rowStates) {
          final animalId = row.animal.id!;

          // 1. Record Weight
          if (_recordWeight) {
            final wText = row.weightController.text.trim();
            final wLbs = double.tryParse(wText);
            if (wLbs != null) {
              final record = WeightRecord(
                animalId: animalId,
                weightLbs: wLbs,
                weighDate: _batchDate,
                notes: row.weightNotesController.text.trim().isNotEmpty 
                    ? row.weightNotesController.text.trim() : null,
              );
              await weightRepo.insertWeightRecord(record);
              weightsCount++;
            }
          }

          // 2. Record Health
          if (_recordHealth) {
            final hasFamacha = row.famachaScore != null;
            final hasBcs = row.bcsScore != null;
            final action = row.actionTaken;
            final product = row.selectedProduct;
            final dosage = row.dosageController.text.trim();
            final testResult = row.testResultController.text.trim();
            final notesInput = row.healthNotesController.text.trim();

            if (hasFamacha || hasBcs || action != null || testResult.isNotEmpty || notesInput.isNotEmpty) {
              String finalNotes = notesInput;
              if (action != null) {
                finalNotes = 'Action: $action. $finalNotes';
              }
              if (testResult.isNotEmpty) {
                finalNotes = 'Result: $testResult. $finalNotes';
              }

              final double? cost = double.tryParse(_sharedCostController.text.trim());
              final HealthRecordType recordCategoryType = row.treatmentDecision ?? _sharedHealthType;

              final record = HealthRecord(
                animalId: animalId,
                recordType: recordCategoryType,
                recordDate: _batchDate,
                diagnosis: _sharedDiagnosisController.text.trim().isNotEmpty 
                    ? _sharedDiagnosisController.text.trim() : null,
                treatment: product != null && product.isNotEmpty ? product : null,
                dosage: dosage.isNotEmpty ? dosage : null,
                famachaScore: row.famachaScore,
                bcsScore: row.bcsScore,
                notes: finalNotes.trim().isNotEmpty ? finalNotes.trim() : null,
                administrator: _sharedAdminController.text.trim().isNotEmpty 
                    ? _sharedAdminController.text.trim() : null,
                cost: cost,
                resolved: true,
              );
              await healthRepo.insertHealthRecord(record);
              healthsCount++;
            }
          }

          // 3. Record Kidding
          if (_recordKidding && row.animal.sex == Sex.doe && row.kids.isNotEmpty) {
            final sireId = row.sireId;
            final sireName = sireId != null 
                ? _activeBucks.firstWhere((b) => b.id == sireId, orElse: () => row.animal).name 
                : null;
            final doeName = row.animal.name;

            for (int i = 0; i < row.kids.length; i++) {
              final kid = row.kids[i];
              int? kidAnimalId;

              if (kid.survivalStatus == SurvivalStatus.alive || kid.survivalStatus == SurvivalStatus.sold) {
                final kidAnimal = Animal(
                  name: kid.name.trim().isNotEmpty ? kid.name.trim() : 'Kid ${i + 1} of $doeName',
                  earTag: kid.earTag.trim().isNotEmpty ? kid.earTag.trim() : null,
                  tattoo: kid.tattoo.trim().isNotEmpty ? kid.tattoo.trim() : null,
                  dob: _batchDate,
                  sex: kid.sex == KidSex.doe ? Sex.doe : Sex.buck,
                  damId: animalId,
                  sireId: sireId,
                  damName: doeName,
                  sireName: sireName,
                  breed: row.animal.breed, 
                  birthWeightLbs: kid.weightLbs,
                  status: AnimalStatus.active,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                kidAnimalId = await animalRepo.insertAnimal(kidAnimal);
                kidsCount++;
              }

              final kiddingRecord = KiddingRecord(
                doeId: animalId,
                buckId: sireId,
                kidId: kidAnimalId,
                kidName: kid.name.trim(),
                kiddingDate: _batchDate,
                birthOrder: i + 1,
                litterSize: row.kids.length,
                birthWeightLbs: kid.weightLbs,
                sex: kid.sex,
                birthType: _getBirthType(row.kids.length),
                presentation: kid.presentation,
                survivalStatus: kid.survivalStatus,
                receivedColostrum: kid.receivedColostrum,
                bottleFed: kid.bottleFed,
                damConditionScore: row.damConditionScore,
                complications: row.complicationsController.text.trim().isNotEmpty 
                    ? row.complicationsController.text.trim() : null,
                notes: ('${row.kiddingNotesController.text.trim()} ${kid.notes}').trim().isNotEmpty 
                    ? ('${row.kiddingNotesController.text.trim()} ${kid.notes}').trim() : null,
                createdAt: DateTime.now(),
              );
              await kiddingRepo.insertKiddingRecord(kiddingRecord);
              kiddingsCount++;
            }
          }

          // 4. Record Status/Removal updates
          if (_recordRemoval && row.removalStatus != AnimalStatus.active) {
            final price = double.tryParse(row.soldPriceController.text.trim());
            final soldTo = row.soldToController.text.trim();
            final deceasedReason = row.deceasedReasonController.text.trim();

            DateTime? soldDate;
            DateTime? deceasedDate;
            if (row.removalStatus == AnimalStatus.sold || row.removalStatus == AnimalStatus.transferred) {
              soldDate = _batchDate;
            } else if (row.removalStatus == AnimalStatus.deceased) {
              deceasedDate = _batchDate;
            }

            final updatedAnimal = row.animal.copyWith(
              status: row.removalStatus,
              soldDate: soldDate,
              soldPrice: price,
              soldTo: soldTo.isNotEmpty ? soldTo : null,
              deceasedDate: deceasedDate,
              deceasedReason: deceasedReason.isNotEmpty ? deceasedReason : null,
              updatedAt: DateTime.now(),
            );

            await animalRepo.updateAnimal(updatedAnimal);
            removalsCount++;
          }
        }
      }

      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);
      ref.invalidate(searchedAnimalsProvider);
      ref.invalidate(breedingListProvider);
      ref.invalidate(kiddingRecordsListProvider);
      ref.invalidate(breedingStatsProvider);
      ref.invalidate(financialRecordsProvider);
      for (final row in _rowStates) {
        if (!row.isNew && row.animal.id != null) {
          final animalId = row.animal.id!;
          ref.invalidate(weightHistoryProvider(animalId));
          ref.invalidate(latestWeightProvider(animalId));
          ref.invalidate(lifetimeADGProvider(animalId));
          ref.invalidate(recentADGProvider(animalId));
          ref.invalidate(milestoneWeightsProvider(animalId));
          ref.invalidate(animalByIdProvider(animalId));
          ref.invalidate(healthHistoryProvider(animalId));
          ref.invalidate(animalRemindersProvider(animalId));
          ref.invalidate(animalPastureProvider(animalId));
          ref.invalidate(financialRecordsForAnimalProvider(animalId));
        }
      }

      setState(() {
        _isSaving = false;
        for (var row in _rowStates) {
          row.dispose();
        }
        _rowStates = [];
        _loaded = false;
      });

      if (mounted) {
        String msg = 'Batch save complete:';
        if (addedCount > 0) msg += ' $addedCount new animals added.';
        if (weightsCount > 0) msg += ' $weightsCount weights.';
        if (healthsCount > 0) msg += ' $healthsCount health records.';
        if (kiddingsCount > 0) msg += ' $kiddingsCount kidding events ($kidsCount new kids registered).';
        if (removalsCount > 0) msg += ' $removalsCount animal removals/status updates.';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AnimalListScreen()),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving batch: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAnimalsAsync = ref.watch(activeAnimalsProvider);

    // Determine dynamic columns to show based on row states
    bool showTreatmentCols = false;
    bool showDiagnosticCols = false;
    bool showRemovalCols = false;

    if (_loaded) {
      showTreatmentCols = _rowStates.any((r) => 
        r.actionTaken == 'Deworm immediately' || 
        r.actionTaken == 'Administer Treatment' || 
        r.treatmentDecision != null
      );
      showDiagnosticCols = _rowStates.any((r) => 
        r.actionTaken == 'Fecal Egg Count (FEC) Test' || 
        r.actionTaken == 'Perform Diagnostic Test'
      );
      showRemovalCols = _rowStates.any((r) => r.removalStatus != AnimalStatus.active);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Entry'),
        actions: [
          if (_loaded && _rowStates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _saveBatch(activeAnimalsAsync.value ?? []),
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
            ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'batch_entry'),
      body: activeAnimalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading animals: $err')),
        data: (allActiveAnimals) {
          if (_availableBreeds.length <= 1 && allActiveAnimals.isNotEmpty) {
            final breeds = allActiveAnimals.map((a) => a.breed).toSet().toList();
            breeds.sort();
            _availableBreeds = ['All', ...breeds];
            _activeBucks = allActiveAnimals.where((a) => a.sex == Sex.buck).toList();
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Configuration Header ──────────────────────────────────────────────
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Form(
                      key: _configFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showConfig = !_showConfig;
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.settings, size: 20, color: Colors.blueGrey),
                                    const SizedBox(width: 8),
                                    Text(
                                      _loaded ? 'Batch Settings & Presets' : 'Configure Settings & Presets',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_loaded)
                                  Icon(
                                    _showConfig ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: Colors.blueGrey,
                                  ),
                              ],
                            ),
                          ),
                          if (!_showConfig) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12.0,
                              runSpacing: 4.0,
                              children: [
                                Text(
                                  'Presets: ${_recordWeight ? "Weight " : ""}${_recordHealth ? "Health " : ""}${_recordKidding ? "Kidding" : ""}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                if (_recordHealth)
                                  Text(
                                    'Event: ${_healthTypeLabel(_sharedHealthType)}${_sharedActionTaken != null ? " ($_sharedActionTaken)" : ""}',
                                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                  ),
                                Text(
                                  'Filters: Breed: $_selectedBreed • Sex: $_selectedSex',
                                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                ),
                              ],
                            ),
                          ],
                          if (_showConfig) ...[
                            const SizedBox(height: 12),
                            // Mode Selection Choice Chips
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(
                                      child: Text(
                                        'Record Events (Existing)',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    selected: _batchMode == BatchMode.recordEvents,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _batchMode = BatchMode.recordEvents;
                                          _loaded = false;
                                          _rowStates = [];
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(
                                      child: Text(
                                        'Add New Animals',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    selected: _batchMode == BatchMode.addAnimals,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _batchMode = BatchMode.addAnimals;
                                          _loaded = false;
                                          _rowStates = [];
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            if (_batchMode == BatchMode.recordEvents) ...[
                              // Categories and date selection
                              Wrap(
                                spacing: 4.0,
                                runSpacing: 4.0,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Categories:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 4),
                                  Checkbox(
                                    value: _recordWeight,
                                    onChanged: (val) => setState(() => _recordWeight = val ?? false),
                                  ),
                                  const Text('Weight'),
                                  Checkbox(
                                    value: _recordHealth,
                                    onChanged: (val) => setState(() => _recordHealth = val ?? false),
                                  ),
                                  const Text('Health'),
                                  Checkbox(
                                    value: _recordKidding,
                                    onChanged: (val) => setState(() => _recordKidding = val ?? false),
                                  ),
                                  const Text('Kidding'),
                                  Checkbox(
                                    value: _recordRemoval,
                                    onChanged: (val) => setState(() => _recordRemoval = val ?? false),
                                  ),
                                  const Text('Status/Removal'),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _selectBatchDate(context),
                                    icon: const Icon(Icons.calendar_today, size: 16),
                                    label: Text(DateFormat.yMMMd().format(_batchDate)),
                                  ),
                                ],
                              ),

                              // Shared Health Preset Configuration
                              if (_recordHealth) ...[
                                const Divider(),
                                const Text(
                                  'Shared Health Configuration:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isMobile = constraints.maxWidth < 600;
                                    final widgets = [
                                      DropdownButtonFormField<HealthRecordType>(
                                        initialValue: _sharedHealthType,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Event Type',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        items: HealthRecordType.values.map((type) {
                                          return DropdownMenuItem(
                                            value: type,
                                            child: Text(_healthTypeLabel(type)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _sharedHealthType = val;
                                              _sharedActionTaken = null;
                                              _sharedTreatmentDecision = null;
                                              _sharedProduct = null;
                                              _sharedDosageController.clear();
                                            });
                                          }
                                        },
                                      ),
                                      DropdownButtonFormField<String>(
                                        initialValue: _sharedActionTaken,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Shared Action Taken',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        items: _getAvailableActions(_sharedHealthType).map((action) {
                                          return DropdownMenuItem(value: action, child: Text(action));
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _sharedActionTaken = val;
                                            
                                            // Default decisions
                                            if (val == 'Deworm immediately') {
                                              _sharedTreatmentDecision = HealthRecordType.deworming;
                                            } else if (val == 'Administer Treatment') {
                                              _sharedTreatmentDecision = HealthConstants.categoryProducts.containsKey(_sharedHealthType) 
                                                  ? _sharedHealthType : null;
                                            } else {
                                              _sharedTreatmentDecision = null;
                                            }
                                            
                                            _sharedProduct = null;
                                            _sharedDosageController.clear();
                                            _sharedTestResultController.clear();
                                            
                                            _syncSharedHealthToRows();
                                          });
                                        },
                                      ),
                                      if (_sharedActionTaken == 'Administer Treatment' && 
                                          !HealthConstants.categoryProducts.containsKey(_sharedHealthType))
                                        DropdownButtonFormField<HealthRecordType>(
                                          initialValue: _sharedTreatmentDecision,
                                          decoration: const InputDecoration(
                                            labelText: 'Treat Category',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          ),
                                          items: [
                                            HealthRecordType.antibiotic,
                                            HealthRecordType.deworming,
                                            HealthRecordType.vaccination,
                                            HealthRecordType.supplement,
                                            HealthRecordType.other,
                                          ].map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              _sharedTreatmentDecision = val;
                                              _sharedProduct = null;
                                              _sharedDosageController.clear();
                                              _syncSharedHealthToRows();
                                            });
                                          },
                                        ),
                                    ];

                                    if (isMobile) {
                                      return Column(
                                        children: widgets.map((w) => Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: w,
                                        )).toList(),
                                      );
                                    } else {
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 2, child: widgets[0]),
                                          const SizedBox(width: 8),
                                          Expanded(flex: 3, child: widgets[1]),
                                          if (widgets.length > 2) ...[
                                            const SizedBox(width: 8),
                                            Expanded(flex: 2, child: widgets[2]),
                                          ],
                                        ],
                                      );
                                    }
                                  },
                                ),
                                
                                if (_sharedTreatmentDecision != null) ...[
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isMobile = constraints.maxWidth < 600;
                                      final productField = DropdownButtonFormField<String>(
                                        initialValue: _sharedProduct,
                                        decoration: const InputDecoration(
                                          labelText: 'Shared Product',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('- Select Product -')),
                                          ..._getCategoryProducts(_sharedTreatmentDecision).map((p) {
                                            return DropdownMenuItem(value: p, child: Text(p));
                                          }),
                                        ],
                                        onChanged: _onSharedProductChanged,
                                      );

                                      final dosageField = TextField(
                                        controller: _sharedDosageController,
                                        decoration: const InputDecoration(
                                          labelText: 'Shared Dosage',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        onChanged: (_) => _syncSharedHealthToRows(),
                                      );

                                      if (isMobile) {
                                        return Column(
                                          children: [
                                            productField,
                                            const SizedBox(height: 8),
                                            dosageField,
                                          ],
                                        );
                                      } else {
                                        return Row(
                                          children: [
                                            Expanded(child: productField),
                                            const SizedBox(width: 8),
                                            Expanded(child: dosageField),
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                ],
                                
                                if (_sharedActionTaken == 'Perform Diagnostic Test' || _sharedActionTaken == 'Fecal Egg Count (FEC) Test') ...[
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isMobile = constraints.maxWidth < 600;
                                      final testResultField = TextField(
                                        controller: _sharedTestResultController,
                                        decoration: const InputDecoration(
                                          labelText: 'Shared Test Result (Optional)',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        onChanged: (_) => _syncSharedHealthToRows(),
                                      );

                                      final treatDecisionField = DropdownButtonFormField<HealthRecordType?>(
                                        initialValue: _sharedTreatmentDecision,
                                        decoration: const InputDecoration(
                                          labelText: 'Shared Treatment Decision',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        items: [
                                          const DropdownMenuItem<HealthRecordType?>(
                                            value: null, 
                                            child: Text('None / Monitor'),
                                          ),
                                          ...[
                                            HealthRecordType.deworming,
                                            HealthRecordType.antibiotic,
                                            HealthRecordType.vaccination,
                                            HealthRecordType.supplement,
                                          ].map((t) => DropdownMenuItem<HealthRecordType?>(
                                            value: t,
                                            child: Text('Treat: ${t.name.toUpperCase()}'),
                                          )),
                                        ],
                                        onChanged: (val) {
                                          setState(() {
                                            _sharedTreatmentDecision = val;
                                            _sharedProduct = null;
                                            _sharedDosageController.clear();
                                            _syncSharedHealthToRows();
                                          });
                                        },
                                      );

                                      if (isMobile) {
                                        return Column(
                                          children: [
                                            testResultField,
                                            const SizedBox(height: 8),
                                            treatDecisionField,
                                          ],
                                        );
                                      } else {
                                        return Row(
                                          children: [
                                            Expanded(child: testResultField),
                                            const SizedBox(width: 8),
                                            Expanded(child: treatDecisionField),
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                ],

                                const SizedBox(height: 8),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isMobile = constraints.maxWidth < 600;
                                    final diagnosisField = TextField(
                                      controller: _sharedDiagnosisController,
                                      decoration: const InputDecoration(
                                        labelText: 'Diagnosis/Reason (Optional)',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                    );

                                    final costField = TextField(
                                      controller: _sharedCostController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Shared Cost \$ (Optional)',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                    );

                                    final adminField = TextField(
                                      controller: _sharedAdminController,
                                      decoration: const InputDecoration(
                                        labelText: 'Administrator (Optional)',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                    );

                                    if (isMobile) {
                                      return Column(
                                        children: [
                                          diagnosisField,
                                          const SizedBox(height: 8),
                                          costField,
                                          const SizedBox(height: 8),
                                          adminField,
                                        ],
                                      );
                                    } else {
                                      return Row(
                                        children: [
                                          Expanded(child: diagnosisField),
                                          const SizedBox(width: 8),
                                          Expanded(child: costField),
                                          const SizedBox(width: 8),
                                          Expanded(child: adminField),
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ],

                              // Shared Removal Configuration
                              if (_recordRemoval) ...[
                                const Divider(),
                                const Text(
                                  'Shared Removal Configuration:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isMobile = constraints.maxWidth < 600;
                                    final statusDropdown = DropdownButtonFormField<AnimalStatus>(
                                      initialValue: _sharedRemovalStatus,
                                      decoration: const InputDecoration(
                                        labelText: 'Shared New Status',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      items: [
                                        AnimalStatus.active,
                                        AnimalStatus.sold,
                                        AnimalStatus.deceased,
                                        AnimalStatus.culled,
                                        AnimalStatus.transferred,
                                      ].map((status) {
                                        return DropdownMenuItem(
                                          value: status,
                                          child: Text(status.name.toUpperCase()),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _sharedRemovalStatus = val;
                                            _syncSharedRemovalToRows();
                                          });
                                        }
                                      },
                                    );

                                    final buyerField = TextField(
                                      controller: _sharedSoldToController,
                                      decoration: const InputDecoration(
                                        labelText: 'Shared Buyer / Location (Optional)',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      onChanged: (_) => _syncSharedRemovalToRows(),
                                    );

                                    final priceField = TextField(
                                      controller: _sharedSoldPriceController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Shared Price per Head (Optional)',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      onChanged: (_) => _syncSharedRemovalToRows(),
                                    );

                                    final reasonField = TextField(
                                      controller: _sharedDeceasedReasonController,
                                      decoration: const InputDecoration(
                                        labelText: 'Shared Deceased Reason (Optional)',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      onChanged: (_) => _syncSharedRemovalToRows(),
                                    );

                                    final widgets = [
                                      statusDropdown,
                                      if (_sharedRemovalStatus == AnimalStatus.sold || _sharedRemovalStatus == AnimalStatus.transferred) ...[
                                        buyerField,
                                      ],
                                      if (_sharedRemovalStatus == AnimalStatus.sold) ...[
                                        priceField,
                                      ],
                                      if (_sharedRemovalStatus == AnimalStatus.deceased) ...[
                                        reasonField,
                                      ]
                                    ];

                                    if (isMobile) {
                                      return Column(
                                        children: widgets.map((w) => Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: w,
                                        )).toList(),
                                      );
                                    } else {
                                      return Row(
                                        children: widgets.map((w) => Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: w,
                                          ),
                                        )).toList(),
                                      );
                                    }
                                  },
                                ),
                              ],

                              const Divider(),
                              // Dynamic filtration rows
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isMobile = constraints.maxWidth < 600;
                                  final breedDropdown = DropdownButtonFormField<String>(
                                    initialValue: _selectedBreed,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Breed',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    items: _availableBreeds.map((b) {
                                      return DropdownMenuItem(value: b, child: Text(b));
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedBreed = val ?? 'All'),
                                  );

                                  final sexDropdown = DropdownButtonFormField<String>(
                                    initialValue: _selectedSex,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Sex',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    items: ['All', 'Doe', 'Buck', 'Wether', 'Unknown'].map((s) {
                                      return DropdownMenuItem(value: s, child: Text(s));
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedSex = val ?? 'All'),
                                  );

                                  if (isMobile) {
                                    return Column(
                                      children: [
                                        breedDropdown,
                                        const SizedBox(height: 8),
                                        sexDropdown,
                                      ],
                                    );
                                  } else {
                                    return Row(
                                      children: [
                                        Expanded(child: breedDropdown),
                                        const SizedBox(width: 8),
                                        Expanded(child: sexDropdown),
                                      ],
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isMobile = constraints.maxWidth < 600;
                                  final bornAfterBtn = OutlinedButton(
                                    onPressed: () => _selectDobStart(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: Text(
                                      _dobStart == null ? 'Born After' : 'Born > ${DateFormat('MM/yy').format(_dobStart!)}',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );

                                  final bornBeforeBtn = OutlinedButton(
                                    onPressed: () => _selectDobEnd(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: Text(
                                      _dobEnd == null ? 'Born Before' : 'Born < ${DateFormat('MM/yy').format(_dobEnd!)}',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );

                                  final loadListBtn = ElevatedButton(
                                    onPressed: () => _loadAnimals(allActiveAnimals),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    child: const Text('Load List'),
                                  );

                                  if (isMobile) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: bornAfterBtn),
                                            const SizedBox(width: 8),
                                            Expanded(child: bornBeforeBtn),
                                            if (_dobStart != null || _dobEnd != null) ...[
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () => setState(() {
                                                  _dobStart = null;
                                                  _dobEnd = null;
                                                }),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: loadListBtn,
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Row(
                                      children: [
                                        Expanded(child: bornAfterBtn),
                                        const SizedBox(width: 8),
                                        Expanded(child: bornBeforeBtn),
                                        if (_dobStart != null || _dobEnd != null) ...[
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () => setState(() {
                                              _dobStart = null;
                                              _dobEnd = null;
                                            }),
                                          ),
                                        ],
                                        const SizedBox(width: 8),
                                        loadListBtn,
                                      ],
                                    );
                                  }
                                },
                              ),
                            ],

                            if (_batchMode == BatchMode.addAnimals) ...[
                              const Text(
                                'Shared Add Configuration & Presets:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isMobile = constraints.maxWidth < 600;
                                  final countDropdown = DropdownButtonFormField<int>(
                                    initialValue: _addCount,
                                    decoration: const InputDecoration(
                                      labelText: 'Number of Animals to Add',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    items: List.generate(50, (index) => index + 1).map((qty) {
                                      return DropdownMenuItem(value: qty, child: Text('$qty'));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _addCount = val);
                                      }
                                    },
                                  );

                                   const breedsList = [
                                     'Kiko',
                                     'Boer',
                                     'Spanish',
                                     'Myotonic (Fainting)',
                                     'Nubian',
                                     'Alpine',
                                     'LaMancha',
                                     'Saanen',
                                     'Toggenburg',
                                     'Oberhasli',
                                     'Pygmy',
                                     'Nigerian Dwarf',
                                     'Angora',
                                     'Savanna',
                                     'Texmaster',
                                     'Other'
                                   ];

                                   final breedDropdown = DropdownButtonFormField<String>(
                                     initialValue: breedsList.contains(_sharedAddBreed) ? _sharedAddBreed : 'Kiko',
                                     decoration: const InputDecoration(
                                       labelText: 'Default Breed',
                                       border: OutlineInputBorder(),
                                       contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                     ),
                                     items: breedsList.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                                     onChanged: (val) {
                                       if (val != null) {
                                         setState(() {
                                           _sharedAddBreed = val;
                                           final books = _getHerdBooksForBreed(val);
                                           _sharedAddHerdBook = books.isNotEmpty ? books.first : null;
                                           _syncSharedAddDetailsToRows();
                                         });
                                       }
                                     },
                                   );

                                   final herdBookDropdown = DropdownButtonFormField<String>(
                                     initialValue: _getHerdBooksForBreed(_sharedAddBreed).contains(_sharedAddHerdBook)
                                         ? _sharedAddHerdBook
                                         : (_getHerdBooksForBreed(_sharedAddBreed).isNotEmpty
                                             ? _getHerdBooksForBreed(_sharedAddBreed).first
                                             : null),
                                     decoration: const InputDecoration(
                                       labelText: 'Default Herd Book',
                                       border: OutlineInputBorder(),
                                       contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                     ),
                                     items: _getHerdBooksForBreed(_sharedAddBreed)
                                         .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                         .toList(),
                                     onChanged: (val) {
                                       setState(() {
                                         _sharedAddHerdBook = val;
                                         _syncSharedAddDetailsToRows();
                                       });
                                     },
                                   );

                                   final sexDropdown = DropdownButtonFormField<Sex>(
                                     initialValue: _sharedAddSex,
                                     decoration: const InputDecoration(
                                       labelText: 'Default Sex',
                                       border: OutlineInputBorder(),
                                       contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                     ),
                                     items: Sex.values.map((s) {
                                       return DropdownMenuItem(
                                         value: s,
                                         child: Text(s.name.toUpperCase()),
                                       );
                                     }).toList(),
                                     onChanged: (val) {
                                       if (val != null) {
                                         setState(() {
                                           _sharedAddSex = val;
                                           _syncSharedAddDetailsToRows();
                                         });
                                       }
                                     },
                                   );

                                   final widgets = [countDropdown, breedDropdown, herdBookDropdown, sexDropdown];

                                  if (isMobile) {
                                    return Column(
                                      children: widgets.map((w) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: w,
                                      )).toList(),
                                    );
                                  } else {
                                    return Row(
                                      children: widgets.map((w) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: w,
                                        ),
                                      )).toList(),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isMobile = constraints.maxWidth < 600;

                                  final priceField = TextField(
                                    controller: _sharedAddPurchasePriceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Shared Acquired Price \$ (Optional)',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (_) => _syncSharedAddDetailsToRows(),
                                  );

                                  final sellerField = TextField(
                                    controller: _sharedAddPurchaseFromController,
                                    decoration: const InputDecoration(
                                      labelText: 'Shared Acquired From (Optional)',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (_) => _syncSharedAddDetailsToRows(),
                                  );

                                  final weightField = TextField(
                                    controller: _sharedAddInitialWeightController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Shared Initial Weight lbs (Optional)',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (_) => _syncSharedAddDetailsToRows(),
                                  );

                                  final dateButton = OutlinedButton.icon(
                                    onPressed: () => _selectSharedPurchaseDate(context),
                                    icon: const Icon(Icons.calendar_today, size: 16),
                                    label: Text(
                                      _sharedAddPurchaseDate == null
                                          ? 'Acquisition Date (Optional)'
                                          : 'Acquired: ${DateFormat.yMMMd().format(_sharedAddPurchaseDate!)}',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  );

                                  final widgets = [priceField, sellerField, weightField, dateButton];

                                  if (isMobile) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: widgets.map((w) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: w,
                                      )).toList(),
                                    );
                                  } else {
                                    return Row(
                                      children: widgets.map((w) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: w,
                                        ),
                                      )).toList(),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _prepareAddList,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text('Prepare Add List', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ],
                    ],
                  ),
                ),
              ),
            ),

              // ─── Spreadsheet Table Grid ───────────────────────────────────────────
              if (!_loaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'Configure the batch settings and click "Load List" above to start.',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else if (_rowStates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'No active animals matched the selected filters.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Text(
                        'Animals Herd (${_rowStates.length}): Enter data in columns below. Blank values will be skipped.',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.all(12),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          columnSpacing: 16,
                          columns: [
                            if (_batchMode == BatchMode.addAnimals) ...[
                              const DataColumn(label: Text('Animal Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Ear Tag', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Tattoo', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Sex', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('DOB', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Breed', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Herd Book', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Color', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Sire', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Dam', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Acquired From', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Purchase Price', style: TextStyle(fontWeight: FontWeight.bold))),
                              const DataColumn(label: Text('Initial Weight', style: TextStyle(fontWeight: FontWeight.bold))),
                            ] else ...[
                              const DataColumn(
                                label: Text('Animal Name / Tag', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (_recordWeight) ...[
                                const DataColumn(
                                  label: Text('Weight (lbs)', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const DataColumn(
                                  label: Text('Weight Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                              if (_recordHealth) ...[
                                const DataColumn(
                                  label: Text('FAMACHA', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const DataColumn(
                                  label: Text('BCS', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const DataColumn(
                                  label: Text('Action Taken', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                if (showDiagnosticCols) ...[
                                  const DataColumn(
                                    label: Text('Test Results', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  const DataColumn(
                                    label: Text('Treat Decision', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                                if (showTreatmentCols) ...[
                                  const DataColumn(
                                    label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  const DataColumn(
                                    label: Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                                const DataColumn(
                                  label: Text('Health Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                              if (_recordKidding) ...[
                                const DataColumn(
                                  label: Text('Kidding Action', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const DataColumn(
                                  label: Text('Kids Registered', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                              if (_recordRemoval) ...[
                                const DataColumn(
                                  label: Text('New Status', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                if (showRemovalCols) ...[
                                  const DataColumn(
                                    label: Text('Buyer / Location', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  const DataColumn(
                                    label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  const DataColumn(
                                    label: Text('Deceased Reason', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ],
                          ],
                          rows: _rowStates.map((row) {
                            if (_batchMode == BatchMode.addAnimals) {
                              final activeDoes = allActiveAnimals.where((a) => a.sex == Sex.doe).toList();
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: TextField(
                                        controller: row.nameController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: 'e.g. Daisy',
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(8),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: row.earTagController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: 'Tag #',
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(8),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: row.tattooController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: 'Tattoo',
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(8),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    DropdownButton<Sex>(
                                      value: row.sex,
                                      style: const TextStyle(fontSize: 13, color: Colors.black),
                                      items: Sex.values.map((s) {
                                        return DropdownMenuItem(
                                          value: s,
                                          child: Text(s.name.toUpperCase()),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => row.sex = val);
                                        }
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    OutlinedButton(
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: row.dob ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime.now().add(const Duration(days: 365)),
                                        );
                                        if (picked != null) {
                                          setState(() => row.dob = picked);
                                        }
                                      },
                                      child: Text(
                                        row.dob == null ? 'Set Date' : DateFormat('MM/dd/yy').format(row.dob!),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: DropdownButton<String>(
                                        value: const [
                                          'Kiko',
                                          'Boer',
                                          'Spanish',
                                          'Myotonic (Fainting)',
                                          'Nubian',
                                          'Alpine',
                                          'LaMancha',
                                          'Saanen',
                                          'Toggenburg',
                                          'Oberhasli',
                                          'Pygmy',
                                          'Nigerian Dwarf',
                                          'Angora',
                                          'Savanna',
                                          'Texmaster',
                                          'Other'
                                        ].contains(row.breedController.text) ? row.breedController.text : 'Kiko',
                                        isExpanded: true,
                                        underline: const SizedBox(),
                                        style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color),
                                        items: const [
                                          'Kiko',
                                          'Boer',
                                          'Spanish',
                                          'Myotonic (Fainting)',
                                          'Nubian',
                                          'Alpine',
                                          'LaMancha',
                                          'Saanen',
                                          'Toggenburg',
                                          'Oberhasli',
                                          'Pygmy',
                                          'Nigerian Dwarf',
                                          'Angora',
                                          'Savanna',
                                          'Texmaster',
                                          'Other'
                                        ].map((b) {
                                          return DropdownMenuItem(
                                            value: b,
                                            child: Text(b, style: const TextStyle(fontSize: 12)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              row.breedController.text = val;
                                              final books = _getHerdBooksForBreed(val);
                                              row.herdBook = books.isNotEmpty ? books.first : null;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: DropdownButton<String>(
                                        value: _getHerdBooksForBreed(row.breedController.text).contains(row.herdBook)
                                            ? row.herdBook
                                            : (_getHerdBooksForBreed(row.breedController.text).isNotEmpty
                                                ? _getHerdBooksForBreed(row.breedController.text).first
                                                : null),
                                        isExpanded: true,
                                        underline: const SizedBox(),
                                        style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color),
                                        items: _getHerdBooksForBreed(row.breedController.text).map((hb) {
                                          return DropdownMenuItem(
                                            value: hb,
                                            child: Text(hb, style: const TextStyle(fontSize: 12)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            row.herdBook = val;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: row.colorController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: 'Color',
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(8),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    DropdownButton<int?>(
                                      value: row.rowSireId,
                                      items: [
                                        const DropdownMenuItem<int?>(value: null, child: Text('Unknown Buck')),
                                        ..._activeBucks.map((buck) {
                                          return DropdownMenuItem(
                                            value: buck.id,
                                            child: Text(buck.name),
                                          );
                                        }),
                                      ],
                                      onChanged: (val) => setState(() => row.rowSireId = val),
                                    ),
                                  ),
                                  DataCell(
                                    DropdownButton<int?>(
                                      value: row.rowDamId,
                                      items: [
                                        const DropdownMenuItem<int?>(value: null, child: Text('Unknown Doe')),
                                        ...activeDoes.map((doe) {
                                          return DropdownMenuItem(
                                            value: doe.id,
                                            child: Text(doe.name),
                                          );
                                        }),
                                      ],
                                      onChanged: (val) => setState(() => row.rowDamId = val),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: TextField(
                                        controller: row.purchaseFromController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: 'Seller / Breeder',
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(8),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: row.purchasePriceController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: '\$',
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(8),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: row.weightController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: 'lbs',
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(8),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            final isDoe = row.animal.sex == Sex.doe;
                            final actions = _getAvailableActions(_sharedHealthType);
                            final showRowDiag = row.actionTaken == 'Fecal Egg Count (FEC) Test' || row.actionTaken == 'Perform Diagnostic Test';
                            final showRowTreat = row.actionTaken == 'Deworm immediately' || row.actionTaken == 'Administer Treatment' || row.treatmentDecision != null;
                            final showRowRemovalOverride = row.removalStatus != AnimalStatus.active;
                            
                            return DataRow(
                              cells: [
                                // Animal Details
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        row.animal.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        '${row.animal.earTag ?? row.animal.tattoo ?? "No Tag"} • ${row.animal.breed} • ${row.animal.sex.name}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                // Weight Inputs
                                if (_recordWeight) ...[
                                  DataCell(
                                    SizedBox(
                                      width: 80,
                                      child: TextField(
                                        controller: row.weightController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: 'lbs',
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(8),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: TextField(
                                        controller: row.weightNotesController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: 'Notes',
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(8),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                // Health Inputs
                                if (_recordHealth) ...[
                                  // FAMACHA (1-5)
                                  DataCell(
                                    DropdownButton<int?>(
                                      value: row.famachaScore,
                                      items: [null, 1, 2, 3, 4, 5].map((val) {
                                        return DropdownMenuItem(
                                          value: val,
                                          child: Text(val == null ? '-' : '$val'),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => row.famachaScore = val),
                                    ),
                                  ),
                                  // BCS (1.0-5.0)
                                  DataCell(
                                    DropdownButton<double?>(
                                      value: row.bcsScore,
                                      items: [null, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0].map((val) {
                                        return DropdownMenuItem(
                                          value: val,
                                          child: Text(val == null ? '-' : val.toStringAsFixed(1)),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => row.bcsScore = val),
                                    ),
                                  ),
                                  // Action Taken Dropdown
                                  DataCell(
                                    DropdownButton<String?>(
                                      value: row.actionTaken,
                                      items: [
                                        const DropdownMenuItem(value: null, child: Text('- Select Action -')),
                                        ...actions.map((act) => DropdownMenuItem(value: act, child: Text(act))),
                                      ],
                                      onChanged: (val) {
                                        setState(() {
                                          row.actionTaken = val;
                                          if (val == 'Deworm immediately') {
                                            row.treatmentDecision = HealthRecordType.deworming;
                                          } else if (val == 'Administer Treatment') {
                                            row.treatmentDecision = HealthConstants.categoryProducts.containsKey(_sharedHealthType) 
                                                ? _sharedHealthType : null;
                                          } else {
                                            row.treatmentDecision = null;
                                          }
                                          row.selectedProduct = null;
                                          row.dosageController.clear();
                                          row.testResultController.clear();
                                        });
                                      },
                                    ),
                                  ),
                                  // Test Results column (visible if showDiagnosticCols)
                                  if (showDiagnosticCols) ...[
                                    DataCell(
                                      showRowDiag
                                          ? SizedBox(
                                              width: 120,
                                              child: TextField(
                                                controller: row.testResultController,
                                                style: const TextStyle(fontSize: 13),
                                                decoration: const InputDecoration(
                                                  hintText: 'EPG / Findings',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.all(8),
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                            )
                                          : const Text('-', style: TextStyle(color: Colors.grey)),
                                    ),
                                    DataCell(
                                      showRowDiag
                                          ? DropdownButton<HealthRecordType?>(
                                              value: row.treatmentDecision,
                                              items: [
                                                const DropdownMenuItem<HealthRecordType?>(
                                                  value: null, 
                                                  child: Text('None / Monitor'),
                                                ),
                                                ...[
                                                  HealthRecordType.deworming,
                                                  HealthRecordType.antibiotic,
                                                  HealthRecordType.vaccination,
                                                  HealthRecordType.supplement,
                                                ].map((t) => DropdownMenuItem<HealthRecordType?>(
                                                  value: t,
                                                  child: Text('Treat: ${t.name.toUpperCase()}'),
                                                )),
                                              ],
                                              onChanged: (val) {
                                                setState(() {
                                                  row.treatmentDecision = val;
                                                  row.selectedProduct = null;
                                                  row.dosageController.clear();
                                                });
                                              },
                                            )
                                          : const Text('-', style: TextStyle(color: Colors.grey)),
                                    ),
                                  ],
                                  // Product & Dosage columns (visible if showTreatmentCols)
                                  if (showTreatmentCols) ...[
                                    DataCell(
                                      showRowTreat && row.treatmentDecision != null
                                          ? DropdownButton<String?>(
                                              value: row.selectedProduct,
                                              items: [
                                                const DropdownMenuItem(value: null, child: Text('- Select -')),
                                                ..._getCategoryProducts(row.treatmentDecision).map((p) {
                                                  return DropdownMenuItem(value: p, child: Text(p));
                                                }),
                                              ],
                                              onChanged: (p) => _onRowProductChanged(row, p),
                                            )
                                          : const Text('-', style: TextStyle(color: Colors.grey)),
                                    ),
                                    DataCell(
                                      showRowTreat && row.treatmentDecision != null
                                          ? SizedBox(
                                              width: 100,
                                              child: TextField(
                                                controller: row.dosageController,
                                                style: const TextStyle(fontSize: 13),
                                                decoration: const InputDecoration(
                                                  hintText: 'Dosage',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.all(8),
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                            )
                                          : const Text('-', style: TextStyle(color: Colors.grey)),
                                    ),
                                  ],
                                  // Health Notes
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: TextField(
                                        controller: row.healthNotesController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: 'Notes',
                                          isDense: true,
                                          contentPadding: EdgeInsets.all(8),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                // Kidding Inputs
                                if (_recordKidding) ...[
                                  DataCell(
                                    isDoe
                                        ? OutlinedButton.icon(
                                            onPressed: () => _showKiddingDialog(row),
                                            icon: const Icon(Icons.child_care, size: 14),
                                            label: Text(
                                              row.kids.isEmpty ? 'Log Kid(s)' : 'Edit Kids (${row.kids.length})',
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                          )
                                        : const Text('-', style: TextStyle(color: Colors.grey)),
                                  ),
                                  DataCell(
                                    isDoe
                                        ? Text(
                                            row.kids.isEmpty
                                                ? 'No kids'
                                                : row.kids.map((k) => '${k.sex.name} (${k.survivalStatus.name})').join(', '),
                                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                                          )
                                        : const Text('N/A', style: TextStyle(color: Colors.grey)),
                                  ),
                                ],
                                // Removal/Status Inputs
                                if (_recordRemoval) ...[
                                  DataCell(
                                    DropdownButton<AnimalStatus>(
                                      value: row.removalStatus,
                                      items: [
                                        AnimalStatus.active,
                                        AnimalStatus.sold,
                                        AnimalStatus.deceased,
                                        AnimalStatus.culled,
                                        AnimalStatus.transferred,
                                      ].map((status) {
                                        return DropdownMenuItem(
                                          value: status,
                                          child: Text(status.name.toUpperCase()),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => row.removalStatus = val);
                                        }
                                      },
                                    ),
                                  ),
                                  if (showRemovalCols) ...[
                                    DataCell(
                                      showRowRemovalOverride && (row.removalStatus == AnimalStatus.sold || row.removalStatus == AnimalStatus.transferred)
                                          ? SizedBox(
                                              width: 120,
                                              child: TextField(
                                                controller: row.soldToController,
                                                style: const TextStyle(fontSize: 13),
                                                decoration: const InputDecoration(
                                                  hintText: 'Buyer',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.all(8),
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                            )
                                          : const Text('-', style: TextStyle(color: Colors.grey)),
                                    ),
                                    DataCell(
                                      showRowRemovalOverride && row.removalStatus == AnimalStatus.sold
                                          ? SizedBox(
                                              width: 80,
                                              child: TextField(
                                                controller: row.soldPriceController,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                style: const TextStyle(fontSize: 13),
                                                decoration: const InputDecoration(
                                                  hintText: '\$',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.all(8),
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                            )
                                          : const Text('-', style: TextStyle(color: Colors.grey)),
                                    ),
                                    DataCell(
                                      showRowRemovalOverride && row.removalStatus == AnimalStatus.deceased
                                          ? SizedBox(
                                              width: 120,
                                              child: TextField(
                                                controller: row.deceasedReasonController,
                                                style: const TextStyle(fontSize: 13),
                                                decoration: const InputDecoration(
                                                  hintText: 'Reason',
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.all(8),
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                            )
                                          : const Text('-', style: TextStyle(color: Colors.grey)),
                                    ),
                                  ],
                                ],
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
        },
      ),
    );
  }
}

class _KiddingDetailsDialog extends StatefulWidget {
  final Animal doe;
  final List<Animal> activeBucks;
  final List<BatchKidState> initialKids;
  final int? initialSireId;
  final int? initialDamConditionScore;
  final String initialComplications;
  final String initialNotes;
  final void Function(
    List<BatchKidState> kids,
    int? sireId,
    int? damConditionScore,
    String complications,
    String notes,
  ) onConfirm;

  const _KiddingDetailsDialog({
    required this.doe,
    required this.activeBucks,
    required this.initialKids,
    required this.initialSireId,
    required this.initialDamConditionScore,
    required this.initialComplications,
    required this.initialNotes,
    required this.onConfirm,
  });

  @override
  State<_KiddingDetailsDialog> createState() => _KiddingDetailsDialogState();
}

class _KiddingDetailsDialogState extends State<_KiddingDetailsDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedSireId;
  int? _damConditionScore;
  final _complicationsController = TextEditingController();
  final _notesController = TextEditingController();

  final List<BatchKidState> _kids = [];
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _tagControllers = [];
  final List<TextEditingController> _tattooControllers = [];
  final List<TextEditingController> _weightControllers = [];

  @override
  void initState() {
    super.initState();
    _selectedSireId = widget.initialSireId;
    _damConditionScore = widget.initialDamConditionScore;
    _complicationsController.text = widget.initialComplications;
    _notesController.text = widget.initialNotes;

    if (widget.initialKids.isEmpty) {
      _addKidRow();
    } else {
      for (var kid in widget.initialKids) {
        _addKidRow(kid);
      }
    }
  }

  @override
  void dispose() {
    _complicationsController.dispose();
    _notesController.dispose();
    for (var c in _nameControllers) {
      c.dispose();
    }
    for (var c in _tagControllers) {
      c.dispose();
    }
    for (var c in _tattooControllers) {
      c.dispose();
    }
    for (var c in _weightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addKidRow([BatchKidState? state]) {
    final newState = state ?? BatchKidState();
    _kids.add(newState);
    
    _nameControllers.add(TextEditingController(text: newState.name));
    _tagControllers.add(TextEditingController(text: newState.earTag));
    _tattooControllers.add(TextEditingController(text: newState.tattoo));
    _weightControllers.add(TextEditingController(
      text: newState.weightLbs != null ? newState.weightLbs.toString() : '',
    ));
    setState(() {});
  }

  void _removeKidRow(int index) {
    if (_kids.length > 1) {
      _kids.removeAt(index);
      _nameControllers.removeAt(index).dispose();
      _tagControllers.removeAt(index).dispose();
      _tattooControllers.removeAt(index).dispose();
      _weightControllers.removeAt(index).dispose();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Log Kids for ${widget.doe.name}'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _selectedSireId,
                      decoration: const InputDecoration(
                        labelText: 'Sire (Buck)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Unknown Buck')),
                        ...widget.activeBucks.map((buck) {
                          return DropdownMenuItem(
                            value: buck.id,
                            child: Text(buck.name),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedSireId = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _damConditionScore,
                      decoration: const InputDecoration(
                        labelText: 'Dam BCS',
                        border: OutlineInputBorder(),
                      ),
                      items: [null, 1, 2, 3, 4, 5].map((val) {
                        return DropdownMenuItem(
                          value: val,
                          child: Text(val == null ? '-' : '$val'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _damConditionScore = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _complicationsController,
                decoration: const InputDecoration(
                  labelText: 'Complications / Delivery Notes',
                  border: OutlineInputBorder(),
                ),
              ),

              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kids Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () => _addKidRow(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Kid'),
                  ),
                ],
              ),

              ...List.generate(_kids.length, (index) {
                final kid = _kids[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Kid #${index + 1}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            ),
                            if (_kids.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _removeKidRow(index),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _nameControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'Name (Optional)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<KidSex>(
                                initialValue: kid.sex,
                                decoration: const InputDecoration(
                                  labelText: 'Sex',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: KidSex.values.map((s) {
                                  return DropdownMenuItem(value: s, child: Text(s.name));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      kid.sex = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: _weightControllers[index],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Birth Wt',
                                  suffixText: 'lbs',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _tagControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'Tag (Optional)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _tattooControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'Tattoo (Optional)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<SurvivalStatus>(
                                initialValue: kid.survivalStatus,
                                decoration: const InputDecoration(
                                  labelText: 'Survival Status',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: SurvivalStatus.values.map((s) {
                                  String label = s.name;
                                  if (s == SurvivalStatus.diedAtBirth) label = 'Died at birth';
                                  if (s == SurvivalStatus.diedWithin24h) label = 'Died in 24h';
                                  if (s == SurvivalStatus.diedWithinWeek) label = 'Died in 1 wk';
                                  if (s == SurvivalStatus.diedLater) label = 'Died later';
                                  return DropdownMenuItem(value: s, child: Text(label));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      kid.survivalStatus = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<Presentation>(
                                initialValue: kid.presentation,
                                decoration: const InputDecoration(
                                  labelText: 'Presentation',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: Presentation.values.map((p) {
                                  return DropdownMenuItem(value: p, child: Text(p.name));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      kid.presentation = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Checkbox(
                              value: kid.receivedColostrum,
                              onChanged: (val) {
                                setState(() {
                                  kid.receivedColostrum = val ?? true;
                                });
                              },
                            ),
                            const Text('Colostrum', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 8),
                            Checkbox(
                              value: kid.bottleFed,
                              onChanged: (val) {
                                setState(() {
                                  kid.bottleFed = val ?? false;
                                });
                              },
                            ),
                            const Text('Bottle Fed', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const Divider(height: 24),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'General Notes',
                  border: OutlineInputBorder(),
                ),
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              for (int i = 0; i < _kids.length; i++) {
                _kids[i].name = _nameControllers[i].text.trim();
                _kids[i].earTag = _tagControllers[i].text.trim();
                _kids[i].tattoo = _tattooControllers[i].text.trim();
                _kids[i].weightLbs = double.tryParse(_weightControllers[i].text.trim());
              }
              widget.onConfirm(
                _kids,
                _selectedSireId,
                _damConditionScore,
                _complicationsController.text.trim(),
                _notesController.text.trim(),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
