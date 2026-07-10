import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../data/models/animal_model.dart';
import '../../../data/models/kidding_record_model.dart';
import '../../../data/models/breeding_event_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../breeding/providers/breeding_providers.dart';
import '../../finances/providers/financial_providers.dart';

class AddEditAnimalScreen extends ConsumerStatefulWidget {
  final Animal? animal;
  final String? initialRfidTag;

  const AddEditAnimalScreen({super.key, this.animal, this.initialRfidTag});

  @override
  ConsumerState<AddEditAnimalScreen> createState() =>
      _AddEditAnimalScreenState();
}

class _AddEditAnimalScreenState
    extends ConsumerState<AddEditAnimalScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _barnNameController = TextEditingController();
  final _earTagController = TextEditingController();
  final _tagController = TextEditingController();
  final _regController = TextEditingController();
  final _secondRegController = TextEditingController();
  final _eidController = TextEditingController();
  final _vglController = TextEditingController();
  final _scrapieController = TextEditingController();
  final _markingsController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Pedigree controllers
  final _sireNameController = TextEditingController();
  final _sireRegController = TextEditingController();
  final _damNameController = TextEditingController();
  final _damRegController = TextEditingController();

  Sex _selectedSex = Sex.doe;
  DateTime? _selectedDob;
  String? _photoPath;

  AnimalStatus _selectedStatus = AnimalStatus.active;
  DateTime? _selectedSoldDate;
  DateTime? _selectedDeceasedDate;
  final _soldPriceController = TextEditingController();
  final _soldToController = TextEditingController();
  final _deceasedReasonController = TextEditingController();

  int? _sireId;
  int? _damId;



  // Dropdown selections
  String? _selectedRegistry;
  bool _isDualRegistry = false;
  String? _selectedSecondRegistry;
  String? _selectedBreed = 'Kiko';
  String? _selectedHerdBook;
  String? _selectedEidType;
  String? _selectedEidPlacement;
  String? _selectedEarType;
  String? _selectedHornType;
  String? _selectedOwnership;
  String? _selectedEyeColor;

  static const _breeds = [
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

  List<String> _getRegistriesForBreed(String? breed) {
    switch (breed) {
      case 'Kiko':
        return ['NKR', 'AKGA', 'IKGA', 'Other'];
      case 'Boer':
        return ['ABGA', 'USBGA', 'Other'];
      case 'Spanish':
        return ['SGA', 'SBGA', 'Other'];
      case 'Myotonic (Fainting)':
        return ['MGR', 'Other'];
      case 'Nubian':
      case 'Alpine':
      case 'LaMancha':
      case 'Saanen':
      case 'Toggenburg':
      case 'Oberhasli':
      case 'Nigerian Dwarf':
        return ['ADGA', 'AGS', 'Other'];
      case 'Pygmy':
        return ['NPGA', 'Other'];
      case 'Angora':
        return ['AAGBA', 'CAGBA', 'Other'];
      case 'Savanna':
        return ['ABGA', 'Other'];
      case 'Texmaster':
        return ['MGR', 'Other'];
      default:
        return ['NKR', 'AKGA', 'IKGA', 'ABGA', 'ADGA', 'MGR', 'Other'];
    }
  }

  List<String> _getHerdBooksForBreed(String? breed) {
    switch (breed) {
      case 'Kiko':
        return ['100% New Zealand', 'Percentage', 'Purebred', 'Commercial'];
      case 'Boer':
        return ['Fullblood', 'Purebred', 'Percentage', 'Commercial'];
      case 'Spanish':
        return ['Purebred Spanish', 'Crossbred'];
      case 'Myotonic (Fainting)':
        return ['Purebred Myotonic', 'Percentage', 'Commercial'];
      case 'Nubian':
      case 'Alpine':
      case 'LaMancha':
      case 'Saanen':
      case 'Toggenburg':
      case 'Oberhasli':
      case 'Nigerian Dwarf':
        return ['Purebred', 'Recorded Grade', 'Experimental'];
      case 'Pygmy':
        return ['Registered Pygmy', 'Unregistered/Grade'];
      case 'Angora':
        return ['Purebred Angora', 'Grade'];
      case 'Savanna':
        return ['Fullblood Savanna', 'Purebred', 'Percentage'];
      case 'Texmaster':
        return ['Registered Texmaster', 'Commercial'];
      default:
        return ['Purebred', 'Crossbred', 'Grade', 'Other'];
    }
  }

  static const _eidTypes = ['Microchip', 'RFID Ear Tag', 'Bolus', 'Other'];
  static const _eidPlacements = ['Tail', 'Left Ear', 'Right Ear', 'Left Shoulder', 'Right Shoulder', 'Other'];
  static const _eyeColors = [
    'Amber/Yellow-Gold',
    'Blue',
    'Brown',
    'Light Brown',
    'Light Blue',
    'Marbled Amber',
    'Marbled Blue',
    'Marbled Brown'
  ];
  static const _earTypes = ['Erect', 'Pendulous', 'Airplane', 'Gopher', 'Elf'];
  static const _hornTypes = ['Horned', 'Polled', 'Disbudded', 'Scurred'];
  static const _ownershipStatuses = ['Owned', 'Leased', 'Co-owned', 'Other'];

  /// Helper to ensure the loaded value exists in the allowed items list.
  /// Returns null if the value is invalid or empty to avoid Dropdown assertion failures.
  String? _validateValue(String? value, List<String> allowedItems) {
    if (value == null || value.isEmpty) return null;
    if (allowedItems.contains(value)) return value;
    return null; // Fallback to null if data doesn't match dropdown options
  }

  List<AnimalStatus> get _allowedStatuses {
    final list = [AnimalStatus.active, AnimalStatus.sold, AnimalStatus.deceased];
    if (widget.animal != null && !list.contains(widget.animal!.status)) {
      list.add(widget.animal!.status);
    }
    return list;
  }

  String _statusName(AnimalStatus status) {
    switch (status) {
      case AnimalStatus.active:
        return 'Active';
      case AnimalStatus.sold:
        return 'Sold';
      case AnimalStatus.deceased:
        return 'Deceased';
      case AnimalStatus.ancestor:
        return 'Ancestor';
      case AnimalStatus.culled:
        return 'Culled';
      case AnimalStatus.transferred:
        return 'Transferred';
    }
  }

  @override
  void initState() {
    super.initState();


    if (widget.animal != null) {
      final a = widget.animal!;
      _nameController.text = a.name;
      _barnNameController.text = a.barnName ?? '';
      _earTagController.text = a.earTag ?? '';
      _tagController.text = a.tattoo ?? '';
      _regController.text = a.nkrRegNumber ?? '';
      _secondRegController.text = a.secondRegNumber ?? '';
      _selectedSex = a.sex;
      _selectedDob = a.dob;
      _photoPath = a.photoPath;
      _eidController.text = a.rfidTag ?? '';
      _vglController.text = a.vglId ?? '';
      _scrapieController.text = a.scrapieTag ?? '';
      _markingsController.text = a.markings ?? '';
      _descriptionController.text = a.description ?? '';
      
      _selectedStatus = a.status;
      _selectedSoldDate = a.soldDate;
      _selectedDeceasedDate = a.deceasedDate;
      _soldPriceController.text = a.soldPrice != null ? a.soldPrice.toString() : '';
      _soldToController.text = a.soldTo ?? '';
      _deceasedReasonController.text = a.deceasedReason ?? '';
      
      // Load Pedigree fields
      _sireNameController.text = a.sireName ?? '';
      _sireRegController.text = a.sireRegNumber ?? '';
      _damNameController.text = a.damName ?? '';
      _damRegController.text = a.damRegNumber ?? '';
      _sireId = a.sireId;
      _damId = a.damId;


      // Validate dropdown values against allowed lists
      _selectedEyeColor = _validateValue(a.eyeColor, _eyeColors);
      _selectedBreed = _validateValue(a.breed, _breeds) ?? 'Kiko';
      _selectedRegistry = _validateValue(a.registry, _getRegistriesForBreed(_selectedBreed));
      _selectedSecondRegistry = _validateValue(a.secondRegistry, _getRegistriesForBreed(_selectedBreed));
      _isDualRegistry = a.secondRegNumber != null && a.secondRegNumber!.isNotEmpty || a.secondRegistry != null;
      _selectedHerdBook = _validateValue(a.herdBook ?? a.breedType, _getHerdBooksForBreed(_selectedBreed));
      _selectedEidType = _validateValue(a.eidType, _eidTypes);
      _selectedEidPlacement = _validateValue(a.eidPlacement, _eidPlacements);
      _selectedEarType = _validateValue(a.earType, _earTypes);
      _selectedHornType = _validateValue(a.hornType, _hornTypes);
      _selectedOwnership = _validateValue(a.ownershipStatus, _ownershipStatuses);
    } else if (widget.initialRfidTag != null) {
      _eidController.text = widget.initialRfidTag!;
    }
  }





  @override
  void dispose() {

    _nameController.dispose();
    _barnNameController.dispose();
    _earTagController.dispose();
    _tagController.dispose();
    _regController.dispose();
    _secondRegController.dispose();
    _eidController.dispose();
    _vglController.dispose();
    _scrapieController.dispose();
    _markingsController.dispose();
    _descriptionController.dispose();

    _soldPriceController.dispose();
    _soldToController.dispose();
    _deceasedReasonController.dispose();
    
    // Dispose pedigree controllers
    _sireNameController.dispose();
    _sireRegController.dispose();
    _damNameController.dispose();
    _damRegController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDob) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      // Copy the photo from the temporary cache to a permanent app directory
      // so it persists across restarts and can be uploaded during sync.
      final docDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(docDir.path, 'flockkeeper_media', 'photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final ext = p.extension(pickedFile.path);
      final permanentPath = p.join(photosDir.path, 'animal_${DateTime.now().millisecondsSinceEpoch}$ext');
      await File(pickedFile.path).copy(permanentPath);

      setState(() {
        _photoPath = permanentPath;
      });
    }
  }

  void _showImagePickerOptions() async {
    if (Platform.isWindows) {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.single.path != null) {
          setState(() {
            _photoPath = result.files.single.path;
          });
        }
      } catch (e) {
        debugPrint('Error picking profile image on Windows: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error picking image: $e')),
          );
        }
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _lookupSire() async {
    final reg = _sireRegController.text.trim();
    final name = _sireNameController.text.trim();
    if (reg.isEmpty && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Sire Registration # or Name to search.')),
      );
      return;
    }

    final repo = ref.read(animalRepositoryProvider);
    Animal? match;
    if (reg.isNotEmpty) {
      match = await repo.getAnimalByNkrRegNumberCaseInsensitive(reg);
    }
    if (match == null && name.isNotEmpty) {
      match = await repo.getAnimalByNameCaseInsensitive(name);
    }

    if (!mounted) return;

    if (match != null) {
      setState(() {
        _sireId = match!.id;
        _sireNameController.text = match.name;
        _sireRegController.text = match.nkrRegNumber ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found existing Sire: ${match.name}. Details auto-populated!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matching animal found. Details will be saved as a new ancestor.')),
      );
    }
  }

  Future<void> _lookupDam() async {
    final reg = _damRegController.text.trim();
    final name = _damNameController.text.trim();
    if (reg.isEmpty && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Dam Registration # or Name to search.')),
      );
      return;
    }

    final repo = ref.read(animalRepositoryProvider);
    Animal? match;
    if (reg.isNotEmpty) {
      match = await repo.getAnimalByNkrRegNumberCaseInsensitive(reg);
    }
    if (match == null && name.isNotEmpty) {
      match = await repo.getAnimalByNameCaseInsensitive(name);
    }

    if (!mounted) return;

    if (match != null) {
      setState(() {
        _damId = match!.id;
        _damNameController.text = match.name;
        _damRegController.text = match.nkrRegNumber ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found existing Dam: ${match.name}. Details auto-populated!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matching animal found. Details will be saved as a new ancestor.')),
      );
    }
  }

  Future<void> _showAnimalSearchDialog({
    required Sex sexFilter,
    required Function(Animal) onSelect,
  }) async {
    final repo = ref.read(animalRepositoryProvider);
    final allAnimals = await repo.getAllAnimals(orderBy: 'name ASC');
    // Filter by sex. Keep active, sold, culled, ancestor etc.
    final filteredAnimals = allAnimals.where((a) => a.sex == sexFilter && a.id != widget.animal?.id).toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final matches = filteredAnimals.where((a) {
              final query = searchQuery.toLowerCase();
              final nameMatch = a.name.toLowerCase().contains(query);
              final barnNameMatch = a.barnName?.toLowerCase().contains(query) ?? false;
              final regMatch = a.nkrRegNumber?.toLowerCase().contains(query) ?? false;
              final tagMatch = a.earTag?.toLowerCase().contains(query) ?? false;
              final tattooMatch = a.tattoo?.toLowerCase().contains(query) ?? false;
              return nameMatch || barnNameMatch || regMatch || tagMatch || tattooMatch;
            }).toList();

            return AlertDialog(
              title: Text('Search ${sexFilter == Sex.buck ? 'Sire (Bucks)' : 'Dam (Does)'}'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search by Name, Reg ID, Tag or Tattoo',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (val) {
                        setStateDialog(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: matches.isEmpty
                          ? const Center(child: Text('No matching animals found.'))
                          : ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final animal = matches[index];
                                final subtext = [
                                  if (animal.nkrRegNumber != null && animal.nkrRegNumber!.isNotEmpty) '${animal.registry ?? 'Reg'}: ${animal.nkrRegNumber}',
                                  if (animal.earTag != null && animal.earTag!.isNotEmpty) 'Tag: ${animal.earTag}',
                                  if (animal.tattoo != null && animal.tattoo!.isNotEmpty) 'Tattoo: ${animal.tattoo}',
                                ].join(' | ');
                                return ListTile(
                                  title: Text(animal.name),
                                  subtitle: Text(subtext.isNotEmpty ? subtext : 'No registration/tags info'),
                                  onTap: () {
                                    onSelect(animal);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }



  void _showDuplicateErrorDialog(String fieldName, String value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Duplicate Animal Detected'),
          ],
        ),
        content: Text(
          'An animal with this $fieldName already exists in your database:\n\n'
          '• Value: "$value"\n\n'
          'Duplicate records are not allowed. Please verify the identifier and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  BirthType _getBirthType(int size) {
    if (size == 1) return BirthType.single;
    if (size == 2) return BirthType.twin;
    if (size == 3) return BirthType.triplet;
    if (size == 4) return BirthType.quad;
    return BirthType.other;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(animalRepositoryProvider);
    final now = DateTime.now();

    final name = _nameController.text.trim();
    final earTag = _earTagController.text.trim().isNotEmpty ? _earTagController.text.trim() : null;
    final tattoo = _tagController.text.trim().isNotEmpty ? _tagController.text.trim() : null;
    final nkrReg = _regController.text.trim().isNotEmpty ? _regController.text.trim() : null;
    final secondReg = _isDualRegistry && _secondRegController.text.trim().isNotEmpty ? _secondRegController.text.trim() : null;
    final secondRegistryVal = _isDualRegistry ? _selectedSecondRegistry : null;
    final rfid = _eidController.text.trim().isNotEmpty ? _eidController.text.trim() : null;
    final scrapie = _scrapieController.text.trim().isNotEmpty ? _scrapieController.text.trim() : null;
    final vgl = _vglController.text.trim().isNotEmpty ? _vglController.text.trim() : null;

    final tempAnimal = Animal(
      name: name,
      earTag: earTag,
      tattoo: tattoo,
      nkrRegNumber: nkrReg,
      secondRegNumber: secondReg,
      secondRegistry: secondRegistryVal,
      rfidTag: rfid,
      scrapieTag: scrapie,
      vglId: vgl,
      dob: _selectedDob,
      sex: _selectedSex,
      createdAt: now,
      updatedAt: now,
    );

    // Perform duplicate check
    final duplicate = await repo.findDuplicateAnimal(tempAnimal, excludeId: widget.animal?.id);
    if (duplicate != null) {
      if (duplicate.nkrRegNumber != null && duplicate.nkrRegNumber!.toLowerCase() == nkrReg?.toLowerCase()) {
        _showDuplicateErrorDialog('NKR Registration Number', nkrReg!);
        return;
      }
      if (duplicate.earTag != null && duplicate.earTag!.toLowerCase() == earTag?.toLowerCase()) {
        _showDuplicateErrorDialog('Ear Tag', earTag!);
        return;
      }
      if (duplicate.tattoo != null && duplicate.tattoo!.toLowerCase() == tattoo?.toLowerCase()) {
        _showDuplicateErrorDialog('Tattoo', tattoo!);
        return;
      }
      if (duplicate.rfidTag != null && duplicate.rfidTag!.toLowerCase() == rfid?.toLowerCase()) {
        _showDuplicateErrorDialog('EID/RFID Tag', rfid!);
        return;
      }

      if (duplicate.vglId != null && duplicate.vglId!.toLowerCase() == vgl?.toLowerCase()) {
        _showDuplicateErrorDialog('UC-Davis VGL#', vgl!);
        return;
      }
      if (duplicate.name.toLowerCase() == name.toLowerCase() &&
          _selectedDob != null &&
          duplicate.dob != null &&
          duplicate.dob!.year == _selectedDob!.year &&
          duplicate.dob!.month == _selectedDob!.month &&
          duplicate.dob!.day == _selectedDob!.day) {
        _showDuplicateErrorDialog('Name and DOB combination', '$name (born ${DateFormat.yMd().format(_selectedDob!)})');
        return;
      }
    }

    int? sireId = _sireId;
    int? damId = _damId;

    final sireName = _sireNameController.text.trim();
    final sireReg = _sireRegController.text.trim();

    if (sireName.isNotEmpty || sireReg.isNotEmpty) {
      if (sireId == null) {
        Animal? existing;
        if (sireReg.isNotEmpty) {
          existing = await repo.getAnimalByNkrRegNumberCaseInsensitive(sireReg);
        }
        if (existing == null && sireName.isNotEmpty) {
          existing = await repo.getAnimalByNameCaseInsensitive(sireName);
        }

        if (existing != null) {
          sireId = existing.id;
        } else {
          final newSire = Animal(
            name: sireName.isNotEmpty ? sireName : 'Sire of $name',
            nkrRegNumber: sireReg.isNotEmpty ? sireReg : null,
            breed: 'Kiko',
            sex: Sex.buck,
            status: AnimalStatus.ancestor,
            createdAt: now,
            updatedAt: now,
          );
          sireId = await repo.insertAnimal(newSire);
        }
      }
    }

    final damName = _damNameController.text.trim();
    final damReg = _damRegController.text.trim();

    if (damName.isNotEmpty || damReg.isNotEmpty) {
      if (damId == null) {
        Animal? existing;
        if (damReg.isNotEmpty) {
          existing = await repo.getAnimalByNkrRegNumberCaseInsensitive(damReg);
        }
        if (existing == null && damName.isNotEmpty) {
          existing = await repo.getAnimalByNameCaseInsensitive(damName);
        }

        if (existing != null) {
          damId = existing.id;
        } else {
          final newDam = Animal(
            name: damName.isNotEmpty ? damName : 'Dam of $name',
            nkrRegNumber: damReg.isNotEmpty ? damReg : null,
            breed: 'Kiko',
            sex: Sex.doe,
            status: AnimalStatus.ancestor,
            createdAt: now,
            updatedAt: now,
          );
          damId = await repo.insertAnimal(newDam);
        }
      }
    }

    // Check if we should auto-create a kidding record (for a goat of any age)
    bool shouldAutoCreateKidding = false;
    final dob = _selectedDob;
    if (widget.animal == null && dob != null && damId != null) {
      final dam = await repo.getAnimalById(damId);
      if (dam != null && dam.status == AnimalStatus.active) {
        shouldAutoCreateKidding = true;
      }
    }

    final animal = Animal(
      id: widget.animal?.id,
      name: name,
      earTag: earTag,
      tattoo: tattoo,
      nkrRegNumber: nkrReg,
      sex: _selectedSex,
      dob: _selectedDob,
      birthWeightLbs: widget.animal?.birthWeightLbs,
      barnName: _barnNameController.text.trim().isNotEmpty ? _barnNameController.text.trim() : null,
      registry: _selectedRegistry,
      secondRegistry: secondRegistryVal,
      secondRegNumber: secondReg,
      breedType: _selectedHerdBook,
      herdBook: _selectedHerdBook,
      rfidTag: rfid,
      eidType: _selectedEidType,
      eidPlacement: _selectedEidPlacement,
      idTagNumber: null,
      idTagPlacement: null,
      scrapieTag: scrapie,
      vglId: vgl,
      eyeColor: _selectedEyeColor,
      earType: _selectedEarType,
      hornType: _selectedHornType,
      markings: _markingsController.text.trim().isNotEmpty ? _markingsController.text.trim() : null,
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      ownershipStatus: _selectedOwnership,
      photoPath: _photoPath,
      sireId: sireId,
      sireName: sireName.isNotEmpty ? sireName : null,
      sireRegNumber: sireReg.isNotEmpty ? sireReg : null,
      damId: damId,
      damName: damName.isNotEmpty ? damName : null,
      damRegNumber: damReg.isNotEmpty ? damReg : null,
      breed: _selectedBreed ?? 'Kiko',
      status: _selectedStatus,
      soldDate: _selectedStatus == AnimalStatus.sold ? _selectedSoldDate : null,
      soldPrice: _selectedStatus == AnimalStatus.sold ? double.tryParse(_soldPriceController.text) : null,
      soldTo: _selectedStatus == AnimalStatus.sold ? _soldToController.text.trim() : null,
      deceasedDate: _selectedStatus == AnimalStatus.deceased ? _selectedDeceasedDate : null,
      deceasedReason: _selectedStatus == AnimalStatus.deceased ? _deceasedReasonController.text.trim() : null,
      createdAt: widget.animal?.createdAt ?? now,
      updatedAt: now,
    );

    int savedId;
    if (widget.animal == null) {
      savedId = await repo.insertAnimal(animal);
    } else {
      savedId = animal.id!;
      await repo.updateAnimal(animal);
    }

    if (shouldAutoCreateKidding) {
      try {
        final kiddingRepo = ref.read(kiddingRepositoryProvider);
        final breedingRepo = ref.read(breedingRepositoryProvider);

        final existingKiddings = await kiddingRepo.getKiddingRecordsForDoe(damId!);
        final sameDayKiddings = existingKiddings.where((k) => 
          k.kiddingDate.year == dob!.year &&
          k.kiddingDate.month == dob.month &&
          k.kiddingDate.day == dob.day
        ).toList();

        int birthOrder = 1;
        int litterSize = 1;
        int? breedingEventId;

        if (sameDayKiddings.isNotEmpty) {
          birthOrder = sameDayKiddings.length + 1;
          litterSize = sameDayKiddings.length + 1;
          breedingEventId = sameDayKiddings.first.breedingEventId;

          // Update existing sibling kidding records
          for (final prevRecord in sameDayKiddings) {
            final updatedPrev = prevRecord.copyWith(
              litterSize: litterSize,
              birthType: _getBirthType(litterSize),
            );
            await kiddingRepo.updateKiddingRecord(updatedPrev);
          }
        } else {
          // Find pending/active breeding event
          final breedingEvents = await breedingRepo.getBreedingEventsForDoe(damId);
          final pendingEvent = breedingEvents.where((e) => e.actualKidDate == null).firstOrNull;
          if (pendingEvent != null) {
            breedingEventId = pendingEvent.id;
            final updatedEvent = pendingEvent.copyWith(
              actualKidDate: dob!,
              outcome: BreedingOutcome.kidded,
              updatedAt: now,
            );
            await breedingRepo.updateBreedingEvent(updatedEvent);
          }
        }

        final kiddingRecord = KiddingRecord(
          breedingEventId: breedingEventId,
          doeId: damId,
          buckId: sireId,
          kidId: savedId,
          kidName: name,
          kiddingDate: dob!,
          birthOrder: birthOrder,
          litterSize: litterSize,
          sex: _selectedSex == Sex.doe ? KidSex.doe : (_selectedSex == Sex.buck ? KidSex.buck : KidSex.unknown),
          birthType: _getBirthType(litterSize),
          survivalStatus: SurvivalStatus.alive,
          createdAt: now,
        );

        await kiddingRepo.insertKiddingRecord(kiddingRecord);

        ref.invalidate(breedingListProvider);
        ref.invalidate(kiddingRecordsListProvider);
        ref.invalidate(breedingStatsProvider);
      } catch (e) {
        debugPrint('Failed to auto-create kidding record: $e');
      }
    }

    // Refresh list
    ref.invalidate(animalsProvider);
    ref.invalidate(activeAnimalsProvider);
    ref.invalidate(searchedAnimalsProvider);
    ref.invalidate(animalByIdProvider(savedId));
    ref.invalidate(financialRecordsProvider);
    ref.invalidate(financialRecordsForAnimalProvider(savedId));

    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteAnimal() async {
    final animal = widget.animal;
    if (animal == null || animal.id == null) {
      if (mounted) {
        Navigator.pop(context); // Close the screen (discarding the unsaved animal)
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Animal'),
        content: Text(
          'Are you sure you want to permanently delete ${animal.name}? '
          'This will also delete all of their weight history, health records, '
          'breeding records, and notes.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(animalRepositoryProvider);
      await repo.deleteAnimal(animal.id!);
      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);
      ref.invalidate(searchedAnimalsProvider);
      ref.invalidate(animalByIdProvider(animal.id!));

      if (mounted) {
        Navigator.pop(context); // Close the Edit screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${animal.name} deleted successfully.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.animal != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Animal' : 'Add Animal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: isEditing ? 'Delete Animal' : 'Discard',
            onPressed: _deleteAnimal,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildSectionHeader('Profile Photo'),
              // --- Photo Picker ---
              Center(
                child: GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: CircleAvatar(
                    radius: 75,
                    backgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
                    backgroundImage: _photoPath != null && File(_photoPath!).existsSync()
                        ? FileImage(File(_photoPath!))
                        : null,
                    child: _photoPath == null || !File(_photoPath!).existsSync()
                        ? const Icon(Icons.add_a_photo, size: 56)
                        : null,
                  ),
                ),
              ),



              const SizedBox(height: 24),
              _buildSectionHeader('Vital Information'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Registered Name *'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _barnNameController,
                decoration: const InputDecoration(labelText: 'Barn / Nickname'),
              ),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedBreed,
                decoration: const InputDecoration(labelText: 'Breed *'),
                items: _breeds
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedBreed = v;
                      final registries = _getRegistriesForBreed(v);
                      if (!registries.contains(_selectedRegistry)) {
                        _selectedRegistry = null;
                      }
                      final herdBooks = _getHerdBooksForBreed(v);
                      if (!herdBooks.contains(_selectedHerdBook)) {
                        _selectedHerdBook = null;
                      }
                    });
                  }
                },
              ),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedHerdBook,
                decoration: const InputDecoration(labelText: 'Herd Book'),
                items: _getHerdBooksForBreed(_selectedBreed)
                    .map((hb) => DropdownMenuItem(value: hb, child: Text(hb)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedHerdBook = v),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _regController,
                      decoration: const InputDecoration(labelText: 'Registration ID #'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedRegistry,
                      decoration: const InputDecoration(labelText: 'Registry'),
                      items: _getRegistriesForBreed(_selectedBreed)
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRegistry = v),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dual Registry?'),
                value: _isDualRegistry,
                onChanged: (value) {
                  setState(() {
                    _isDualRegistry = value;
                    if (!value) {
                      _secondRegController.clear();
                      _selectedSecondRegistry = null;
                    }
                  });
                },
              ),
              if (_isDualRegistry) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _secondRegController,
                        decoration: const InputDecoration(labelText: '2nd Registration ID #'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSecondRegistry,
                        decoration: const InputDecoration(labelText: '2nd Registry'),
                        items: _getRegistriesForBreed(_selectedBreed)
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedSecondRegistry = v),
                      ),
                    ),
                  ],
                ),
              ],

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date of Birth'),
                subtitle: Text(_selectedDob == null
                    ? 'Not set'
                    : DateFormat.yMMMd().format(_selectedDob!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),

              DropdownButtonFormField<Sex>(
                initialValue: _selectedSex,
                decoration: const InputDecoration(labelText: 'Sex'),
                items: Sex.values.map((sex) {
                  return DropdownMenuItem(
                    value: sex,
                    child: Text(sex.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedSex = value);
                  }
                },
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Identifying Information'),
              TextFormField(
                controller: _earTagController,
                decoration: const InputDecoration(labelText: 'Ear Tag'),
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _tagController,
                decoration: const InputDecoration(labelText: 'Tattoo'),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedEidType,
                      decoration: const InputDecoration(labelText: 'Electronic ID Type'),
                      items: _eidTypes
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedEidType = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _eidController,
                      decoration: const InputDecoration(labelText: 'EID Number'),
                    ),
                  ),
                ],
              ),
              if (_selectedEidType != null)
                DropdownButtonFormField<String>(
                  initialValue: _selectedEidPlacement,
                  decoration: const InputDecoration(labelText: 'EID Placement'),
                  items: _eidPlacements
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedEidPlacement = v),
                ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _scrapieController,
                decoration: const InputDecoration(labelText: 'USDA Scrapie Tag #'),
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _vglController,
                decoration: const InputDecoration(
                  labelText: 'UC-Davis VGL#',
                  hintText: 'Optional genetic / DNA reference ID',
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Description'),
              DropdownButtonFormField<String>(
                initialValue: _selectedEyeColor,
                decoration: const InputDecoration(labelText: 'Eye Color'),
                items: _eyeColors.map((color) {
                  return DropdownMenuItem(
                    value: color,
                    child: Text(color),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedEyeColor = v),
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedEarType,
                      decoration: const InputDecoration(labelText: 'Ear Type'),
                      items: _earTypes
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedEarType = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedHornType,
                      decoration: const InputDecoration(labelText: 'Horn Type'),
                      items: _hornTypes
                          .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedHornType = v),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _markingsController,
                decoration: const InputDecoration(labelText: 'Colors and Markings'),
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'General Description'),
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              _buildPedigreeFormFields(),
              _buildSectionHeader('Status & Ownership'),
              DropdownButtonFormField<AnimalStatus>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Goat Status *'),
                items: _allowedStatuses
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(_statusName(status)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedStatus = v);
                  }
                },
              ),
              const SizedBox(height: 12),

              if (_selectedStatus == AnimalStatus.sold) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sold Date'),
                  subtitle: Text(_selectedSoldDate == null
                      ? 'Not set'
                      : DateFormat.yMMMd().format(_selectedSoldDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedSoldDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedSoldDate = picked);
                    }
                  },
                ),
                TextFormField(
                  controller: _soldPriceController,
                  decoration: const InputDecoration(labelText: 'Sold Price (\$)', suffixText: 'USD'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _soldToController,
                  decoration: const InputDecoration(labelText: 'Sold To / Buyer'),
                ),
                const SizedBox(height: 12),
              ],

              if (_selectedStatus == AnimalStatus.deceased) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deceased Date'),
                  subtitle: Text(_selectedDeceasedDate == null
                      ? 'Not set'
                      : DateFormat.yMMMd().format(_selectedDeceasedDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDeceasedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedDeceasedDate = picked);
                    }
                  },
                ),
                TextFormField(
                  controller: _deceasedReasonController,
                  decoration: const InputDecoration(labelText: 'Deceased Reason (e.g. illness, predator)'),
                ),
                const SizedBox(height: 12),
              ],

              DropdownButtonFormField<String>(
                initialValue: _selectedOwnership,
                decoration: const InputDecoration(labelText: 'Ownership Status'),
                items: _ownershipStatuses
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedOwnership = v),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
          ),
        ),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }



  Widget _buildPedigreeFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Pedigree & Ancestry'),
        
        // --- Sire Section ---
        const Text(
          'Sire (Father)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _sireRegController,
                decoration: InputDecoration(
                  labelText: 'Sire Registry # / NKR #',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    tooltip: 'Lookup Sire in Database',
                    onPressed: _lookupSire,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: _sireNameController,
                decoration: InputDecoration(
                  labelText: 'Sire Registered Name',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    tooltip: 'Search Sire list in Database',
                    onPressed: () {
                      _showAnimalSearchDialog(
                        sexFilter: Sex.buck,
                        onSelect: (animal) {
                          setState(() {
                            _sireId = animal.id;
                            _sireNameController.text = animal.name;
                            _sireRegController.text = animal.nkrRegNumber ?? '';
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 24),

        // --- Dam Section ---
        const Text(
          'Dam (Mother)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _damRegController,
                decoration: InputDecoration(
                  labelText: 'Dam Registry # / NKR #',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.pink),
                    tooltip: 'Lookup Dam in Database',
                    onPressed: _lookupDam,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: TextFormField(
                controller: _damNameController,
                decoration: InputDecoration(
                  labelText: 'Dam Registered Name',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.pink),
                    tooltip: 'Search Dam list in Database',
                    onPressed: () {
                      _showAnimalSearchDialog(
                        sexFilter: Sex.doe,
                        onSelect: (animal) {
                          setState(() {
                            _damId = animal.id;
                            _damNameController.text = animal.name;
                            _damRegController.text = animal.nkrRegNumber ?? '';
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}


