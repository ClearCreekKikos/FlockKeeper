// lib/features/inventory/screens/supplier_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/supplier_model.dart';
import '../../../shared/providers/providers.dart';
import '../providers/inventory_providers.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Supplier',
            onPressed: () => _showAddEditDialog(context, ref),
          ),
        ],
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return const Center(child: Text('No suppliers yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final s = suppliers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.store,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: s.website != null && s.website!.isNotEmpty
                      ? Text(s.website!, style: const TextStyle(fontSize: 12))
                      : s.contactInfo != null && s.contactInfo!.isNotEmpty
                          ? Text(s.contactInfo!, style: const TextStyle(fontSize: 12))
                          : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.website != null && s.website!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          tooltip: 'Open Website',
                          onPressed: () async {
                            final uri = Uri.parse(s.website!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Edit',
                        onPressed: () =>
                            _showAddEditDialog(context, ref, existing: s),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDelete(context, ref, s),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddEditDialog(
    BuildContext context,
    WidgetRef ref, {
    Supplier? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final contactCtrl = TextEditingController(text: existing?.contactInfo ?? '');
    final websiteCtrl = TextEditingController(text: existing?.website ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Supplier' : 'Add Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: websiteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Website',
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contactCtrl,
                decoration: const InputDecoration(labelText: 'Contact Info'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final repo = ref.read(supplierRepositoryProvider);
              final supplier = Supplier(
                id: existing?.id,
                name: name,
                contactInfo: contactCtrl.text.trim().isEmpty
                    ? null
                    : contactCtrl.text.trim(),
                website: websiteCtrl.text.trim().isEmpty
                    ? null
                    : websiteCtrl.text.trim(),
                notes: notesCtrl.text.trim().isEmpty
                    ? null
                    : notesCtrl.text.trim(),
                createdAt: existing?.createdAt,
              );

              if (isEdit) {
                await repo.updateSupplier(supplier);
              } else {
                await repo.insertSupplier(supplier);
              }

              ref.invalidate(suppliersListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Supplier s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Delete "${s.name}"? Items linked to this supplier will be unlinked.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              await ref.read(supplierRepositoryProvider).deleteSupplier(s.id!);
              ref.invalidate(suppliersListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
