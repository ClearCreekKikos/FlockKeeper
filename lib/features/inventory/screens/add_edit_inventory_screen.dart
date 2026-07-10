// lib/features/inventory/screens/add_edit_inventory_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/inventory_item_model.dart';

import '../../../shared/providers/providers.dart';
import '../providers/inventory_providers.dart';

class AddEditInventoryScreen extends ConsumerStatefulWidget {
  final InventoryItem? existingItem;

  const AddEditInventoryScreen({super.key, this.existingItem});

  @override
  ConsumerState<AddEditInventoryScreen> createState() =>
      _AddEditInventoryScreenState();
}

class _AddEditInventoryScreenState
    extends ConsumerState<AddEditInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _minQuantityCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _notesCtrl;

  InventoryCategory _category = InventoryCategory.healthMedical;
  int? _supplierId;
  DateTime? _expirationDate;
  bool _isActive = true;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _unitCtrl = TextEditingController(text: item?.unit ?? 'each');
    _quantityCtrl = TextEditingController(
      text: item != null ? _fmtQty(item.currentQuantity) : '0',
    );
    _minQuantityCtrl = TextEditingController(
      text: item != null ? _fmtQty(item.minimumQuantity) : '1',
    );
    _costCtrl = TextEditingController(
      text: item != null ? item.costPerUnit.toStringAsFixed(2) : '0.00',
    );
    _barcodeCtrl = TextEditingController(text: item?.barcode ?? '');
    _notesCtrl = TextEditingController(text: item?.notes ?? '');
    _category = item?.category ?? InventoryCategory.healthMedical;
    _supplierId = item?.supplierId;
    _expirationDate = item?.expirationDate;
    _isActive = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _quantityCtrl.dispose();
    _minQuantityCtrl.dispose();
    _costCtrl.dispose();
    _barcodeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmtQty(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  Future<void> _pickExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expirationDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(inventoryRepositoryProvider);
    final suppliers = ref.read(suppliersListProvider).whenOrNull(
      data: (list) => list,
    ) ?? [];
    final supplierName = _supplierId != null
        ? suppliers
            .where((s) => s.id == _supplierId)
            .map((s) => s.name)
            .firstOrNull
        : null;

    final item = InventoryItem(
      id: widget.existingItem?.id,
      name: _nameCtrl.text.trim(),
      category: _category,
      unit: _unitCtrl.text.trim(),
      currentQuantity: double.tryParse(_quantityCtrl.text) ?? 0,
      minimumQuantity: double.tryParse(_minQuantityCtrl.text) ?? 1,
      costPerUnit: double.tryParse(_costCtrl.text) ?? 0,
      supplierId: _supplierId,
      supplierName: supplierName,
      expirationDate: _expirationDate,
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isActive: _isActive,
      createdAt: widget.existingItem?.createdAt,
    );

    if (_isEditing) {
      await repo.updateItem(item);
    } else {
      await repo.insertItem(item);
    }

    ref.invalidate(inventoryItemsProvider);
    ref.invalidate(lowStockItemsProvider);
    ref.invalidate(expiringItemsProvider);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Supply' : 'Add Supply'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Name ─────────────────────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Item Name *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),

            // ─── Category ─────────────────────────────────────────────────
            DropdownButtonFormField<InventoryCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: InventoryCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(InventoryItem.categoryLabel(c)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 12),

            // ─── Unit & Quantities row ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _unitCtrl,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _quantityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minQuantityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Min Stock'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ─── Cost ─────────────────────────────────────────────────────
            TextFormField(
              controller: _costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cost per Unit (\$)',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),

            // ─── Supplier ─────────────────────────────────────────────────
            suppliersAsync.when(
              data: (suppliers) => DropdownButtonFormField<int?>(
                initialValue: _supplierId,
                decoration: const InputDecoration(labelText: 'Supplier'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('None')),
                  ...suppliers.map((s) => DropdownMenuItem<int?>(
                        value: s.id,
                        child: Text(s.name),
                      )),
                ],
                onChanged: (v) => setState(() => _supplierId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => const Text('Could not load suppliers'),
            ),
            const SizedBox(height: 12),

            // ─── Expiration Date ──────────────────────────────────────────
            InkWell(
              onTap: _pickExpirationDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Expiration Date',
                  suffixIcon: _expirationDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setState(() => _expirationDate = null),
                        )
                      : const Icon(Icons.calendar_today),
                ),
                child: Text(
                  _expirationDate != null
                      ? DateFormat.yMMMd().format(_expirationDate!)
                      : 'No expiration',
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Barcode ──────────────────────────────────────────────────
            TextFormField(
              controller: _barcodeCtrl,
              decoration: InputDecoration(
                labelText: 'Barcode / QR Code',
                suffixIcon: (Platform.isAndroid || Platform.isIOS)
                    ? IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'Scan Code',
                        onPressed: () {
                          // QR scanning will be integrated via mobile_scanner
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('QR scanning coming soon'),
                            ),
                          );
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),

            // ─── Stock Switch ─────────────────────────────────────────────
            SwitchListTile(
              title: const Text('Active / In Stock'),
              subtitle: const Text('Turn off to make this item inactive (unstocked), which hides it from alerts and active lists.'),
              value: _isActive,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 12),

            // ─── Notes ────────────────────────────────────────────────────
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
