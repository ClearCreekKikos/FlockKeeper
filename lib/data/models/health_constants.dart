import 'health_record_model.dart';

class HealthConstants {
  static const Map<HealthRecordType, List<String>> categoryProducts = {
    HealthRecordType.vaccination: [
      'CD&T',
      'Covexin 8',
      'Tetanus Antitoxin',
      'Rabies',
      'Sore Mouth',
    ],
    HealthRecordType.deworming: [
      'Valbazen (Albendazole)',
      'Safe-Guard (Fenbendazole)',
      'Ivomec Sheep Drench (Ivermectin)',
      'Prohibit Oral Drench (Levamisole)',
      'Cydectin Sheep Drench (Moxidectin)',
      'Rumatel (Morantel) Feed Pre-mix',
    ],
    HealthRecordType.antibiotic: [
      'LA-200 (Oxytetracycline)',
      'Nuflor (Florfenicol)',
      'Penicillin G',
      'Excenel',
      'Draxxin',
    ],
    HealthRecordType.supplement: [
      'Copper Bolus (COWP)',
      'BoSe (Selenium/Vit E)',
      'Vitamin B Complex',
      'Probiotic Paste',
      'Electrolytes',
      'Mineral Block/Loose Mineral',
      'Vitamin A/D',
    ],
    HealthRecordType.labTest: [
      'Blood Sample (CAE/CL/Johnes)',
      'BioPRYN (Pregnancy Test)',
      'Fecal Egg Count (FEC)',
      'Milk Culture',
      'Skin Scrape',
    ],
    HealthRecordType.grooming: [
      'Hoof Trimming',
      'Shearing',
      'Brushing',
      'Bath',
    ],
  };

  static const Map<String, String> recommendedDosages = {
    'CD&T': '2ml SQ',
    'Covexin 8': '2ml SQ',
    'Tetanus Antitoxin': '1500 units SQ',
    'Valbazen (Albendazole)': '2 ml / 25 lb (Benzimidazoles; Oral, 20 mg/kg)',
    'Safe-Guard (Fenbendazole)': '1.1 ml / 25 lb (Benzimidazoles; Oral, 10 mg/kg)',
    'Ivomec Sheep Drench (Ivermectin)': '6 ml / 25 lb (Macrocyclic Lactones; Oral, 0.4 mg/kg)',
    'Prohibit Oral Drench (Levamisole)': '2.7 ml / 25 lb (Imidazothiazoles; Oral, 12 mg/kg)',
    'Cydectin Sheep Drench (Moxidectin)': '4.5 ml / 25 lb (Macrocyclic Lactones; Oral, 0.4 mg/kg)',
    'Rumatel (Morantel) Feed Pre-mix': '45 gm / 100 lb BW (Tetrahydropyrimidines; Oral, 10 mg/kg)',
    'LA-200 (Oxytetracycline)': '1ml per 22 lbs (SQ)',
    'Nuflor (Florfenicol)': '2ml per 100 lbs (SQ)',
    'Penicillin G': '1ml per 30 lbs (IM)',
    'Copper Bolus (COWP)': 'Kids (Over 25 lbs & >5 wks): 2g | Adults (Over 50 lbs & >3 mos): 4g (Oral Capsule)',
    'BoSe (Selenium/Vit E)': '1ml per 40 lbs (SQ)',
    'Vitamin B Complex': '5ml per 100 lbs (SQ/IM)',
    'Probiotic Paste': '5g (Oral)',
  };

  static const Map<String, int> recommendedWithdrawalDays = {
    'Valbazen (Albendazole)': 7,
    'Safe-Guard (Fenbendazole)': 6,
    'Ivomec Sheep Drench (Ivermectin)': 11,
    'Prohibit Oral Drench (Levamisole)': 3,
    'Cydectin Sheep Drench (Moxidectin)': 7,
    'Rumatel (Morantel) Feed Pre-mix': 30,
    'LA-200 (Oxytetracycline)': 28,
    'Nuflor (Florfenicol)': 28,
    'Penicillin G': 15,
    'Draxxin': 18,
    'Excenel': 0,
    'CD&T': 21,
    'Covexin 8': 21,
  };

  static const List<String> illnessTypes = [
    'Pneumonia',
    'Coccidiosis',
    'Bloat',
    'Listeriosis',
    'Polio',
    'Foot Rot',
    'Mastitis',
    'CAE (Caprine Arthritis Encephalitis)',
    'CL (Caseous Lymphadenitis)',
    'Johnes Disease',
    'Pinkeye',
    'Orf (Sore Mouth)',
    'Urinary Calculi',
  ];

  static const List<String> famachaActions = [
    'No Action Taken',
    'Monitor Closely',
    'Fecal Egg Count (FEC) Test',
    'Deworm immediately',
    'Consult Veterinarian',
    'Move to clean pasture',
    'Selective Culling Evaluation',
    'Supplemental protein/nutrition',
    'Schedule Treatment',
  ];

  static const List<String> generalActions = [
    'No Action Taken',
    'Consult Veterinarian',
    'Perform Diagnostic Test',
    'Administer Treatment',
    'Schedule Treatment',
  ];
}