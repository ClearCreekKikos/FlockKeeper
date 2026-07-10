import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  test('Dump PDF form fields to file synchronously', () {
    final dir = Directory('C:\\Users\\hecte\\AndroidStudioProjects\\flockkeeper\\forms');
    expect(dir.existsSync(), true);

    final sb = StringBuffer();

    for (final file in dir.listSync()) {
      if (file is File && file.path.endsWith('.pdf')) {
        final bytes = file.readAsBytesSync();
        try {
          final document = sf.PdfDocument(inputBytes: bytes);
          sb.writeln('=========================================');
          sb.writeln('File: ${file.path.split(Platform.pathSeparator).last}');
          sb.writeln('=========================================');
          final form = document.form;
          sb.writeln('Total fields: ${form.fields.count}');
          for (var i = 0; i < form.fields.count; i++) {
            final field = form.fields[i];
            String typeStr = field.runtimeType.toString();
            sb.writeln('  - Name: "${field.name}" | Type: $typeStr');
          }
          document.dispose();
        } catch (e) {
          sb.writeln('Error reading ${file.path}: $e');
        }
      }
    }

    final outputFile = File('C:\\Users\\hecte\\AndroidStudioProjects\\flockkeeper\\test\\pdf_fields_dump.txt');
    outputFile.writeAsStringSync(sb.toString());
  });
}
