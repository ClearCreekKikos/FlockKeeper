// lib/features/import/screens/field_mapper_screen.dart

import 'package:flutter/material.dart';

import '../models/field_mapping.dart';
import '../templates/import_template.dart';
import 'import_preview_screen.dart';

class FieldMapperScreen extends StatefulWidget {
  final String fileName;
  final List<String> headers;
  final List<Map<String, String>> rawRows;

  const FieldMapperScreen({
    super.key,
    required this.fileName,
    required this.headers,
    required this.rawRows,
  });

  @override
  State<FieldMapperScreen> createState() => _FieldMapperScreenState();
}

class _FieldMapperScreenState extends State<FieldMapperScreen> {
  late List<FieldMapping> _mappings;

  @override
  void initState() {
    super.initState();
    _initializeMappings();
  }

  void _initializeMappings() {
    final autoDetected = SmartAutoMapper.autoMap(widget.headers);

    _mappings = widget.headers.map((header) {
      final targetKey = autoDetected[header];
      final isRequired = targetKey != null &&
          FlockKeeperFields.animalFields
              .firstWhere((f) => f.key == targetKey,
                  orElse: () => const TargetField('', '', false))
              .isRequired;

      return FieldMapping(
        sourceField: header,
        targetField: targetKey,
        isRequired: isRequired,
        sampleValue: widget.rawRows.isNotEmpty ? widget.rawRows.first[header] : null,
      );
    }).toList();
  }

  void _updateMapping(int index, String? targetField) {
    setState(() {
      final oldMapping = _mappings[index];
      
      // Check if targetField is required
      final isRequired = targetField != null &&
          FlockKeeperFields.animalFields
              .firstWhere((f) => f.key == targetField,
                  orElse: () => const TargetField('', '', false))
              .isRequired;

      _mappings[index] = oldMapping.copyWith(targetField: targetField);
      // We also update isRequired property by copying since copyWith doesn't modify isRequired direct.
      // But we can construct a new one for completeness.
      _mappings[index] = FieldMapping(
        sourceField: oldMapping.sourceField,
        targetField: targetField,
        isRequired: isRequired,
        sampleValue: oldMapping.sampleValue,
      );
    });
  }

  bool _validateRequiredFields() {
    final mappedTargets = _mappings.map((m) => m.targetField).toSet();
    final requiredFields = FlockKeeperFields.animalFields.where((f) => f.isRequired);

    for (final req in requiredFields) {
      if (!mappedTargets.contains(req.key)) {
        return false;
      }
    }
    return true;
  }

  List<String> _getMissingRequiredFields() {
    final mappedTargets = _mappings.map((m) => m.targetField).toSet();
    return FlockKeeperFields.animalFields
        .where((f) => f.isRequired && !mappedTargets.contains(f.key))
        .map((f) => f.displayName)
        .toList();
  }

  void _goToPreview() {
    if (!_validateRequiredFields()) {
      final missing = _getMissingRequiredFields().join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please map all required fields: $missing'),
          backgroundColor: Colors.red[800],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportPreviewScreen(
          fileName: widget.fileName,
          mappings: _mappings,
          rawRows: widget.rawRows,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isValid = _validateRequiredFields();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Import Columns'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: ElevatedButton(
            onPressed: _goToPreview,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isValid ? Theme.of(context).colorScheme.primary : Colors.grey,
              foregroundColor: isValid ? Colors.white : Colors.black54,
            ),
            child: const Text(
              'Next: Preview Records',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mapping Columns for: ${widget.fileName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Match the columns from your uploaded file on the left to FlockKeeper\'s data fields on the right. '
                      'Required fields are marked with an asterisk (*).',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Required Fields Banner if missing
          if (!isValid)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Missing Required Mappings: ${_getMissingRequiredFields().join(", ")}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // List of Headers
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: _mappings.length,
              itemBuilder: (context, index) {
                final mapping = _mappings[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Left: Source column details
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mapping.sourceField,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (mapping.sampleValue != null &&
                                  mapping.sampleValue!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Sample: "${mapping.sampleValue}"',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),
                        const Icon(Icons.arrow_forward, color: Colors.grey),
                        const SizedBox(width: 16),

                        // Right: Dropdown mapper
                        Expanded(
                          flex: 6,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: mapping.targetField,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              // Don't Import option
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text(
                                  "Don't Import",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              // FlockKeeper target fields
                              ...FlockKeeperFields.animalFields.map((field) {
                                return DropdownMenuItem(
                                  value: field.key,
                                  child: Text(
                                    '${field.displayName}${field.isRequired ? " *" : ""}',
                                    style: TextStyle(
                                      fontWeight: field.isRequired ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) => _updateMapping(index, val),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
