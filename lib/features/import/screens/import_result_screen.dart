// lib/features/import/screens/import_result_screen.dart

import 'package:flutter/material.dart';

import '../services/import_service.dart';

class ImportResultScreen extends StatelessWidget {
  final ImportResult result;

  const ImportResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final hasErrors = result.errors.isNotEmpty;
    final themeColor = hasErrors && result.successCount == 0
        ? Colors.red
        : result.successCount > 0
            ? Colors.green
            : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Results'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Pop back to settings screen
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Status Icon
            Icon(
              hasErrors && result.successCount == 0
                  ? Icons.cancel_outlined
                  : Icons.check_circle_outline,
              size: 80,
              color: themeColor,
            ),
            const SizedBox(height: 16),
            Text(
              result.successCount > 0 ? 'Import Complete' : 'Import Finished',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // Statistics Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStatRow('Total Rows Processed:', '${result.totalRows}', null),
                    const Divider(height: 24),
                    _buildStatRow('Successful Imports:', '${result.successCount}', Colors.green),
                    _buildStatRow('Updated Records:', '${result.updatedCount}', Colors.blue),
                    _buildStatRow('Skipped (Duplicates):', '${result.skippedCount}', Colors.orange),
                    _buildStatRow('Errors (Failed rows):', '${result.errors.length}', Colors.red),
                  ],
                ),
              ),
            ),

            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Row Failures (${result.errors.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: result.errors.length,
                itemBuilder: (context, index) {
                  final err = result.errors[index];
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Card(
                    color: isDark ? Colors.red[900]?.withValues(alpha: 0.3) : Colors.red[50],
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: isDark ? Colors.red[900]?.withValues(alpha: 0.5) : Colors.red[100],
                        radius: 14,
                        child: Text(
                          '${err.rowIndex}',
                          style: TextStyle(
                            color: isDark ? Colors.red[200] : Colors.red[900],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        'Row ${err.rowIndex} failed',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        err.message,
                        style: TextStyle(color: isDark ? Colors.red[200] : Colors.red[900]),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
