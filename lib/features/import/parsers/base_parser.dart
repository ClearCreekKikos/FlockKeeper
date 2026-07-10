import 'dart:typed_data';

abstract class BaseParser {
  /// Parses raw file bytes into a list of raw rows (key-value maps)
  Future<List<Map<String, String>>> parse(Uint8List fileBytes);

  /// Returns the detected column headers from the file
  Future<List<String>> detectHeaders(Uint8List fileBytes);
}
