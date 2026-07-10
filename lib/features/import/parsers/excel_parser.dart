// lib/features/import/parsers/excel_parser.dart

import 'package:excel/excel.dart';
import 'dart:typed_data';
import 'base_parser.dart';

class ExcelParser extends BaseParser {
  final int sheetIndex;
  ExcelParser({this.sheetIndex = 0});

  @override
  Future<List<Map<String, String>>> parse(Uint8List fileBytes) async {
    final excel = Excel.decodeBytes(fileBytes);
    final sheetName = excel.tables.keys.elementAt(sheetIndex);
    final sheet = excel.tables[sheetName]!;

    if (sheet.rows.isEmpty) return [];

    final headers = sheet.rows.first
        .map((cell) => cell?.value?.toString().trim() ?? '')
        .toList();

    return sheet.rows.skip(1).map((row) {
      final map = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        map[headers[i]] = i < row.length
            ? row[i]?.value?.toString().trim() ?? ''
            : '';
      }
      return map;
    }).toList();
  }

  @override
  Future<List<String>> detectHeaders(Uint8List fileBytes) async {
    final excel = Excel.decodeBytes(fileBytes);
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    if (sheet.rows.isEmpty) return [];
    return sheet.rows.first
        .map((cell) => cell?.value?.toString().trim() ?? '')
        .toList();
  }
}
