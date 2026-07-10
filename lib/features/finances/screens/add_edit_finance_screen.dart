// lib/features/finances/screens/add_edit_finance_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/providers/providers.dart';
import '../../../data/models/financial_record_model.dart';
import '../../../shared/providers/animal_providers.dart';
import '../providers/financial_providers.dart';

class AddEditFinanceScreen extends ConsumerStatefulWidget {
  final FinancialRecord? record;

  const AddEditFinanceScreen({super.key, this.record});

  @override
  ConsumerState<AddEditFinanceScreen> createState() => _AddEditFinanceScreenState();
}

class _AddEditFinanceScreenState extends ConsumerState<AddEditFinanceScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vendorBuyerController = TextEditingController();
  final _receiptController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'expense'; // 'income' or 'expense'
  String _selectedCategory = 'other';
  DateTime _selectedDate = DateTime.now();
  int? _selectedAnimalId;

  // Static list of categories from DB constraints
  static const List<Map<String, String>> _categories = [
    {'value': 'purchase', 'label': 'Purchase'},
    {'value': 'sale', 'label': 'Sale'},
    {'value': 'feed', 'label': 'Feed'},
    {'value': 'medication', 'label': 'Medication'},
    {'value': 'veterinary', 'label': 'Veterinary'},
    {'value': 'equipment', 'label': 'Equipment'},
    {'value': 'pasture', 'label': 'Pasture'},
    {'value': 'registration', 'label': 'Registration'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();

    if (widget.record != null) {
      final r = widget.record!;
      _selectedType = r.type;
      _selectedCategory = r.category;
      _selectedDate = r.recordDate;
      _amountController.text = r.amount.toStringAsFixed(2);
      _descriptionController.text = r.description ?? '';
      _vendorBuyerController.text = r.vendorBuyer ?? '';
      _receiptController.text = r.receiptNumber ?? '';
      _notesController.text = r.notes ?? '';
      _selectedAnimalId = r.animalId;
    } else {
      // Default category depending on type
      _selectedCategory = 'feed';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _vendorBuyerController.dispose();
    _receiptController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(financialRepositoryProvider);
    final amount = double.parse(_amountController.text);

    final record = FinancialRecord(
      id: widget.record?.id,
      animalId: _selectedAnimalId,
      recordDate: _selectedDate,
      category: _selectedCategory,
      type: _selectedType,
      amount: amount,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      vendorBuyer: _vendorBuyerController.text.trim().isEmpty
          ? null
          : _vendorBuyerController.text.trim(),
      receiptNumber: _receiptController.text.trim().isEmpty
          ? null
          : _receiptController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: widget.record?.createdAt,
    );

    try {
      if (widget.record == null) {
        await repo.insertFinancialRecord(record);
      } else {
        await repo.updateFinancialRecord(record);
      }

      ref.invalidate(financialRecordsProvider);
      if (_selectedAnimalId != null) {
        ref.invalidate(financialRecordsForAnimalProvider(_selectedAnimalId!));
      }
      if (widget.record?.animalId != null && widget.record?.animalId != _selectedAnimalId) {
        ref.invalidate(financialRecordsForAnimalProvider(widget.record!.animalId!));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.record == null
                ? 'Transaction added successfully.'
                : 'Transaction updated successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalsAsync = ref.watch(activeAnimalsProvider);
    final isEdit = widget.record != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ─── Transaction Type Toggle ─────────────────────────────────────
            const Text(
              'Transaction Type',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'expense',
                  label: Text('Cost / Expense'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment<String>(
                  value: 'income',
                  label: Text('Sale / Income'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                  // Auto switch category if user hasn't customized it heavily
                  if (_selectedType == 'income') {
                    _selectedCategory = 'sale';
                  } else {
                    _selectedCategory = 'feed';
                  }
                });
              },
            ),
            const SizedBox(height: 20),

            // ─── Financial Value Section ─────────────────────────────────────
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (\$)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null) {
                          return 'Please enter a valid number';
                        }
                        if (amount <= 0) {
                          return 'Amount must be greater than zero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date Field
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Transaction Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat.yMMMd().format(_selectedDate),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Details Section ─────────────────────────────────────────────
            const Text(
              'Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['value']!,
                          child: Text(cat['label']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Description Form Field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (e.g. Premium Alfalfa)',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 100,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                    const SizedBox(height: 16),
                    // Vendor / Buyer field
                    TextFormField(
                      controller: _vendorBuyerController,
                      decoration: InputDecoration(
                        labelText: _selectedType == 'income' ? 'Buyer' : 'Vendor',
                        border: const OutlineInputBorder(),
                      ),
                      maxLength: 100,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── Animal Association & References ─────────────────────────────
            const Text(
              'Association & References',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Animal Selector Dropdown
                    animalsAsync.when(
                      data: (animals) {
                        // Allow selecting no animal
                        return DropdownButtonFormField<int?>(
                          initialValue: _selectedAnimalId,
                          decoration: const InputDecoration(
                            labelText: 'Link to Goat (Optional)',
                            border: OutlineInputBorder(),
                            helperText: 'Associate this cost/sale with a specific goat',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('None (General Farm Expense/Sale)'),
                            ),
                            ...animals.map((animal) {
                              return DropdownMenuItem<int?>(
                                value: animal.id,
                                child: Text('${animal.name} (${animal.sexDisplay})'),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedAnimalId = value;
                            });
                          },
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Text(
                        'Failed to load goats: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Receipt Number Form Field
                    TextFormField(
                      controller: _receiptController,
                      decoration: const InputDecoration(
                        labelText: 'Receipt / Invoice # (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 50,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                    const SizedBox(height: 16),
                    // Notes field
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 500,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isEdit ? 'Save Changes' : 'Log Transaction',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
