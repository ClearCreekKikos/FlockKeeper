// lib/features/import/screens/import_preview_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/providers/animal_providers.dart';
import '../models/field_mapping.dart';
import '../services/import_service.dart';
import 'import_result_screen.dart';

class ImportPreviewScreen extends ConsumerStatefulWidget {
  final String fileName;
  final List<FieldMapping> mappings;
  final List<Map<String, String>> rawRows;

  const ImportPreviewScreen({
    super.key,
    required this.fileName,
    required this.mappings,
    required this.rawRows,
  });

  @override
  ConsumerState<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends ConsumerState<ImportPreviewScreen> {
  ConflictResolutionStrategy _selectedStrategy = ConflictResolutionStrategy.skip;
  bool _isImporting = false;

  Map<String, String> _applyMappings(Map<String, String> rawRow) {
    final result = <String, String>{};
    for (final mapping in widget.mappings) {
      if (mapping.targetField != null) {
        result[mapping.targetField!] = rawRow[mapping.sourceField] ?? '';
      }
    }
    return result;
  }

  String _parseDateDisplay(String? value) {
    if (value == null || value.isEmpty) return 'Not set';
    final formats = [
      'MM/dd/yyyy', 'yyyy-MM-dd', 'MM-dd-yyyy',
      'dd/MM/yyyy', 'M/d/yyyy',   'yyyy/MM/dd',
    ];
    for (final fmt in formats) {
      try {
        final parsed = DateFormat(fmt).parseStrict(value);
        return DateFormat.yMMMd().format(parsed);
      } catch (e) {
        debugPrint('Failed to parse date "$value" with format "$fmt": $e');
        // Try next format
      }
    }
    return 'Invalid Date ("$value")';
  }

  String _parseSexDisplay(String value) {
    final v = value.toLowerCase().trim();
    if (v == 'f' || v == 'female' || v == 'doe') return 'Doe (Female)';
    if (v == 'm' || v == 'male' || v == 'buck') return 'Buck (Male)';
    if (v == 'w' || v == 'wether' || v == 'castrated') return 'Wether';
    if (v.isEmpty) return 'Unknown (Missing)';
    return 'Unknown ("$value")';
  }

  Future<void> _executeImport() async {
    setState(() => _isImporting = true);

    try {
      final importService = ref.read(importServiceProvider);
      final result = await importService.importAnimals(
        rawRows: widget.rawRows,
        mappings: widget.mappings,
        conflictStrategy: _selectedStrategy,
      );

      // Invalidate animal providers to refresh the main herd list
      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);
      ref.invalidate(searchedAnimalsProvider);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ImportResultScreen(result: result),
          ),
          (route) => route.isFirst, // Go back to Settings
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Preview first 5 rows
    final previewCount = widget.rawRows.length < 5 ? widget.rawRows.length : 5;
    final previewRows = widget.rawRows.take(previewCount).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Records'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: ElevatedButton(
            onPressed: _isImporting ? null : _executeImport,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isImporting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Import All ${widget.rawRows.length} Records Now',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Conflict Strategy Selection Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Duplicate Resolution Strategy',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'If an imported animal\'s registration number already exists in the database:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ConflictResolutionStrategy>(
                      isExpanded: true,
                      initialValue: _selectedStrategy,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ConflictResolutionStrategy.skip,
                          child: Text('Skip (Ignore row, keep existing)'),
                        ),
                        DropdownMenuItem(
                          value: ConflictResolutionStrategy.overwrite,
                          child: Text('Overwrite (Replace with import row)'),
                        ),
                        DropdownMenuItem(
                          value: ConflictResolutionStrategy.keepBoth,
                          child: Text('Keep Both (Create duplicate record)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStrategy = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Sample Preview (First $previewCount of ${widget.rawRows.length} Rows)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            // Preview List
            ...List.generate(previewRows.length, (index) {
              final rawRow = previewRows[index];
              final mappedData = _applyMappings(rawRow);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Row #${index + 2}: ${mappedData['name'] ?? "Unknown"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _parseSexDisplay(mappedData['sex'] ?? ''),
                              style: TextStyle(fontSize: 12, color: Colors.blue[800], fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _buildPreviewItem('DOB:', _parseDateDisplay(mappedData['dob'])),
                      _buildPreviewItem('NKR Reg. Number:', mappedData['nkrRegNumber']?.isNotEmpty == true ? mappedData['nkrRegNumber']! : 'Not mapped/empty'),
                      _buildPreviewItem('Ear Tag:', mappedData['earTag']?.isNotEmpty == true ? mappedData['earTag']! : 'Not mapped/empty'),
                      _buildPreviewItem('Tattoo:', mappedData['tattoo']?.isNotEmpty == true ? mappedData['tattoo']! : 'Not mapped/empty'),
                      _buildPreviewItem('Sire Name:', mappedData['sireName']?.isNotEmpty == true ? mappedData['sireName']! : 'Not mapped/empty'),
                      _buildPreviewItem('Dam Name:', mappedData['damName']?.isNotEmpty == true ? mappedData['damName']! : 'Not mapped/empty'),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    final isWarning = value.startsWith('Invalid');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isWarning ? Colors.red : null,
                fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
