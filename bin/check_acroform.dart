// ignore_for_file: avoid_print
import 'dart:io';

void main() {
  final dir = Directory('C:\\Users\\hecte\\AndroidStudioProjects\\flockkeeper\\forms');
  if (!dir.existsSync()) {
    print('Directory forms/ does not exist.');
    return;
  }

  for (final file in dir.listSync()) {
    if (file is File && file.path.endsWith('.pdf')) {
      final bytes = file.readAsBytesSync();
      final content = String.fromCharCodes(bytes);
      final hasAcroForm = content.contains('/AcroForm');
      print('${file.path.split(Platform.pathSeparator).last}: Has AcroForm = $hasAcroForm');
    }
  }
}
