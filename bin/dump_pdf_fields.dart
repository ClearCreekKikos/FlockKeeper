// ignore_for_file: avoid_print
import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  final dir = Directory('C:\\Users\\hecte\\AndroidStudioProjects\\flockkeeper\\forms');
  if (!dir.existsSync()) {
    print('Directory forms/ does not exist.');
    return;
  }

  for (final file in dir.listSync()) {
    if (file is File && file.path.endsWith('.pdf')) {
      final bytes = file.readAsBytesSync();
      try {
        final document = sf.PdfDocument(inputBytes: bytes);
        print('=========================================');
        print('File: ${file.path.split(Platform.pathSeparator).last}');
        print('=========================================');
        final form = document.form;
        print('Total fields: ${form.fields.count}');
        for (var i = 0; i < form.fields.count; i++) {
          final field = form.fields[i];
          String typeStr = field.runtimeType.toString();
          print('  - Name: "${field.name}" | Type: $typeStr');
        }
        document.dispose();
      } catch (e) {
        print('Error reading ${file.path}: $e');
      }
    }
  }
}
