import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class PathResolver {
  static String? _docDirPath;

  static Future<void> initialize() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _docDirPath = docDir.path;
      debugPrint('PathResolver initialized with Documents Directory: $_docDirPath');
    } catch (e) {
      debugPrint('Error initializing PathResolver: $e');
    }
  }

  static String? get docDirPath => _docDirPath;

  static String? resolvePath(String? originalPath) {
    if (originalPath == null || originalPath.isEmpty) return originalPath;

    // Check if the path contains our media signature folders
    const mediaSubstrings = ['flockkeeper_media/photos/', 'flockkeeper_media/logos/'];
    
    for (final substring in mediaSubstrings) {
      final index = originalPath.indexOf(substring);
      if (index != -1) {
        final relativePath = originalPath.substring(index);
        if (_docDirPath != null) {
          return p.join(_docDirPath!, relativePath);
        }
      }
    }
    return originalPath;
  }
}
