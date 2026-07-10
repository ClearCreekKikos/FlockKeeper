// lib/features/export/services/pdf_export_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../../data/models/animal_model.dart';
import '../../../data/models/weight_record_model.dart';
import '../../../data/repositories/animal_repository.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../../data/repositories/health_repository.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/utils/path_resolver.dart';

class PdfExportService {
  final AnimalRepository animalRepo;
  final WeightRepository weightRepo;
  final HealthRepository healthRepo;

  PdfExportService({
    required this.animalRepo,
    required this.weightRepo,
    required this.healthRepo,
  });

  Future<Uint8List> generateBuyerCertificate({
    required Animal animal,
    required Map<String, String> settings,
    PdfPageFormat pageFormat = PdfPageFormat.letter,
    bool includeBillOfSale = false,
    String? buyerName,
    String? buyerAddress,
    String? buyerPhone,
    double? agreedPrice,
    String? billOfSalePhotoPath,
  }) async {
    final pdf = pw.Document();
    final titleFont = await PdfGoogleFonts.arvoBold();

    // 1. Fetch related data
    final weights = await weightRepo.getWeightRecordsForAnimal(animal.id!);
    final healthRecords = await healthRepo.getHealthRecordsForAnimal(animal.id!);

    // Fetch parent details
    Animal? sireRecord;
    Animal? damRecord;
    if (animal.sireId != null) {
      sireRecord = await animalRepo.getAnimalById(animal.sireId!);
    }
    if (animal.damId != null) {
      damRecord = await animalRepo.getAnimalById(animal.damId!);
    }

    // Fetch grandparent details for pedigree tree
    String patGrandsire = 'Unknown';
    String? patGrandsireReg;
    String patGranddam = 'Unknown';
    String? patGranddamReg;
    String matGrandsire = 'Unknown';
    String? matGrandsireReg;
    String matGranddam = 'Unknown';
    String? matGranddamReg;

    if (sireRecord != null) {
      if (sireRecord.sireName != null && sireRecord.sireName!.isNotEmpty) {
        patGrandsire = sireRecord.sireName!;
        patGrandsireReg = sireRecord.sireRegNumber;
      } else if (sireRecord.sireId != null) {
        final gSire = await animalRepo.getAnimalById(sireRecord.sireId!);
        if (gSire != null) {
          patGrandsire = gSire.name;
          patGrandsireReg = gSire.nkrRegNumber;
        }
      }

      if (sireRecord.damName != null && sireRecord.damName!.isNotEmpty) {
        patGranddam = sireRecord.damName!;
        patGranddamReg = sireRecord.damRegNumber;
      } else if (sireRecord.damId != null) {
        final gDam = await animalRepo.getAnimalById(sireRecord.damId!);
        if (gDam != null) {
          patGranddam = gDam.name;
          patGranddamReg = gDam.nkrRegNumber;
        }
      }
    }

    if (damRecord != null) {
      if (damRecord.sireName != null && damRecord.sireName!.isNotEmpty) {
        matGrandsire = damRecord.sireName!;
        matGrandsireReg = damRecord.sireRegNumber;
      } else if (damRecord.sireId != null) {
        final gSire = await animalRepo.getAnimalById(damRecord.sireId!);
        if (gSire != null) {
          matGrandsire = gSire.name;
          matGrandsireReg = gSire.nkrRegNumber;
        }
      }

      if (damRecord.damName != null && damRecord.damName!.isNotEmpty) {
        matGranddam = damRecord.damName!;
        matGranddamReg = damRecord.damRegNumber;
      } else if (damRecord.damId != null) {
        final gDam = await animalRepo.getAnimalById(damRecord.damId!);
        if (gDam != null) {
          matGranddam = gDam.name;
          matGranddamReg = gDam.nkrRegNumber;
        }
      }
    }

    // Calculate performance stats
    final double birthWeight = animal.birthWeightLbs ?? 0.0;
    double latestWeight = 0.0;
    if (weights.isNotEmpty) {
      latestWeight = weights.first.weightLbs;
    }

    double lifetimeADG = 0.0;
    if (weights.length >= 2 && animal.dob != null) {
      final sorted = List<WeightRecord>.from(weights)
        ..sort((a, b) => a.weighDate.compareTo(b.weighDate));
      final first = sorted.first;
      final last = sorted.last;
      final days = last.weighDate.difference(first.weighDate).inDays;
      if (days > 0) {
        lifetimeADG = (last.weightLbs - first.weightLbs) / days;
      }
    }

    // Load logo if exists
    pw.MemoryImage? logoImage;
    final logoPath = PathResolver.resolvePath(settings['farm_logo_path']);
    if (logoPath != null && File(logoPath).existsSync()) {
      try {
        logoImage = pw.MemoryImage(File(logoPath).readAsBytesSync());
      } catch (e) {
        debugPrint('Failed to load logo image from $logoPath: $e');
        // Continue without logo if loading fails
      }
    }

    // Load goat photo if provided
    pw.MemoryImage? goatImage;
    if (billOfSalePhotoPath != null) {
      final resolvedPhotoPath = PathResolver.resolvePath(billOfSalePhotoPath);
      if (resolvedPhotoPath != null && File(resolvedPhotoPath).existsSync()) {
        try {
          goatImage = pw.MemoryImage(File(resolvedPhotoPath).readAsBytesSync());
        } catch (e) {
          debugPrint('Failed to load goat photo from $resolvedPhotoPath: $e');
        }
      }
    }

    final farmName = settings['farm_name'] ?? 'FlockKeeper Farm';
    final ownerName = settings['owner_name'] ?? '';

    // Page formatting & layout
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // ─── Header Section ──────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        farmName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 22,
                          font: titleFont,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      if (ownerName.isNotEmpty ||
                          (settings['farm_address']?.isNotEmpty == true) ||
                          (settings['farm_phone']?.isNotEmpty == true))
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
                          child: pw.Text(
                            [
                              if (ownerName.isNotEmpty) 'Owner: $ownerName',
                              if (settings['farm_address']?.isNotEmpty == true) 'Address: ${settings['farm_address']}',
                              if (settings['farm_phone']?.isNotEmpty == true) 'Phone: ${settings['farm_phone']}',
                            ].join('  |  '),
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ),
                      pw.Text(
                        'Official Health & Performance Certificate',
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                if (logoImage != null)
                  pw.Container(
                    width: 65,
                    height: 65,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  )
                else
                  pw.Container(
                    width: 65,
                    height: 65,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 1),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'FlockKeeper',
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.blue900, thickness: 2),
            pw.SizedBox(height: 12),

            // ─── Section 1: Profile Details ──────────────────────────────────
            pw.Text(
              'ANIMAL PROFILE',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  children: [
                    _buildCell('Registered Name', animal.name, isBold: true),
                    _buildCell('Date of Birth', animal.dob != null ? DateFormat.yMMMd().format(animal.dob!) : 'N/A'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCell('NKR Reg Number', animal.nkrRegNumber ?? 'Unregistered'),
                    _buildCell('Sex', animal.sexDisplay),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCell('Ear Tag', animal.earTag ?? 'N/A'),
                    _buildCell('Tattoo', animal.tattoo ?? 'N/A'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCell('RFID Tag Number', animal.rfidTag ?? 'N/A'),
                    _buildCell('USDA Scrapie Tag', animal.scrapieTag ?? 'N/A'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCell('Breed', animal.breed),
                    _buildCell('Herd Book', animal.herdBook ?? animal.breedType ?? 'N/A'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCell('Color & Markings', animal.markings ?? 'N/A'),
                    _buildCell('UC-Davis VGL#', animal.vglId ?? 'N/A'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCell('Status', animal.statusDisplay),
                    _buildCell('N/A', 'N/A'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // ─── Section 2: Pedigree Tree ────────────────────────────────────
            pw.Text(
              'PEDIGREE ANCESTRY',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(1), // Parents
                1: pw.FlexColumnWidth(1), // Grandparents
              },
              children: [
                // Sire Row
                pw.TableRow(
                  children: [
                    _buildPedigreeCell('SIRE (FATHER)', animal.sireName ?? 'Unknown Sire', animal.sireRegNumber),
                    _buildPedigreeCell('PATERNAL GRANDSIRE', patGrandsire, patGrandsireReg),
                  ],
                ),
                // Sire Sub-Row (Granddam)
                pw.TableRow(
                  children: [
                    pw.Container(), // empty cell to align
                    _buildPedigreeCell('PATERNAL GRANDDAM', patGranddam, patGranddamReg),
                  ],
                ),
                // Dam Row
                pw.TableRow(
                  children: [
                    _buildPedigreeCell('DAM (MOTHER)', animal.damName ?? 'Unknown Dam', animal.damRegNumber),
                    _buildPedigreeCell('MATERNAL GRANDSIRE', matGrandsire, matGrandsireReg),
                  ],
                ),
                // Dam Sub-Row (Granddam)
                pw.TableRow(
                  children: [
                    pw.Container(), // empty cell to align
                    _buildPedigreeCell('MATERNAL GRANDDAM', matGranddam, matGranddamReg),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // ─── Section 3: Performance & Growth ─────────────────────────────
            pw.Text(
              'GROWTH & PERFORMANCE METRICS',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildMetricCard('Birth Weight', birthWeight > 0 ? '$birthWeight lbs' : 'N/A'),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildMetricCard('Latest Weight', latestWeight > 0 ? '$latestWeight lbs' : 'N/A'),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildMetricCard('Lifetime ADG', lifetimeADG > 0 ? '${lifetimeADG.toStringAsFixed(3)} lbs/day' : 'N/A'),
                ),
              ],
            ),

            if (weights.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Weight Logs:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildHeaderCell('Date'),
                      _buildHeaderCell('Weight (lbs)'),
                    ],
                  ),
                  ...weights.take(5).map((w) {
                    return pw.TableRow(
                      children: [
                        _buildCellText(DateFormat.yMMMd().format(w.weighDate)),
                        _buildCellText('${w.weightLbs} lbs'),
                      ],
                    );
                  }),
                ],
              ),
              if (weights.length > 5)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4.0),
                  child: pw.Text('* Showing latest 5 weight records. Total logs available: ${weights.length}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ),
            ],
            pw.SizedBox(height: 18),

            // ─── Section 4: Health Log ───────────────────────────────────────
            pw.Text(
              'HEALTH & MEDICAL LOG',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 6),
            if (healthRecords.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text('No health issues, treatments, or vaccinations logged for this animal.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildHeaderCell('Date'),
                      _buildHeaderCell('Event/Type'),
                      _buildHeaderCell('Treatment & Dosage'),
                      _buildHeaderCell('FAMACHA / FEC'),
                    ],
                  ),
                  ...healthRecords.take(6).map((h) {
                    final treatmentStr = [
                      if (h.treatment != null && h.treatment!.isNotEmpty) h.treatment,
                      if (h.dosage != null && h.dosage!.isNotEmpty) h.dosage,
                    ].join(' - ');

                    final scores = [
                      if (h.famachaScore != null) 'FAM: ${h.famachaScore}',
                      if (h.bcsScore != null) 'BCS: ${h.bcsScore}',
                    ].join(' • ');

                    return pw.TableRow(
                      children: [
                        _buildCellText(DateFormat.yMMMd().format(h.recordDate)),
                        _buildCellText(h.recordType.name.toUpperCase()),
                        _buildCellText(treatmentStr.isNotEmpty ? treatmentStr : 'None'),
                        _buildCellText(scores.isNotEmpty ? scores : 'N/A'),
                      ],
                    );
                  }),
                ],
              ),
            if (healthRecords.length > 6)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4.0),
                child: pw.Text('* Showing latest 6 health records.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ),

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated via FlockKeeper Herd Manager on ${DateFormat.yMMMd().format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Signature of Owner: ________________________',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
          ];
        },
      ),
    );

    if (includeBillOfSale) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Bill of Sale Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'BILL OF SALE',
                      style: pw.TextStyle(
                        fontSize: 22,
                        font: titleFont,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    if (logoImage != null)
                      pw.Container(
                        width: 50,
                        height: 50,
                        child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                      ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'TRANSFER OF LIVESTOCK OWNERSHIP',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.blue900, thickness: 1.5),
                pw.SizedBox(height: 12),

                // Seller & Buyer Section
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('SELLER (RANCH)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.SizedBox(height: 4),
                          pw.Text(farmName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          if (ownerName.isNotEmpty) pw.Text('Owner: $ownerName', style: const pw.TextStyle(fontSize: 9)),
                          if (settings['farm_address']?.isNotEmpty == true) pw.Text(settings['farm_address']!, style: const pw.TextStyle(fontSize: 9)),
                          if (settings['farm_phone']?.isNotEmpty == true) pw.Text('Phone: ${settings['farm_phone']!}', style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BUYER', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.SizedBox(height: 4),
                          pw.Text(buyerName?.isNotEmpty == true ? buyerName! : '________________________', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.SizedBox(height: 2),
                          pw.Text('Address: ${buyerAddress?.isNotEmpty == true ? buyerAddress! : "________________________"}', style: const pw.TextStyle(fontSize: 9)),
                          pw.SizedBox(height: 2),
                          pw.Text('Phone: ${buyerPhone?.isNotEmpty == true ? buyerPhone! : "________________________"}', style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Animal Description
                pw.Text('ANIMAL DESCRIPTION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 6),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                        children: [
                          pw.TableRow(
                            children: [
                              _buildCell('Registered Name', animal.name, isBold: true),
                              _buildCell('Date of Birth', animal.dob != null ? DateFormat.yMMMd().format(animal.dob!) : 'N/A'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildCell('NKR Reg Number', animal.nkrRegNumber ?? 'Unregistered'),
                              _buildCell('Sex', animal.sexDisplay),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildCell('Ear Tag', animal.earTag ?? 'N/A'),
                              _buildCell('Scrapie Tag', animal.scrapieTag ?? 'N/A'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildCell('Tattoo', animal.tattoo ?? 'N/A'),
                              _buildCell('UC-Davis VGL#', animal.vglId ?? 'N/A'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (goatImage != null) ...[
                      pw.SizedBox(width: 16),
                      pw.Container(
                        width: 90,
                        height: 90,
                        decoration: const pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 6,
                          verticalRadius: 6,
                          child: pw.Image(goatImage, fit: pw.BoxFit.cover),
                        ),
                      ),
                    ],
                  ],
                ),
                pw.SizedBox(height: 20),

                // Transaction Details
                pw.Text('TRANSACTION DETAILS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Agreed Purchase Price', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800)),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            agreedPrice != null ? '\$${agreedPrice.toStringAsFixed(2)}' : '________________________',
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Date of Transfer', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800)),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            DateFormat.yMMMd().format(DateTime.now()),
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Ownership terms
                pw.Text(
                  'The Seller warrants that they are the lawful owner of the animal described above, free of all encumbrances. The Seller hereby transfers all rights, title, and interest in said animal to the Buyer. The animal is sold in "AS IS" condition. No other warranties or guarantees are expressed or implied by the Seller. Purchase price includes Registration, DNA Parentage Verification and Registry Ownership Transfer Fee.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 40),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Divider(color: PdfColors.grey400, thickness: 1),
                          pw.SizedBox(height: 4),
                          pw.Text('Seller Signature', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text(farmName, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 48),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Divider(color: PdfColors.grey400, thickness: 1),
                          pw.SizedBox(height: 4),
                          pw.Text('Buyer Signature', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text(buyerName?.isNotEmpty == true ? buyerName! : 'Buyer Name', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  // Cell builders
  pw.Widget _buildCell(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPedigreeCell(String role, String name, String? reg) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      height: 40,
      alignment: pw.Alignment.centerLeft,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(role, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Text(
            name,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            maxLines: 1,
          ),
          if (reg != null && reg.isNotEmpty)
            pw.Text('Reg: $reg', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
      ),
    );
  }

  pw.Widget _buildCellText(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
      ),
    );
  }

  pw.Widget _buildMetricCard(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
          ),
        ],
      ),
    );
  }

  // ─── NKR Interactive PDF Forms filling ────────────────────────────────────

  String _getWeightNearAgeDays(List<WeightRecord> records, DateTime? dob, int targetDays, {int tolerance = 30}) {
    if (dob == null || records.isEmpty) return '';
    double closestDiff = double.infinity;
    WeightRecord? closestRecord;
    for (final r in records) {
      final ageInDays = r.weighDate.difference(dob).inDays;
      final diff = (ageInDays - targetDays).abs();
      if (diff < closestDiff && diff <= tolerance) {
        closestDiff = diff.toDouble();
        closestRecord = r;
      }
    }
    return closestRecord != null ? closestRecord.weightLbs.toStringAsFixed(1) : '';
  }

  Future<Uint8List> generateNkrDnaForm({
    required Animal animal,
    required String ownerName,
    required String ownerPhone,
    required String ownerEmail,
    required String ownerAddress,
    required String ownerClientId,
    required String ownerPrefix,
  }) async {
    final data = await rootBundle.load('forms/NKR DNA Request Form 050126 (1).pdf');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final document = sf.PdfDocument(inputBytes: bytes);
    final form = document.form;

    final fieldMap = <String, sf.PdfField>{};
    for (var i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      if (field.name != null) {
        fieldMap[field.name!] = field;
      }
    }

    void setField(String name, String value) {
      final field = fieldMap[name];
      if (field is sf.PdfTextBoxField) {
        field.text = value;
      }
    }

    // PART A. Animal info
    setField('Text65', animal.name);
    setField('Text66', animal.dob != null ? DateFormat('MM/dd/yyyy').format(animal.dob!) : '');
    setField('Text67', animal.tattoo ?? '');
    setField('Text68', animal.tattoo ?? ''); // Right Ear Tattoo default
    setField('Text70', animal.rfidTag ?? ''); // Microchip
    if (animal.sex == Sex.buck) {
      setField('Text71', 'X');
    } else if (animal.sex == Sex.doe) {
      setField('Text72', 'X');
    }
    setField('Text74', animal.nkrRegNumber ?? '');

    // PART B. Owner info
    setField('Text75', ownerName);
    setField('Text76', ownerPhone);
    setField('Text77', ownerAddress);
    setField('Text78', ownerClientId);
    setField('Text79', ownerPrefix);
    setField('Text80', ownerEmail);

    // PART C. Parents
    setField('Text81', animal.sireRegNumber ?? '');
    setField('Text83', animal.damRegNumber ?? '');
    setField('Text85', DateFormat('MM/dd/yyyy').format(DateTime.now()));

    document.form.flattenAllFields();
    final List<int> filledBytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(filledBytes);
  }

  Future<Uint8List> generateNkrRegApp({
    required Animal animal,
    required String ownerName,
    required String ownerPhone,
    required String ownerEmail,
    required String ownerAddress,
    required String ownerClientId,
    required String ownerPrefix,
    required String buyerName,
    required String buyerPhone,
    required String buyerEmail,
    required String buyerAddress,
    required String buyerClientId,
    required String buyerPrefix,
    required String birthType,
    required String sireVglId,
    required String damVglId,
    required bool hairSampleAttached,
  }) async {
    final data = await rootBundle.load('forms/NKR Registration Application 050126 (1).pdf');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final document = sf.PdfDocument(inputBytes: bytes);
    final form = document.form;

    final fieldMap = <String, sf.PdfField>{};
    for (var i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      if (field.name != null) {
        fieldMap[field.name!] = field;
      }
    }

    void setField(String name, String value) {
      final field = fieldMap[name];
      if (field is sf.PdfTextBoxField) {
        field.text = value;
      }
    }

    void setCheckbox(String name, bool checked) {
      final field = fieldMap[name];
      if (field is sf.PdfCheckBoxField) {
        field.isChecked = checked;
      }
    }

    // Owner details
    setField('Name', ownerName);
    setField('Phone', ownerPhone);
    setField('Mailing address', ownerAddress);
    setField('NKR Client', ownerClientId);
    setField('NKR Herd Prefix', ownerPrefix);
    setField('Email', ownerEmail);

    // Sex check
    setCheckbox('Buck', animal.sex == Sex.buck);
    setCheckbox('Doe', animal.sex == Sex.doe);

    // Breed classification checkboxes
    final classification = animal.herdBook ?? animal.breedType ?? '';
    final breedTypeLower = classification.toLowerCase();
    setCheckbox('100 New Zealand', breedTypeLower.contains('100') || breedTypeLower.contains('new zealand'));
    setCheckbox('Purebred', breedTypeLower.contains('purebred'));
    setCheckbox('Percentage', breedTypeLower.contains('percentage'));

    // Animal Name
    setField('Name of Animal Maximum 30 charactersMust include Herd Prefix', animal.name);
    setField('Birth Date', animal.dob != null ? DateFormat('MM/dd/yyyy').format(animal.dob!) : '');
    setField('Tag', animal.earTag ?? '');
    setField('Tattoos R Ear', animal.tattoo ?? '');
    setField('Microchip Number', animal.rfidTag ?? '');

    // Birth Type Checkboxes
    setCheckbox('Birth Number Single', birthType.toLowerCase() == 'single');
    setCheckbox('Twin', birthType.toLowerCase() == 'twin');
    setCheckbox('Triplet', birthType.toLowerCase() == 'triplet');
    setCheckbox('Quad', birthType.toLowerCase() == 'quad');
    setCheckbox('Quint', birthType.toLowerCase() == 'quint');

    setField('Color', animal.color ?? '');

    // Parents
    Animal? sireRecord;
    Animal? damRecord;
    if (animal.sireId != null) {
      sireRecord = await animalRepo.getAnimalById(animal.sireId!);
    }
    if (animal.damId != null) {
      damRecord = await animalRepo.getAnimalById(animal.damId!);
    }

    final sireVgl = sireVglId.isNotEmpty ? sireVglId : (sireRecord?.vglId ?? '');
    final damVgl = damVglId.isNotEmpty ? damVglId : (damRecord?.vglId ?? '');

    setField('Sires Reg', animal.sireRegNumber ?? '');
    setField('OPTIONAL  Sires UC Davis VGL', sireVgl);
    setField('Dams Reg', animal.damRegNumber ?? '');
    setField('OPTIONAL Dams UCDavis VGL', damVgl);

    // Performance Weights
    setField('OPTIONAL  Birth Weight', animal.birthWeightLbs?.toString() ?? '');
    
    final weights = await weightRepo.getWeightRecordsForAnimal(animal.id!);
    setField('90Day Wt', _getWeightNearAgeDays(weights, animal.dob, 90));
    setField('150Day Wt', _getWeightNearAgeDays(weights, animal.dob, 150));
    setField('1Year Wt', _getWeightNearAgeDays(weights, animal.dob, 365, tolerance: 60));

    // Hair sample checkboxes
    setCheckbox('Hair sample for DNA testing is attached Yes', hairSampleAttached);
    setCheckbox('No', !hairSampleAttached);

    // Buyer details
    setField('Buyer', buyerName);
    setField('Phone_2', buyerPhone);
    setField('Buyers Mailing Address', buyerAddress);
    setField('Buyers NKR Client', buyerClientId);
    setField('Buyers NKR Herd Prefix', buyerPrefix);
    setField('Buyers Email', buyerEmail);
    setField('Date of Sale', DateFormat('MM/dd/yyyy').format(DateTime.now()));
    setField('Date', DateFormat('MM/dd/yyyy').format(DateTime.now()));

    document.form.flattenAllFields();
    final List<int> filledBytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(filledBytes);
  }

  Future<Uint8List> generateNkrTransfer({
    required Animal animal,
    required String ownerName,
    required String ownerPhone,
    required String ownerEmail,
    required String ownerAddress,
    required String ownerClientId,
    required String ownerPrefix,
    required String buyerName,
    required String buyerPhone,
    required String buyerEmail,
    required String buyerAddress,
    required String buyerClientId,
    required String buyerPrefix,
  }) async {
    final data = await rootBundle.load('forms/NKR transfer form-050126 (1).pdf');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final document = sf.PdfDocument(inputBytes: bytes);
    final form = document.form;

    final fieldMap = <String, sf.PdfField>{};
    for (var i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      if (field.name != null) {
        fieldMap[field.name!] = field;
      }
    }

    void setField(String name, String value) {
      final field = fieldMap[name];
      if (field is sf.PdfTextBoxField) {
        field.text = value;
      }
    }

    // Seller (Name, Phone, Mailing address, NKR Client, NKR Herd Prefix, Email)
    setField('Name', ownerName);
    setField('Phone', ownerPhone);
    setField('Mailing address', ownerAddress);
    setField('NKR Client', ownerClientId);
    setField('NKR Herd Prefix', ownerPrefix);
    setField('Email', ownerEmail);

    // Buyer (Name_2, Phone_2, Mailing address_2, NKR Client_2, NKR Herd Prefix_2, Email_2)
    setField('Name_2', buyerName);
    setField('Phone_2', buyerPhone);
    setField('Mailing address_2', buyerAddress);
    setField('NKR Client_2', buyerClientId);
    setField('NKR Herd Prefix_2', buyerPrefix);
    setField('Email_2', buyerEmail);

    // Row 1
    setField('Animals NameRow1', animal.name);
    setField('NKR Registration NoRow1', animal.nkrRegNumber ?? '');
    setField('Date of BirthRow1', animal.dob != null ? DateFormat('MM/dd/yyyy').format(animal.dob!) : '');

    setField('Date of Sale', DateFormat('MM/dd/yyyy').format(DateTime.now()));

    document.form.flattenAllFields();
    final List<int> filledBytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(filledBytes);
  }

  Future<Uint8List> generateNkrDualRegister({
    required Animal animal,
    required String ownerName,
    required String ownerPhone,
    required String ownerEmail,
    required String ownerAddress,
    required String ownerClientId,
    required String ownerPrefix,
  }) async {
    final data = await rootBundle.load('forms/NKR Dual Register Form 050126.pdf');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final document = sf.PdfDocument(inputBytes: bytes);
    final form = document.form;

    final fieldMap = <String, sf.PdfField>{};
    for (var i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      if (field.name != null) {
        fieldMap[field.name!] = field;
      }
    }

    void setField(String name, String value) {
      final field = fieldMap[name];
      if (field is sf.PdfTextBoxField) {
        field.text = value;
      }
    }

    setField('Name', ownerName);
    setField('Phone', ownerPhone);
    setField('Address', ownerAddress);
    setField('Client #', ownerClientId);
    setField('Prefix', ownerPrefix);
    setField('E-mail', ownerEmail);

    // Row 1
    setField('Animals NameRow1', animal.name);
    setField('Registration NoRow1', animal.nkrRegNumber ?? '');
    setField('ColorRow1', animal.color ?? '');
    setField('Date', DateFormat('MM/dd/yyyy').format(DateTime.now()));

    document.form.flattenAllFields();
    final List<int> filledBytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(filledBytes);
  }

  Future<Uint8List> generateCustomPdfForm({
    required String templatePath,
    required Animal animal,
    required Map<String, String> settings,
  }) async {
    final file = File(templatePath);
    if (!await file.exists()) {
      throw Exception('Template file not found at $templatePath');
    }
    final bytes = await file.readAsBytes();
    final document = sf.PdfDocument(inputBytes: bytes);
    final form = document.form;

    final weights = await weightRepo.getWeightRecordsForAnimal(animal.id!);

    // Loop through all fields and perform smart mapping
    for (var i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      final name = field.name?.toLowerCase() ?? '';
      if (name.isEmpty) continue;

      if (field is sf.PdfTextBoxField) {
        // First check parent-specific fields to avoid clashes
        if (name.contains('sire')) {
          if (name.contains('reg') || name.contains('no') || name.contains('num')) {
            field.text = animal.sireRegNumber ?? '';
          } else if (name.contains('name')) {
            field.text = animal.sireName ?? '';
          }
        } else if (name.contains('dam')) {
          if (name.contains('reg') || name.contains('no') || name.contains('num')) {
            field.text = animal.damRegNumber ?? '';
          } else if (name.contains('name')) {
            field.text = animal.damName ?? '';
          }
        }
        // Then check buyer fields to prevent clashes with seller/owner
        else if (name.contains('buyer') || name.contains('purchaser') || name.contains('_2') || name.endsWith('2')) {
          if (name.contains('name')) {
            field.text = settings['buyer_name'] ?? '';
          } else if (name.contains('phone') || name.contains('tel')) {
            field.text = settings['buyer_phone'] ?? '';
          } else if (name.contains('email') || name.contains('mail')) {
            field.text = settings['buyer_email'] ?? '';
          } else if (name.contains('address') || name.contains('street') || name.contains('mailing')) {
            field.text = settings['buyer_address'] ?? '';
          } else if (name.contains('client') || name.contains('member') || name.contains('prefix') || name.contains('id') || name.contains('#')) {
            if (name.contains('prefix')) {
              field.text = settings['buyer_prefix'] ?? '';
            } else {
              field.text = settings['buyer_client_id'] ?? '';
            }
          }
        }
        // Seller/Owner/Ranch details
        else if (name.contains('seller') || name.contains('owner') || name.contains('applicant') || name.contains('breeder')) {
          if (name.contains('name')) {
            field.text = settings['owner_name'] ?? settings['farm_name'] ?? '';
          } else if (name.contains('phone') || name.contains('tel')) {
            field.text = settings['farm_phone'] ?? '';
          } else if (name.contains('email') || name.contains('mail')) {
            field.text = settings['farm_email'] ?? '';
          } else if (name.contains('address') || name.contains('street') || name.contains('mailing')) {
            field.text = settings['farm_address'] ?? '';
          } else if (name.contains('client') || name.contains('member') || name.contains('prefix') || name.contains('id') || name.contains('#')) {
            if (name.contains('prefix')) {
              field.text = settings['nkr_herd_prefix'] ?? '';
            } else {
              field.text = settings['nkr_client_id'] ?? '';
            }
          }
        }
        // Animal details
        else if (name.contains('animal') || name.contains('goat') || name.contains('kid')) {
          if (name.contains('name')) {
            field.text = animal.name;
          } else if (name.contains('tag') || name.contains('ear')) {
            field.text = animal.earTag ?? '';
          } else if (name.contains('scrapie')) {
            field.text = animal.scrapieTag ?? '';
          } else if (name.contains('tattoo')) {
            field.text = animal.tattoo ?? '';
          } else if (name.contains('microchip') || name.contains('rfid') || name.contains('chip')) {
            field.text = animal.rfidTag ?? '';
          } else if (name.contains('color') || name.contains('marking')) {
            field.text = [animal.color, animal.markings].where((e) => e != null && e.isNotEmpty).join(', ');
          } else if (name.contains('breed')) {
            field.text = animal.breed;
          } else if (name.contains('dob') || name.contains('birth') || name.contains('born')) {
            field.text = animal.dob != null ? DateFormat('MM/dd/yyyy').format(animal.dob!) : '';
          } else if (name.contains('reg') || name.contains('no') || name.contains('num')) {
            field.text = animal.nkrRegNumber ?? '';
          }
        }
        // General fallbacks if field name is simple (like "name", "phone", "email", "address", "date", "tattoo", "tag", "sex")
        else if (name == 'name' || name == 'farm name' || name == 'ranch name') {
          field.text = settings['farm_name'] ?? '';
        } else if (name == 'phone' || name == 'telephone' || name == 'tel') {
          field.text = settings['farm_phone'] ?? '';
        } else if (name == 'email' || name == 'e-mail') {
          field.text = settings['farm_email'] ?? '';
        } else if (name == 'address' || name == 'street' || name == 'city' || name == 'state' || name == 'zip') {
          field.text = settings['farm_address'] ?? '';
        } else if (name == 'date' || name == 'date of sale' || name == 'sale date') {
          field.text = DateFormat('MM/dd/yyyy').format(DateTime.now());
        } else if (name == 'tattoo' || name == 'tattoos' || name == 'tattoo number') {
          field.text = animal.tattoo ?? '';
        } else if (name == 'tag' || name == 'ear tag' || name == 'tag number' || name == 'tag #') {
          field.text = animal.earTag ?? '';
        } else if (name == 'scrapie' || name == 'scrapie tag') {
          field.text = animal.scrapieTag ?? '';
        } else if (name == 'microchip' || name == 'rfid' || name == 'chip') {
          field.text = animal.rfidTag ?? '';
        } else if (name == 'color' || name == 'color/markings') {
          field.text = [animal.color, animal.markings].where((e) => e != null && e.isNotEmpty).join(', ');
        } else if (name == 'breed') {
          field.text = animal.breed;
        } else if (name == 'dob' || name == 'birth date' || name == 'date of birth') {
          field.text = animal.dob != null ? DateFormat('MM/dd/yyyy').format(animal.dob!) : '';
        } else if (name == 'sire' || name == 'sire reg' || name == 'sire registration') {
          field.text = animal.sireRegNumber ?? '';
        } else if (name == 'dam' || name == 'dam reg' || name == 'dam registration') {
          field.text = animal.damRegNumber ?? '';
        } else if (name == 'birth weight' || name == 'birth wt') {
          field.text = animal.birthWeightLbs?.toString() ?? '';
        } else if (name == '90day wt' || name == '90 day wt' || name == '90-day wt') {
          field.text = _getWeightNearAgeDays(weights, animal.dob, 90);
        } else if (name == '150day wt' || name == '150 day wt' || name == '150-day wt') {
          field.text = _getWeightNearAgeDays(weights, animal.dob, 150);
        } else if (name == '1year wt' || name == '1 year wt' || name == '1-year wt') {
          field.text = _getWeightNearAgeDays(weights, animal.dob, 365, tolerance: 60);
        }
      } else if (field is sf.PdfCheckBoxField) {
        if (name.contains('buck') || name.contains('male') || name == 'm') {
          field.isChecked = animal.sex == Sex.buck;
        } else if (name.contains('doe') || name.contains('female') || name == 'f') {
          field.isChecked = animal.sex == Sex.doe;
        } else if (name.contains('wether')) {
          field.isChecked = animal.sex == Sex.wether;
        }
      }
    }

    document.form.flattenAllFields();
    final List<int> filledBytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(filledBytes);
  }

  Future<Uint8List> mergePdfDocuments(List<Uint8List> documents) async {
    final sf.PdfDocument finalDoc = sf.PdfDocument();
    
    for (final docBytes in documents) {
      final sf.PdfDocument loadedDoc = sf.PdfDocument(inputBytes: docBytes);
      for (int i = 0; i < loadedDoc.pages.count; i++) {
        final sf.PdfPage loadedPage = loadedDoc.pages[i];
        // Create a new section explicitly to ensure page settings/margins are not inherited/corrupted
        final sf.PdfSection section = finalDoc.sections!.add();
        section.pageSettings.size = loadedPage.size;
        section.pageSettings.margins.all = 0;
        final sf.PdfPage page = section.pages.add();
        final sf.PdfTemplate template = loadedPage.createTemplate();
        page.graphics.drawPdfTemplate(template, Offset.zero, loadedPage.size);
      }
      loadedDoc.dispose();
    }
    final List<int> mergedBytes = finalDoc.saveSync();
    finalDoc.dispose();
    return Uint8List.fromList(mergedBytes);
  }
}

// Provider definition
final pdfExportServiceProvider = Provider<PdfExportService>((ref) {
  return PdfExportService(
    animalRepo: ref.read(animalRepositoryProvider),
    weightRepo: ref.read(weightRepositoryProvider),
    healthRepo: ref.read(healthRepositoryProvider),
  );
});
