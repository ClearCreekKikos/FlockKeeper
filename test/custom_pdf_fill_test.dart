import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flockkeeper/data/models/animal_model.dart';
import 'package:flockkeeper/data/models/weight_record_model.dart';
import 'package:flockkeeper/features/export/services/pdf_export_service.dart';
import 'package:flockkeeper/data/repositories/animal_repository.dart';
import 'package:flockkeeper/data/repositories/weight_repository.dart';
import 'package:flockkeeper/data/repositories/health_repository.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class StubAnimalRepository extends AnimalRepository {
  @override
  Future<Animal?> getAnimalById(int id) async => null;
}

class StubWeightRepository extends WeightRepository {
  @override
  Future<List<WeightRecord>> getWeightRecordsForAnimal(int animalId) async => [];
}

class StubHealthRepository extends HealthRepository {}

void main() {
  test('generateCustomPdfForm fills custom PDF matching fields without crashing', () async {
    final animal = Animal(
      id: 1,
      name: 'Test Animal',
      earTag: 'TAG-123',
      tattoo: 'TAT-456',
      dob: DateTime(2026, 1, 1),
      sex: Sex.buck,
      breed: 'Kiko',
      status: AnimalStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final pdfExportService = PdfExportService(
      animalRepo: StubAnimalRepository(),
      weightRepo: StubWeightRepository(),
      healthRepo: StubHealthRepository(),
    );

    // Use one of the existing PDF forms as a test template file
    final testPdfFile = File('forms/NKR DNA Request Form 050126 (1).pdf');
    expect(testPdfFile.existsSync(), true);

    final settings = {
      'farm_name': 'My Ranch',
      'owner_name': 'John Doe',
      'farm_phone': '123-456-7890',
    };

    final filledBytes = await pdfExportService.generateCustomPdfForm(
      templatePath: testPdfFile.path,
      animal: animal,
      settings: settings,
    );

    expect(filledBytes, isNotEmpty);

    // Read the filled PDF to check that it parses successfully
    final doc = sf.PdfDocument(inputBytes: filledBytes);
    expect(doc.form.fields.count, 0); // Flattened form should have 0 interactive fields
    doc.dispose();
  });
}
