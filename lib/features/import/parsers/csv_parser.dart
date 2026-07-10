// lib/features/import/parsers/csv_parser.dart

import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'base_parser.dart';

class CsvParser extends BaseParser {
  @override
  Future<List<Map<String, String>>> parse(Uint8List fileBytes) async {
    final content = utf8.decode(fileBytes, allowMalformed: true);
    final rows = CsvDecoder().convert(content);

    if (rows.isEmpty) return [];

    // First row = headers
    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.skip(1).toList();

    return dataRows.map((row) {
      final map = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        map[headers[i]] = i < row.length ? row[i].toString().trim() : '';
      }
      return map;
    }).toList();
  }

  @override
  Future<List<String>> detectHeaders(Uint8List fileBytes) async {
    final content = utf8.decode(fileBytes, allowMalformed: true);
    final rows = CsvDecoder().convert(content);
    if (rows.isEmpty) return [];
    return rows.first.map((e) => e.toString().trim()).toList();
  }
}
