// lib/features/export/screens/pdf_preview_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../../../shared/utils/phone_number_formatter.dart';

import '../../../data/models/animal_model.dart';
import '../../../shared/providers/providers.dart';
import '../services/pdf_export_service.dart';

class PdfPreviewScreen extends ConsumerStatefulWidget {
  final Animal animal;

  const PdfPreviewScreen({super.key, required this.animal});

  @override
  ConsumerState<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends ConsumerState<PdfPreviewScreen> {
  bool _includeBillOfSale = false;
  bool _registeredInOtherRegistry = false;
  bool _hairSampleAttached = true;
  String _birthType = 'Single';
  String _selectedDoc = 'Certificate';
  bool _includeGoatPhoto = false;
  bool _useExistingPhoto = true;
  String? _customPhotoPath;

  Future<void> _pickCustomPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _customPhotoPath = pickedFile.path;
        _useExistingPhoto = false;
      });
    }
  }

  final _buyerNameController = TextEditingController();
  final _buyerAddressController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _buyerEmailController = TextEditingController();
  final _buyerClientIdController = TextEditingController();
  final _buyerPrefixController = TextEditingController();
  final _priceController = TextEditingController();

  final _sellerNameController = TextEditingController();
  final _sellerPhoneController = TextEditingController();
  final _sellerEmailController = TextEditingController();
  final _sellerAddressController = TextEditingController();
  final _sellerClientIdController = TextEditingController();
  final _sellerPrefixController = TextEditingController();

  final _sireVglController = TextEditingController();
  final _damVglController = TextEditingController();

  List<File> _customForms = [];

  @override
  void initState() {
    super.initState();
    _loadCustomForms();
    // Pre-populate seller details from settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsStateProvider);
      _sellerNameController.text = settings['owner_name'] ?? settings['farm_name'] ?? 'FlockKeeper Farm';
      _sellerPhoneController.text = settings['farm_phone'] ?? '';
      _sellerEmailController.text = settings['farm_email'] ?? '';
      _sellerAddressController.text = settings['farm_address'] ?? '';
      _sellerClientIdController.text = settings['nkr_client_id'] ?? '';
      _sellerPrefixController.text = settings['nkr_herd_prefix'] ?? '';
    });
  }

  Future<void> _loadCustomForms() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final customFormsDir = Directory(p.join(directory.path, 'custom_registry_forms'));
      if (!await customFormsDir.exists()) {
        await customFormsDir.create(recursive: true);
      }
      final files = customFormsDir.listSync();
      setState(() {
        _customForms = files
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.pdf'))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading custom registry forms: $e');
    }
  }

  Future<void> _uploadCustomForm() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final pickedPath = result.files.single.path!;
        final directory = await getApplicationDocumentsDirectory();
        final customFormsDir = Directory(p.join(directory.path, 'custom_registry_forms'));
        if (!await customFormsDir.exists()) {
          await customFormsDir.create(recursive: true);
        }

        final fileName = p.basename(pickedPath);
        final destPath = p.join(customFormsDir.path, fileName);
        await File(pickedPath).copy(destPath);

        await _loadCustomForms();
        setState(() {
          _selectedDoc = destPath;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Uploaded custom form: $fileName')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking custom registry form: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload form: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCustomForm(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Custom Form?'),
        content: Text('Are you sure you want to delete ${p.basename(path)}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        await _loadCustomForms();
        setState(() {
          _selectedDoc = 'Certificate';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deleted custom form.')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting custom form: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete form: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _buyerNameController.dispose();
    _buyerAddressController.dispose();
    _buyerPhoneController.dispose();
    _buyerEmailController.dispose();
    _buyerClientIdController.dispose();
    _buyerPrefixController.dispose();
    _priceController.dispose();

    _sellerNameController.dispose();
    _sellerPhoneController.dispose();
    _sellerEmailController.dispose();
    _sellerAddressController.dispose();
    _sellerClientIdController.dispose();
    _sellerPrefixController.dispose();

    _sireVglController.dispose();
    _damVglController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);

    final defaultOptions = {'Certificate', 'All', 'DNA', 'RegApp', 'Transfer', 'Dual'};
    final customPaths = _customForms.map((f) => f.path).toSet();
    if (!defaultOptions.contains(_selectedDoc) && !customPaths.contains(_selectedDoc)) {
      _selectedDoc = 'Certificate';
    }

    Widget formPanel() {
      return Card(
        margin: const EdgeInsets.all(12),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Document Package',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include Bill of Sale'),
                subtitle: const Text('Generates transfer document'),
                value: _includeBillOfSale,
                onChanged: (val) {
                  setState(() {
                    _includeBillOfSale = val;
                    if (!val) {
                      _selectedDoc = 'Certificate';
                    }
                  });
                },
              ),
              if (_includeBillOfSale) ...[
                const Divider(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDoc,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Document to Preview/Export',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'Certificate', child: Text('Custom Certificate & Bill of Sale')),
                    const DropdownMenuItem(value: 'All', child: Text('All Documents (Full Package)')),
                    const DropdownMenuItem(value: 'DNA', child: Text('NKR DNA Request Form')),
                    const DropdownMenuItem(value: 'RegApp', child: Text('NKR Registration Application')),
                    const DropdownMenuItem(value: 'Transfer', child: Text('NKR Transfer Form')),
                    if (_registeredInOtherRegistry)
                      const DropdownMenuItem(value: 'Dual', child: Text('NKR Dual Register Form')),
                    ..._customForms.map((file) {
                      return DropdownMenuItem(
                        value: file.path,
                        child: Text('Custom: ${p.basename(file.path)}'),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDoc = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include Goat Photo on Bill of Sale'),
                  subtitle: const Text('Include picture next to description'),
                  value: _includeGoatPhoto,
                  onChanged: (val) {
                    setState(() {
                      _includeGoatPhoto = val;
                    });
                  },
                ),
                if (_includeGoatPhoto) ...[
                  const SizedBox(height: 8),
                  if (widget.animal.photoPath != null) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Use Animal Profile Photo'),
                      subtitle: const Text('Toggles between profile and custom photo'),
                      value: _useExistingPhoto,
                      onChanged: (val) {
                        setState(() {
                          _useExistingPhoto = val;
                        });
                      },
                    ),
                  ],
                  if (!_useExistingPhoto || widget.animal.photoPath == null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickCustomPhoto,
                          icon: const Icon(Icons.photo_library),
                          label: Text(_customPhotoPath != null ? 'Change Custom Photo' : 'Select Custom Photo'),
                        ),
                        if (_customPhotoPath != null) ...[
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_customPhotoPath!),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _customPhotoPath = null;
                                if (widget.animal.photoPath != null) {
                                  _useExistingPhoto = true;
                                }
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _uploadCustomForm,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Upload Custom Form', style: TextStyle(fontSize: 12)),
                    ),
                    if (!_selectedDoc.startsWith('Certificate') &&
                        !_selectedDoc.startsWith('All') &&
                        !_selectedDoc.startsWith('DNA') &&
                        !_selectedDoc.startsWith('RegApp') &&
                        !_selectedDoc.startsWith('Transfer') &&
                        !_selectedDoc.startsWith('Dual') &&
                        _selectedDoc.endsWith('.pdf'))
                      TextButton.icon(
                        onPressed: () => _deleteCustomForm(_selectedDoc),
                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                        label: const Text('Delete Form', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Registered in other registry?'),
                  subtitle: const Text('Includes NKR Dual Register Form'),
                  value: _registeredInOtherRegistry,
                  onChanged: (val) {
                    setState(() {
                      _registeredInOtherRegistry = val;
                      if (!val && _selectedDoc == 'Dual') {
                        _selectedDoc = 'Certificate';
                      }
                    });
                  },
                ),
                const Divider(height: 20),
                
                // Seller ExpansionTile
                ExpansionTile(
                  title: const Text('Seller (Ranch) Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    TextFormField(
                      controller: _sellerNameController,
                      decoration: const InputDecoration(labelText: 'Seller Ranch Name', prefixIcon: Icon(Icons.business)),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sellerPhoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneNumberFormatter()],
                      decoration: const InputDecoration(labelText: 'Seller Ranch Phone', prefixIcon: Icon(Icons.phone), hintText: '(XXX)XXX-XXXX'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sellerEmailController,
                      decoration: const InputDecoration(labelText: 'Seller Ranch Email', prefixIcon: Icon(Icons.email)),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sellerAddressController,
                      decoration: const InputDecoration(labelText: 'Seller Address', prefixIcon: Icon(Icons.home)),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sellerClientIdController,
                            decoration: const InputDecoration(labelText: 'Seller NKR Client ID'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _sellerPrefixController,
                            decoration: const InputDecoration(labelText: 'Seller NKR Prefix'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Buyer ExpansionTile
                ExpansionTile(
                  initiallyExpanded: true,
                  title: const Text('Buyer Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    TextFormField(
                      controller: _buyerNameController,
                      decoration: const InputDecoration(labelText: 'Buyer Full Name', prefixIcon: Icon(Icons.person)),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _buyerPhoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneNumberFormatter()],
                      decoration: const InputDecoration(labelText: 'Buyer Phone', prefixIcon: Icon(Icons.phone), hintText: '(XXX)XXX-XXXX'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _buyerEmailController,
                      decoration: const InputDecoration(labelText: 'Buyer Email', prefixIcon: Icon(Icons.email)),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _buyerAddressController,
                      decoration: const InputDecoration(labelText: 'Buyer Address', prefixIcon: Icon(Icons.home)),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _buyerClientIdController,
                            decoration: const InputDecoration(labelText: 'Buyer NKR Client ID'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _buyerPrefixController,
                            decoration: const InputDecoration(labelText: 'Buyer NKR Prefix'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Agreed Price (\$)', prefixIcon: Icon(Icons.attach_money)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
                
                // Additional Options ExpansionTile
                ExpansionTile(
                  title: const Text('Additional NKR Form Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _birthType,
                      decoration: const InputDecoration(labelText: 'Birth Type'),
                      items: ['Single', 'Twin', 'Triplet', 'Quad', 'Quint'].map((val) {
                        return DropdownMenuItem(value: val, child: Text(val));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _birthType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sireVglController,
                      decoration: const InputDecoration(labelText: "Sire's UC-Davis VGL #"),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _damVglController,
                      decoration: const InputDecoration(labelText: "Dam's UC-Davis VGL #"),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hair Sample Attached?'),
                      subtitle: const Text('Checkbox on Registration Form'),
                      value: _hairSampleAttached,
                      onChanged: (val) {
                        setState(() {
                          _hairSampleAttached = val;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    Widget pdfPreviewWidget() {
      final double? agreedPrice = double.tryParse(_priceController.text);

      return PdfPreview(
        initialPageFormat: PdfPageFormat.letter,
        build: (format) async {
          final exportService = ref.read(pdfExportServiceProvider);
          final String? billOfSalePhotoPath = _includeGoatPhoto
              ? (_useExistingPhoto ? widget.animal.photoPath : _customPhotoPath)
              : null;

          if (!_includeBillOfSale || _selectedDoc == 'Certificate') {
            return exportService.generateBuyerCertificate(
                  animal: widget.animal,
                  settings: settings,
                  pageFormat: format,
                  includeBillOfSale: _includeBillOfSale,
                  buyerName: _buyerNameController.text.trim(),
                  buyerAddress: _buyerAddressController.text.trim(),
                  buyerPhone: _buyerPhoneController.text.trim(),
                  agreedPrice: agreedPrice,
                  billOfSalePhotoPath: billOfSalePhotoPath,
                );
          } else if (_selectedDoc == 'DNA') {
            return exportService.generateNkrDnaForm(
                  animal: widget.animal,
                  ownerName: _sellerNameController.text.trim(),
                  ownerPhone: _sellerPhoneController.text.trim(),
                  ownerEmail: _sellerEmailController.text.trim(),
                  ownerAddress: _sellerAddressController.text.trim(),
                  ownerClientId: _sellerClientIdController.text.trim(),
                  ownerPrefix: _sellerPrefixController.text.trim(),
                );
          } else if (_selectedDoc == 'RegApp') {
            return exportService.generateNkrRegApp(
                  animal: widget.animal,
                  ownerName: _sellerNameController.text.trim(),
                  ownerPhone: _sellerPhoneController.text.trim(),
                  ownerEmail: _sellerEmailController.text.trim(),
                  ownerAddress: _sellerAddressController.text.trim(),
                  ownerClientId: _sellerClientIdController.text.trim(),
                  ownerPrefix: _sellerPrefixController.text.trim(),
                  buyerName: _buyerNameController.text.trim(),
                  buyerPhone: _buyerPhoneController.text.trim(),
                  buyerEmail: _buyerEmailController.text.trim(),
                  buyerAddress: _buyerAddressController.text.trim(),
                  buyerClientId: _buyerClientIdController.text.trim(),
                  buyerPrefix: _buyerPrefixController.text.trim(),
                  birthType: _birthType,
                  sireVglId: _sireVglController.text.trim(),
                  damVglId: _damVglController.text.trim(),
                  hairSampleAttached: _hairSampleAttached,
                );
          } else if (_selectedDoc == 'Transfer') {
            return exportService.generateNkrTransfer(
                  animal: widget.animal,
                  ownerName: _sellerNameController.text.trim(),
                  ownerPhone: _sellerPhoneController.text.trim(),
                  ownerEmail: _sellerEmailController.text.trim(),
                  ownerAddress: _sellerAddressController.text.trim(),
                  ownerClientId: _sellerClientIdController.text.trim(),
                  ownerPrefix: _sellerPrefixController.text.trim(),
                  buyerName: _buyerNameController.text.trim(),
                  buyerPhone: _buyerPhoneController.text.trim(),
                  buyerEmail: _buyerEmailController.text.trim(),
                  buyerAddress: _buyerAddressController.text.trim(),
                  buyerClientId: _buyerClientIdController.text.trim(),
                  buyerPrefix: _buyerPrefixController.text.trim(),
                );
          } else if (_selectedDoc == 'Dual') {
            return exportService.generateNkrDualRegister(
                  animal: widget.animal,
                  ownerName: _sellerNameController.text.trim(),
                  ownerPhone: _sellerPhoneController.text.trim(),
                  ownerEmail: _sellerEmailController.text.trim(),
                  ownerAddress: _sellerAddressController.text.trim(),
                  ownerClientId: _sellerClientIdController.text.trim(),
                  ownerPrefix: _sellerPrefixController.text.trim(),
                );
          } else if (_selectedDoc == 'All') {
            final List<Uint8List> docs = [];

            // 1. Certificate and Bill of Sale
            final certBytes = await exportService.generateBuyerCertificate(
              animal: widget.animal,
              settings: settings,
              pageFormat: format,
              includeBillOfSale: _includeBillOfSale,
              buyerName: _buyerNameController.text.trim(),
              buyerAddress: _buyerAddressController.text.trim(),
              buyerPhone: _buyerPhoneController.text.trim(),
              agreedPrice: agreedPrice,
              billOfSalePhotoPath: billOfSalePhotoPath,
            );
            docs.add(certBytes);

            // 2. DNA Form
            final dnaBytes = await exportService.generateNkrDnaForm(
              animal: widget.animal,
              ownerName: _sellerNameController.text.trim(),
              ownerPhone: _sellerPhoneController.text.trim(),
              ownerEmail: _sellerEmailController.text.trim(),
              ownerAddress: _sellerAddressController.text.trim(),
              ownerClientId: _sellerClientIdController.text.trim(),
              ownerPrefix: _sellerPrefixController.text.trim(),
            );
            docs.add(dnaBytes);

            // 3. Registration Application
            final regAppBytes = await exportService.generateNkrRegApp(
              animal: widget.animal,
              ownerName: _sellerNameController.text.trim(),
              ownerPhone: _sellerPhoneController.text.trim(),
              ownerEmail: _sellerEmailController.text.trim(),
              ownerAddress: _sellerAddressController.text.trim(),
              ownerClientId: _sellerClientIdController.text.trim(),
              ownerPrefix: _sellerPrefixController.text.trim(),
              buyerName: _buyerNameController.text.trim(),
              buyerPhone: _buyerPhoneController.text.trim(),
              buyerEmail: _buyerEmailController.text.trim(),
              buyerAddress: _buyerAddressController.text.trim(),
              buyerClientId: _buyerClientIdController.text.trim(),
              buyerPrefix: _buyerPrefixController.text.trim(),
              birthType: _birthType,
              sireVglId: _sireVglController.text.trim(),
              damVglId: _damVglController.text.trim(),
              hairSampleAttached: _hairSampleAttached,
            );
            docs.add(regAppBytes);

            // 4. Transfer Form
            final transferBytes = await exportService.generateNkrTransfer(
              animal: widget.animal,
              ownerName: _sellerNameController.text.trim(),
              ownerPhone: _sellerPhoneController.text.trim(),
              ownerEmail: _sellerEmailController.text.trim(),
              ownerAddress: _sellerAddressController.text.trim(),
              ownerClientId: _sellerClientIdController.text.trim(),
              ownerPrefix: _sellerPrefixController.text.trim(),
              buyerName: _buyerNameController.text.trim(),
              buyerPhone: _buyerPhoneController.text.trim(),
              buyerEmail: _buyerEmailController.text.trim(),
              buyerAddress: _buyerAddressController.text.trim(),
              buyerClientId: _buyerClientIdController.text.trim(),
              buyerPrefix: _buyerPrefixController.text.trim(),
            );
            docs.add(transferBytes);

            // 5. Dual Register Form (if checked)
            if (_registeredInOtherRegistry) {
              final dualBytes = await exportService.generateNkrDualRegister(
                animal: widget.animal,
                ownerName: _sellerNameController.text.trim(),
                ownerPhone: _sellerPhoneController.text.trim(),
                ownerEmail: _sellerEmailController.text.trim(),
                ownerAddress: _sellerAddressController.text.trim(),
                ownerClientId: _sellerClientIdController.text.trim(),
                ownerPrefix: _sellerPrefixController.text.trim(),
              );
              docs.add(dualBytes);
            }

            return exportService.mergePdfDocuments(docs);
          }
          if (File(_selectedDoc).existsSync()) {
            final pdfSettings = {
              ...settings,
              'owner_name': _sellerNameController.text.trim(),
              'farm_phone': _sellerPhoneController.text.trim(),
              'farm_email': _sellerEmailController.text.trim(),
              'farm_address': _sellerAddressController.text.trim(),
              'nkr_client_id': _sellerClientIdController.text.trim(),
              'nkr_herd_prefix': _sellerPrefixController.text.trim(),
              'buyer_name': _buyerNameController.text.trim(),
              'buyer_phone': _buyerPhoneController.text.trim(),
              'buyer_email': _buyerEmailController.text.trim(),
              'buyer_address': _buyerAddressController.text.trim(),
              'buyer_client_id': _buyerClientIdController.text.trim(),
              'buyer_prefix': _buyerPrefixController.text.trim(),
              'birth_type': _birthType,
            };
            return exportService.generateCustomPdfForm(
              templatePath: _selectedDoc,
              animal: widget.animal,
              settings: pdfSettings,
            );
          }
          throw Exception('Unknown document type');
        },
        pdfFileName: _selectedDoc == 'Certificate'
            ? (_includeBillOfSale 
                ? '${widget.animal.name.replaceAll(' ', '_')}_Certificate_and_Bill_of_Sale.pdf'
                : '${widget.animal.name.replaceAll(' ', '_')}_Certificate.pdf')
            : (_selectedDoc == 'All'
                ? '${widget.animal.name.replaceAll(' ', '_')}_Full_Document_Package.pdf'
                : (_selectedDoc.endsWith('.pdf') 
                    ? '${widget.animal.name.replaceAll(' ', '_')}_${p.basename(_selectedDoc)}'
                    : '${widget.animal.name.replaceAll(' ', '_')}_NKR_Form_$_selectedDoc.pdf')),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        actions: const [],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.animal.name} Certificate Export'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 850) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: SingleChildScrollView(child: formPanel()),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pdfPreviewWidget()),
              ],
            );
          } else {
            return Column(
              children: [
                Flexible(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: formPanel(),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: pdfPreviewWidget(),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
