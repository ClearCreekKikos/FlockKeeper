// lib/features/import/screens/import_home_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../parsers/base_parser.dart';
import '../parsers/csv_parser.dart';
import '../parsers/excel_parser.dart';
import 'field_mapper_screen.dart';

class ImportHomeScreen extends StatefulWidget {
  const ImportHomeScreen({super.key});

  @override
  State<ImportHomeScreen> createState() => _ImportHomeScreenState();
}

class _ImportHomeScreenState extends State<ImportHomeScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true, // required for web and safe on mobile/desktop
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.first;
      final extension = file.extension?.toLowerCase();

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Could not read file data. The file might be empty.');
      }

      BaseParser parser;
      if (extension == 'csv') {
        parser = CsvParser();
      } else if (extension == 'xlsx' || extension == 'xls') {
        parser = ExcelParser();
      } else {
        throw Exception('Unsupported file format. Please upload a .csv or .xlsx file.');
      }

      final headers = await parser.detectHeaders(bytes);
      if (headers.isEmpty) {
        throw Exception('No column headers detected in the file. Ensure the first row contains headers.');
      }

      final rawRows = await parser.parse(bytes);
      if (rawRows.isEmpty) {
        throw Exception('No data records found in the file.');
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FieldMapperScreen(
              fileName: file.name,
              headers: headers,
              rawRows: rawRows,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Herd Data'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Import from CSV or Excel',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bring records from other herd management software into FlockKeeper. '
                'You will be able to map your custom file columns to internal fields in the next step.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Browse Excel / CSV File'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 48),
              _buildTipsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tips for Successful Import',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTipItem('The first row of your file MUST contain column names (headers).'),
            _buildTipItem('Ensure animal names are included (required for FlockKeeper).'),
            _buildTipItem('Dates (like Date of Birth) should be formatted clearly (e.g. MM/dd/yyyy or yyyy-MM-dd).'),
            _buildTipItem('Animal sexes should be labeled Doe, Buck, Wether, or M/F.'),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
