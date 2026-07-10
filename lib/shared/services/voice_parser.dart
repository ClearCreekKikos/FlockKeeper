import '../../../data/models/kidding_record_model.dart';
import '../../../data/models/reminder_model.dart';
import '../../../data/models/pasture_model.dart';
import '../../../data/models/health_record_model.dart';

enum VoiceIntent { kidding, weight, health, note, reminder, pasture, inventory, unknown }

enum InventoryVoiceAction { addStock, useStock, checkStock }

enum PastureVoiceAction { moveAnimal, moveHerd, setStatus, rotate }

class VoiceWeightResult {
  final double weight;
  final String? animalName;
  final String rawText;

  VoiceWeightResult({
    required this.weight,
    this.animalName,
    required this.rawText,
  });

  @override
  String toString() {
    return 'VoiceWeightResult(animal: $animalName, weight: $weight)';
  }
}

class VoiceHealthResult {
  final HealthRecordType type;
  final String treatment;
  final String? dosage;
  final int? famachaScore;
  final double? bcsScore;
  final String? animalName;
  final bool appliesToHerd;
  final String rawText;

  VoiceHealthResult({
    this.type = HealthRecordType.other,
    required this.treatment,
    this.dosage,
    this.famachaScore,
    this.bcsScore,
    this.animalName,
    this.appliesToHerd = false,
    required this.rawText,
  });

  @override
  String toString() {
    return 'VoiceHealthResult(animal: $animalName, herd: $appliesToHerd, type: ${type.name}, '
        'treatment: $treatment, dosage: $dosage, famacha: $famachaScore, bcs: $bcsScore)';
  }
}

class VoiceNoteResult {
  final String noteText;
  final String? animalName;
  final String rawText;

  VoiceNoteResult({
    required this.noteText,
    this.animalName,
    required this.rawText,
  });

  @override
  String toString() {
    return 'VoiceNoteResult(animal: $animalName, note: $noteText)';
  }
}

class VoiceReminderResult {
  final String title;
  final DateTime date;
  final ReminderType type;
  final String? animalName;
  final String rawText;

  VoiceReminderResult({
    required this.title,
    required this.date,
    required this.type,
    this.animalName,
    required this.rawText,
  });

  @override
  String toString() {
    return 'VoiceReminderResult(title: $title, date: $date, type: ${type.name}, animal: $animalName)';
  }
}

class VoicePastureResult {
  final PastureVoiceAction action;
  final String? pastureName;
  final String? animalName;
  final PastureStatus? status;
  final String rawText;

  VoicePastureResult({
    required this.action,
    this.pastureName,
    this.animalName,
    this.status,
    required this.rawText,
  });

  @override
  String toString() {
    return 'VoicePastureResult(action: ${action.name}, pasture: $pastureName, animal: $animalName, status: ${status?.name})';
  }
}

class VoiceInventoryResult {
  final InventoryVoiceAction action;
  final String itemName;
  final double quantity;
  final String rawText;

  VoiceInventoryResult({
    required this.action,
    required this.itemName,
    required this.quantity,
    required this.rawText,
  });

  @override
  String toString() {
    return 'VoiceInventoryResult(action: ${action.name}, item: $itemName, qty: $quantity)';
  }
}

class VoiceKiddingResult {
  final String? damName;
  final int litterSize;
  final List<VoiceKidDetail> kids;
  final String rawText;

  VoiceKiddingResult({
    this.damName,
    required this.litterSize,
    required this.kids,
    required this.rawText,
  });

  @override
  String toString() {
    return 'VoiceKiddingResult(dam: $damName, size: $litterSize, kids: $kids)';
  }
}

class VoiceKidDetail {
  final String? earTag;
  final KidSex sex;
  final String? color;
  final double? weight;

  VoiceKidDetail({
    this.earTag,
    this.sex = KidSex.unknown,
    this.color,
    this.weight,
  });

  @override
  String toString() {
    return 'VoiceKidDetail(tag: $earTag, sex: ${sex.name}, color: $color, weight: $weight)';
  }
}

class VoiceCommandResult {
  final VoiceIntent intent;
  final String rawText;
  final String? animalName;
  final VoiceKiddingResult? kiddingResult;
  final VoiceWeightResult? weightResult;
  final VoiceHealthResult? healthResult;
  final VoiceNoteResult? noteResult;
  final VoiceReminderResult? reminderResult;
  final VoicePastureResult? pastureResult;
  final VoiceInventoryResult? inventoryResult;

  VoiceCommandResult({
    required this.intent,
    required this.rawText,
    this.animalName,
    this.kiddingResult,
    this.weightResult,
    this.healthResult,
    this.noteResult,
    this.reminderResult,
    this.pastureResult,
    this.inventoryResult,
  });
}

class VoiceParser {
  static const List<String> _knownColors = [
    'brown', 'tan', 'white', 'black', 'red', 'cream',
    'spotted', 'paint', 'roan', 'gold', 'grey', 'gray', 'silver'
  ];

  static VoiceCommandResult parseCommand(
    String text,
    List<String> animalNames, {
    Map<String, String>? tagToNameMap,
    List<String> pastureNames = const [],
    List<String> inventoryItemNames = const [],
  }) {
    final textLower = text.toLowerCase();

    // ── Resolve animal name (full name, partial word, or ear tag) ──
    String? matchedAnimal;
    for (final name in animalNames) {
      if (textLower.contains(name.toLowerCase())) {
        matchedAnimal = name;
        break;
      }
    }
    if (matchedAnimal == null) {
      for (final name in animalNames) {
        final words = name.toLowerCase().split(RegExp(r'\s+'));
        for (final word in words) {
          if (word.length > 2 && textLower.contains(word)) {
            matchedAnimal = name;
            break;
          }
        }
        if (matchedAnimal != null) break;
      }
    }
    if (matchedAnimal == null && tagToNameMap != null) {
      final tagRegex = RegExp(r'\b\d{3,7}\b');
      final tags = tagRegex.allMatches(textLower).map((m) => m.group(0)!).toList();
      for (final tag in tags) {
        if (tagToNameMap.containsKey(tag)) {
          matchedAnimal = tagToNameMap[tag];
          break;
        }
      }
    }

    // ── Resolve pasture name ──
    final String? matchedPasture = _matchPasture(textLower, pastureNames);

    final bool isHerdWord = textLower.contains('herd') ||
        textLower.contains('flock') ||
        textLower.contains('everyone') ||
        textLower.contains('all the goats') ||
        textLower.contains('all goats') ||
        textLower.contains('whole herd');

    // ── Determine intent. Reminder & pasture are checked first because they
    //    legitimately contain weigh/deworm/move keywords. ──
    VoiceIntent intent;
    if (textLower.contains('remind') ||
        textLower.contains('reminder') ||
        textLower.contains('schedule') ||
        textLower.contains("don't forget") ||
        textLower.contains('do not forget')) {
      intent = VoiceIntent.reminder;
    } else if (textLower.contains('pasture') ||
        textLower.contains('paddock') ||
        textLower.contains('graze') ||
        textLower.contains('grazing') ||
        textLower.contains('rotate') ||
        textLower.contains('rotation') ||
        (textLower.contains('move') &&
            (matchedPasture != null || isHerdWord))) {
      intent = VoiceIntent.pasture;
    } else if (_isHealthCommand(textLower)) {
      // Health is checked before kidding so "had a FAMACHA score" or
      // "had a dose of dewormer" are not mistaken for a birth.
      intent = VoiceIntent.health;
    } else if (_isKiddingCommand(textLower)) {
      intent = VoiceIntent.kidding;
    } else if (textLower.contains('weight') ||
        textLower.contains('weigh') ||
        textLower.contains('weighed') ||
        textLower.contains('weighs')) {
      intent = VoiceIntent.weight;
    } else if (textLower.contains('note') ||
        textLower.contains('logged') ||
        textLower.contains('remark')) {
      intent = VoiceIntent.note;
    } else if (_isInventoryCommand(textLower)) {
      intent = VoiceIntent.inventory;
    } else {
      intent = VoiceIntent.unknown;
    }

    // ── REMINDER ──
    if (intent == VoiceIntent.reminder) {
      final type = _deriveReminderType(textLower);
      final date = _parseReminderDate(textLower);
      final title = _extractReminderTitle(textLower, matchedAnimal, type);
      return VoiceCommandResult(
        intent: VoiceIntent.reminder,
        rawText: text,
        animalName: matchedAnimal,
        reminderResult: VoiceReminderResult(
          title: title,
          date: date,
          type: type,
          animalName: matchedAnimal,
          rawText: text,
        ),
      );
    }

    // ── PASTURE ──
    if (intent == VoiceIntent.pasture) {
      PastureStatus? status;
      if (textLower.contains('rest')) {
        status = PastureStatus.resting;
      } else if (textLower.contains('available') || textLower.contains('open')) {
        status = PastureStatus.available;
      } else if (textLower.contains('maintenance') ||
          textLower.contains('repair')) {
        status = PastureStatus.maintenance;
      } else if (textLower.contains('occupied')) {
        status = PastureStatus.occupied;
      }

      final bool marksStatus =
          textLower.contains('mark') || textLower.contains('set');

      PastureVoiceAction action;
      if (marksStatus && status != null) {
        action = PastureVoiceAction.setStatus;
      } else if (textLower.contains('rotate') ||
          textLower.contains('rotation')) {
        action = PastureVoiceAction.rotate;
      } else if (isHerdWord) {
        action = PastureVoiceAction.moveHerd;
      } else if (matchedAnimal != null) {
        action = PastureVoiceAction.moveAnimal;
      } else {
        action = PastureVoiceAction.moveHerd;
      }

      return VoiceCommandResult(
        intent: VoiceIntent.pasture,
        rawText: text,
        animalName: matchedAnimal,
        pastureResult: VoicePastureResult(
          action: action,
          pastureName: matchedPasture,
          animalName: matchedAnimal,
          status: status,
          rawText: text,
        ),
      );
    }

    // ── WEIGHT ──
    if (intent == VoiceIntent.weight) {
      double? weight;
      final weightMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:lbs|lbs\b|pound|pounds\b|kg|kgs\b)').firstMatch(textLower);
      if (weightMatch != null) {
        weight = double.tryParse(weightMatch.group(1)!);
      } else {
        final allNumbers = RegExp(r'\b\d+(?:\.\d+)?\b').allMatches(textLower).map((m) => m.group(0)!).toList();
        for (final numStr in allNumbers) {
          if (tagToNameMap != null && tagToNameMap.containsKey(numStr) && tagToNameMap[numStr] == matchedAnimal) {
            continue;
          }
          final parsed = double.tryParse(numStr);
          if (parsed != null && parsed > 0) {
            weight = parsed;
            break;
          }
        }
      }

      return VoiceCommandResult(
        intent: VoiceIntent.weight,
        rawText: text,
        animalName: matchedAnimal,
        weightResult: VoiceWeightResult(
          weight: weight ?? 0.0,
          animalName: matchedAnimal,
          rawText: text,
        ),
      );
    }

    if (intent == VoiceIntent.health) {
      final HealthRecordType type = _deriveHealthType(textLower);
      int? famachaScore;
      double? bcsScore;
      String treatment = _healthTypeLabel(type);
      String? dosage;

      if (type == HealthRecordType.famacha) {
        final s = _extractScore(textLower);
        if (s != null) famachaScore = s.round();
        treatment = 'FAMACHA';
      } else if (type == HealthRecordType.bcs) {
        final s = _extractScore(textLower);
        if (s != null) bcsScore = s;
        treatment = 'Body Condition Score';
      } else {
        // Product / treatment name
        const treatments = [
          'cd and t', 'cd&t', 'ivermectin', 'valbazen', 'safeguard',
          'penicillin', 'banamine', 'banimine', 'hoof trim', 'hoof trimming',
          'vitamin b', 'la-200', 'la 200', 'cydectin', 'dectomax', 'bo-se',
          'probios', 'selenium',
        ];
        bool found = false;
        for (final t in treatments) {
          if (textLower.contains(t)) {
            treatment = _prettyTreatment(t);
            found = true;
            break;
          }
        }
        if (!found) {
          final withMatch = RegExp(r'(?:with|vaccine|dewormer|gave|administered|of)\s+([a-zA-Z][a-zA-Z\s-]+)')
              .firstMatch(textLower);
          if (withMatch != null) {
            String val = withMatch.group(1)!.trim();
            val = val.split(RegExp(r'\b\d')).first.trim();
            if (val.isNotEmpty && val.length > 1) {
              treatment = val[0].toUpperCase() + val.substring(1);
            }
          }
        }

        final dosageMatch = RegExp(r'(\d+(?:\.\d+)?\s*(?:cc|ml|mg|cc\b|ml\b|mg\b))').firstMatch(textLower);
        if (dosageMatch != null) {
          dosage = dosageMatch.group(1)!.trim();
        }
      }

      return VoiceCommandResult(
        intent: VoiceIntent.health,
        rawText: text,
        animalName: matchedAnimal,
        healthResult: VoiceHealthResult(
          type: type,
          treatment: treatment,
          dosage: dosage,
          famachaScore: famachaScore,
          bcsScore: bcsScore,
          animalName: matchedAnimal,
          appliesToHerd: isHerdWord,
          rawText: text,
        ),
      );
    }

    if (intent == VoiceIntent.note) {
      String noteText = text;
      final colonIndex = text.indexOf(':');
      if (colonIndex != -1 && colonIndex < text.length - 1) {
        noteText = text.substring(colonIndex + 1).trim();
      } else {
        String textToStrip = textLower;
        if (matchedAnimal != null) {
          textToStrip = textToStrip.replaceFirst(matchedAnimal.toLowerCase(), '');
          final words = matchedAnimal.toLowerCase().split(RegExp(r'\s+'));
          for (final word in words) {
            if (word.length > 2) {
              textToStrip = textToStrip.replaceFirst(word, '');
            }
          }
        }
        textToStrip = textToStrip.replaceFirst(RegExp(r'add\s+a?\s*note\s+(?:for|on|about)?|log\s+a?\s*note\s+(?:for|on|about)?|note|remark'), '');
        textToStrip = textToStrip.trim();
        noteText = textToStrip;
      }

      while (noteText.startsWith(':') || noteText.startsWith(',') || noteText.startsWith(' ')) {
        noteText = noteText.substring(1).trim();
      }

      return VoiceCommandResult(
        intent: VoiceIntent.note,
        rawText: text,
        animalName: matchedAnimal,
        noteResult: VoiceNoteResult(
          noteText: noteText,
          animalName: matchedAnimal,
          rawText: text,
        ),
      );
    }

    // ── INVENTORY ──
    if (intent == VoiceIntent.inventory) {
      final invResult = _parseInventoryCommand(textLower, inventoryItemNames, text);
      return VoiceCommandResult(
        intent: VoiceIntent.inventory,
        rawText: text,
        inventoryResult: invResult,
      );
    }

    // ── UNKNOWN (no recognized intent) ──
    if (intent == VoiceIntent.unknown) {
      return VoiceCommandResult(
        intent: VoiceIntent.unknown,
        rawText: text,
        animalName: matchedAnimal,
      );
    }

    // ── KIDDING ──
    int litterSize = 1;
    if (textLower.contains('twin')) {
      litterSize = 2;
    } else if (textLower.contains('triplet')) {
      litterSize = 3;
    } else if (textLower.contains('quad')) {
      litterSize = 4;
    } else {
      final countRegex = RegExp(r'(\d+|one|two|three|four|five)\s*(kids?|goats?|babies|babys?|children|bucks?|does?)');
      final match = countRegex.firstMatch(textLower);
      if (match != null) {
        final numWord = match.group(1)!;
        if (numWord == 'one' || numWord == '1') {
          litterSize = 1;
        } else if (numWord == 'two' || numWord == '2') {
          litterSize = 2;
        } else if (numWord == 'three' || numWord == '3') {
          litterSize = 3;
        } else if (numWord == 'four' || numWord == '4') {
          litterSize = 4;
        } else if (numWord == 'five' || numWord == '5') {
          litterSize = 5;
        }
      }
    }

    String detailsText = textLower;
    if (matchedAnimal != null) {
      detailsText = detailsText.replaceAll(matchedAnimal.toLowerCase(), '');
    }

    final tagRegex = RegExp(r'\b\d{3,7}\b');
    final tags = tagRegex.allMatches(detailsText).map((m) => m.group(0)!).toList();

    final foundColors = <String>[];
    final colorWords = detailsText.split(RegExp(r'[\s,\.\?]+'));
    for (final word in colorWords) {
      if (_knownColors.contains(word)) {
        foundColors.add(word[0].toUpperCase() + word.substring(1));
      }
    }

    final foundSexes = <KidSex>[];
    final sexRegex = RegExp(r'\b(buck|male|boy|doe|female|girl)\b');
    final sexMatches = sexRegex.allMatches(detailsText).toList();
    for (final match in sexMatches) {
      final s = match.group(1)!;
      if (s == 'buck' || s == 'male' || s == 'boy') {
        foundSexes.add(KidSex.buck);
      } else if (s == 'doe' || s == 'female' || s == 'girl') {
        foundSexes.add(KidSex.doe);
      }
    }

    final weightRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:lbs|lbs\b|pound|pounds\b|kg|kgs\b)');
    final weights = weightRegex.allMatches(detailsText).map((m) => double.tryParse(m.group(1)!)).toList();

    final kids = <VoiceKidDetail>[];
    for (int i = 0; i < litterSize; i++) {
      final String? tag = i < tags.length ? tags[i] : null;
      final KidSex sex = i < foundSexes.length ? foundSexes[i] : KidSex.unknown;
      final String? color = i < foundColors.length ? foundColors[i] : null;
      final double? weight = i < weights.length ? weights[i] : null;

      kids.add(VoiceKidDetail(
        earTag: tag,
        sex: sex,
        color: color,
        weight: weight,
      ));
    }

    final kiddingResult = VoiceKiddingResult(
      damName: matchedAnimal,
      litterSize: litterSize,
      kids: kids,
      rawText: text,
    );

    return VoiceCommandResult(
      intent: VoiceIntent.kidding,
      rawText: text,
      animalName: matchedAnimal,
      kiddingResult: kiddingResult,
    );
  }

  // ─── Health command helpers ─────────────────────────────────────────────
  static bool _isHealthCommand(String t) {
    const keywords = [
      'famacha', 'bcs', 'body condition', 'condition score',
      'vaccin', 'booster', 'cd&t', 'cd and t', 'cdt', 'antitoxin', 'tetanus',
      'deworm', 'wormer', 'worming', 'drench', 'anthelmintic',
      'antibiotic', 'penicillin', 'banamine', 'banimine', 'la-200', 'la 200',
      'oxytet', 'supplement', 'vitamin', 'mineral', 'selenium', 'bo-se',
      'bose', 'probios', 'probiotic', 'copper', 'bolus', 'cobalt', 'b12',
      'b-12', 'calcium', 'electrolyte', 'iron',
      'ivermectin', 'valbazen', 'safeguard', 'cydectin', 'dectomax',
      'treatment', 'treated', 'medication', 'medicine', 'shot',
      'injection', 'dose', 'dosage', 'hoof', 'hooves', 'trim',
    ];
    for (final k in keywords) {
      if (t.contains(k)) return true;
    }
    return false;
  }

  static bool _isKiddingCommand(String t) {
    if (t.contains('kid') ||
        t.contains('twins') ||
        t.contains('triplet') ||
        t.contains('quad') ||
        t.contains('newborn') ||
        t.contains('gave birth') ||
        t.contains('born')) {
      return true;
    }
    if (t.contains('had') &&
        (t.contains('single') ||
            t.contains('a buck') ||
            t.contains('a doe') ||
            t.contains('babies'))) {
      return true;
    }
    return false;
  }

  static HealthRecordType _deriveHealthType(String t) {
    if (t.contains('famacha')) return HealthRecordType.famacha;
    if (t.contains('bcs') ||
        t.contains('body condition') ||
        t.contains('condition score')) {
      return HealthRecordType.bcs;
    }
    if (t.contains('vaccin') ||
        t.contains('cd&t') ||
        t.contains('cd and t') ||
        t.contains('cdt') ||
        t.contains('booster') ||
        t.contains('tetanus') ||
        t.contains('antitoxin') ||
        t.contains('shot')) {
      return HealthRecordType.vaccination;
    }
    if (t.contains('deworm') ||
        t.contains('wormer') ||
        t.contains('worming') ||
        t.contains('drench') ||
        t.contains('ivermectin') ||
        t.contains('valbazen') ||
        t.contains('safeguard') ||
        t.contains('cydectin') ||
        t.contains('dectomax')) {
      return HealthRecordType.deworming;
    }
    if (t.contains('antibiotic') ||
        t.contains('penicillin') ||
        t.contains('banamine') ||
        t.contains('banimine') ||
        t.contains('la-200') ||
        t.contains('la 200') ||
        t.contains('oxytet')) {
      return HealthRecordType.antibiotic;
    }
    if (t.contains('supplement') ||
        t.contains('vitamin') ||
        t.contains('mineral') ||
        t.contains('selenium') ||
        t.contains('bo-se') ||
        t.contains('bose') ||
        t.contains('probios') ||
        t.contains('probiotic') ||
        t.contains('copper') ||
        t.contains('bolus') ||
        t.contains('cobalt') ||
        t.contains('b12') ||
        t.contains('b-12') ||
        t.contains('calcium') ||
        t.contains('electrolyte') ||
        t.contains('iron')) {
      return HealthRecordType.supplement;
    }
    if (t.contains('hoof') || t.contains('hooves') || t.contains('trim')) {
      return HealthRecordType.grooming;
    }
    return HealthRecordType.other;
  }

  static String _healthTypeLabel(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.famacha:
        return 'FAMACHA';
      case HealthRecordType.bcs:
        return 'Body Condition Score';
      case HealthRecordType.vaccination:
        return 'Vaccination';
      case HealthRecordType.deworming:
        return 'Deworming';
      case HealthRecordType.antibiotic:
        return 'Antibiotic';
      case HealthRecordType.supplement:
        return 'Supplement';
      case HealthRecordType.grooming:
        return 'Hoof Trim';
      case HealthRecordType.labTest:
        return 'Lab Test';
      case HealthRecordType.pregnancyCheck:
        return 'Pregnancy Check';
      case HealthRecordType.illness:
        return 'Illness';
      case HealthRecordType.injury:
        return 'Injury';
      case HealthRecordType.surgery:
        return 'Surgery';
      case HealthRecordType.vetVisit:
        return 'Vet Visit';
      case HealthRecordType.other:
        return 'Treatment';
    }
  }

  static String _prettyTreatment(String t) {
    switch (t) {
      case 'cd and t':
      case 'cd&t':
        return 'CD&T';
      case 'hoof trim':
      case 'hoof trimming':
        return 'Hoof Trim';
      case 'vitamin b':
        return 'Vitamin B';
      case 'la 200':
      case 'la-200':
        return 'LA-200';
      case 'bo-se':
        return 'Bo-Se';
      default:
        return t[0].toUpperCase() + t.substring(1);
    }
  }

  /// Extracts a 1–5 score (whole or .5) while avoiding ear-tag / goat numbers.
  static double? _extractScore(String t) {
    final patterns = [
      RegExp(r'(?:score|famacha|bcs|condition)\D{0,10}([1-5](?:\.\d)?)'),
      RegExp(r'\bof\s+(?:a\s+)?([1-5](?:\.\d)?)\b'),
      RegExp(r'\bis\s+(?:a\s+)?([1-5](?:\.\d)?)\b'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(t);
      if (m != null) {
        final v = double.tryParse(m.group(1)!);
        if (v != null && v >= 1 && v <= 5) return v;
      }
    }
    // Fallback: a standalone 1–5 not adjacent to other digits.
    final m = RegExp(r'(?<!\d)([1-5](?:\.\d)?)(?!\d)').firstMatch(t);
    if (m != null) {
      final v = double.tryParse(m.group(1)!);
      if (v != null && v >= 1 && v <= 5) return v;
    }
    return null;
  }

  // ─── Number-word ↔ digit normalisation ──────────────────────────────────
  static const Map<String, String> _numberWordToDigit = {
    'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
    'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
    'eleven': '11', 'twelve': '12',
  };

  /// Replace spoken number words ("one", "two", …) with their digit form,
  /// and also replace digits with their word form, so either representation
  /// in the transcription can match the stored pasture name.
  static String _normalizeNumbers(String text) {
    var result = text;
    _numberWordToDigit.forEach((word, digit) {
      // Word → digit  (e.g. "pasture one" → "pasture 1")
      result = result.replaceAllMapped(
        RegExp('\\b$word\\b'),
        (m) => digit,
      );
    });
    return result;
  }

  // ─── Pasture name matching ──────────────────────────────────────────────
  static String? _matchPasture(String textLower, List<String> pastureNames) {
    // Build a version of the input where number words are also digits.
    final textNorm = _normalizeNumbers(textLower);

    for (final name in pastureNames) {
      if (name.isEmpty) continue;
      final nameLower = name.toLowerCase();
      final nameNorm = _normalizeNumbers(nameLower);

      // Exact substring match (original or normalised).
      if (textLower.contains(nameLower) || textNorm.contains(nameNorm)) {
        return name;
      }
    }

    // Fallback: match on non-generic individual words from the pasture name.
    const generic = {'pasture', 'paddock', 'field', 'the', 'and', 'lot'};
    for (final name in pastureNames) {
      final nameLower = name.toLowerCase();
      final nameNorm = _normalizeNumbers(nameLower);
      final words = nameNorm.split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.isNotEmpty &&
            !generic.contains(word) &&
            (textLower.contains(word) || textNorm.contains(word))) {
          return name;
        }
      }
    }
    return null;
  }

  // ─── Reminder helpers ───────────────────────────────────────────────────
  static const Map<String, int> _weekdays = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  static const Map<String, int> _monthNames = {
    'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
    'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11,
    'december': 12,
  };

  static const Map<String, int> _numberWords = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7,
    'eight': 8, 'nine': 9, 'ten': 10, 'a': 1, 'an': 1, 'couple': 2, 'few': 3,
  };

  static ReminderType _deriveReminderType(String t) {
    if (t.contains('vaccin') ||
        t.contains('cd&t') ||
        t.contains('cd and t') ||
        t.contains('shot')) {
      return ReminderType.vaccination;
    }
    if (t.contains('deworm') || t.contains('worm')) {
      return ReminderType.deworming;
    }
    if (t.contains('breed')) return ReminderType.breeding;
    if (t.contains('kidd') || t.contains('due to kid')) return ReminderType.kidding;
    if (t.contains('weigh')) return ReminderType.weigh;
    if (t.contains('vet')) return ReminderType.vet;
    if (t.contains('pasture') ||
        t.contains('rotat') ||
        t.contains('graz') ||
        t.contains('move')) {
      return ReminderType.pasture;
    }
    if (t.contains('test') ||
        t.contains('famacha') ||
        t.contains('bcs') ||
        t.contains('fec') ||
        t.contains('fecal') ||
        t.contains('egg count')) {
      return ReminderType.testing;
    }
    return ReminderType.custom;
  }

  static DateTime _parseReminderDate(String t) {
    final now = DateTime.now();
    DateTime morning(DateTime d) => DateTime(d.year, d.month, d.day, 8, 0);

    if (t.contains('day after tomorrow')) {
      return morning(now.add(const Duration(days: 2)));
    }
    if (t.contains('tomorrow')) return morning(now.add(const Duration(days: 1)));
    if (t.contains('today') || t.contains('tonight')) return morning(now);

    // "in N days/weeks/months"
    final inMatch = RegExp(
            r'in\s+(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|couple|few)\s+(day|week|month)s?')
        .firstMatch(t);
    if (inMatch != null) {
      final qWord = inMatch.group(1)!;
      final n = int.tryParse(qWord) ?? _numberWords[qWord] ?? 1;
      switch (inMatch.group(2)) {
        case 'day':
          return morning(now.add(Duration(days: n)));
        case 'week':
          return morning(now.add(Duration(days: 7 * n)));
        case 'month':
          return morning(DateTime(now.year, now.month + n, now.day, 8));
      }
    }

    if (t.contains('next week')) return morning(now.add(const Duration(days: 7)));
    if (t.contains('next month')) {
      return morning(DateTime(now.year, now.month + 1, now.day, 8));
    }

    // "<month> <day>" e.g. "march 15", "on the 3rd of april"
    for (final entry in _monthNames.entries) {
      if (t.contains(entry.key)) {
        final dm = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\b').firstMatch(t);
        final day = dm != null ? (int.tryParse(dm.group(1)!) ?? 1) : 1;
        var candidate = DateTime(now.year, entry.value, day, 8);
        if (candidate.isBefore(now)) {
          candidate = DateTime(now.year + 1, entry.value, day, 8);
        }
        return candidate;
      }
    }

    // "<weekday>" / "next <weekday>" → nearest upcoming occurrence
    for (final entry in _weekdays.entries) {
      if (t.contains(entry.key)) {
        var daysAhead = (entry.value - now.weekday) % 7;
        if (daysAhead <= 0) daysAhead += 7;
        return morning(now.add(Duration(days: daysAhead)));
      }
    }

    // default: one week from now
    return morning(now.add(const Duration(days: 7)));
  }

  static String _extractReminderTitle(
      String textLower, String? animal, ReminderType type) {
    String t = textLower;

    const leadIns = [
      'please remind me to ', 'please remind me ', 'remind me to ', 'remind me ',
      'set a reminder to ', 'set an reminder to ', 'set reminder to ',
      'set a reminder for ', 'set a reminder about ', 'set a reminder ',
      'create a reminder to ', 'create a reminder for ', 'create a reminder ',
      'add a reminder to ', 'add a reminder ',
      'schedule a ', 'schedule an ', 'schedule ',
      "don't forget to ", 'do not forget to ',
    ];
    for (final lead in leadIns) {
      if (t.startsWith(lead)) {
        t = t.substring(lead.length);
        break;
      }
    }

    // Strip date phrases
    t = t.replaceAll(
        RegExp(r'\b(today|tonight|tomorrow|day after tomorrow|next week|this week|next month)\b'),
        '');
    t = t.replaceAll(
        RegExp(r'\bin\s+(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten|couple|few)\s+(day|week|month)s?\b'),
        '');
    t = t.replaceAll(
        RegExp(r'\b(next\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b'),
        '');
    t = t.replaceAll(
        RegExp(r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\b\s*\d{0,2}(st|nd|rd|th)?'),
        '');
    t = t.replaceAll(RegExp(r'\bon the\b|\bon\b'), ' ');

    // Strip animal reference
    if (animal != null) {
      t = t.replaceAll('for ${animal.toLowerCase()}', '');
      t = t.replaceAll(animal.toLowerCase(), '');
    }

    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceFirst(RegExp(r'^(to|for|the|a|an|of|and)\s+'), '').trim();
    t = t.replaceFirst(RegExp(r'\s+(for|on|to|the)$'), '').trim();

    if (t.isEmpty) return type.displayName;
    return t[0].toUpperCase() + t.substring(1);
  }

  // ─── Inventory Voice Helpers ─────────────────────────────────────────────

  static bool _isInventoryCommand(String text) {
    return text.contains('inventory') ||
        text.contains('supplies') ||
        text.contains('supply') ||
        text.contains('stock') ||
        text.contains('restock') ||
        text.contains('in stock') ||
        (text.contains('used') && _hasInventoryItemHint(text)) ||
        (text.contains('add') && text.contains('to inventory')) ||
        (text.contains('how many') && _hasInventoryItemHint(text));
  }

  static bool _hasInventoryItemHint(String text) {
    const hints = [
      'syringe', 'needle', 'bottle', 'glove', 'vaccine',
      'band', 'tag', 'tape', 'wrap', 'bandage', 'mineral',
      'la-200', 'la 200', 'penicillin', 'banamine', 'ivermectin',
      'cydectin', 'valbazen', 'safeguard', 'electrolyte',
      'probiotics', 'drench', 'charcoal', 'bleach', 'lime',
    ];
    for (final h in hints) {
      if (text.contains(h)) return true;
    }
    return false;
  }

  static VoiceInventoryResult _parseInventoryCommand(
    String textLower,
    List<String> itemNames,
    String rawText,
  ) {
    // Normalise numbers ("two" → "2") reusing existing helper
    textLower = _normalizeNumbers(textLower);

    // Determine action
    InventoryVoiceAction action;
    if (textLower.contains('how many') ||
        textLower.contains('check') ||
        textLower.contains('count') ||
        textLower.contains('do i have') ||
        textLower.contains('do we have') ||
        textLower.contains('in stock')) {
      action = InventoryVoiceAction.checkStock;
    } else if (textLower.contains('used') ||
        textLower.contains('use ') ||
        textLower.contains('took') ||
        textLower.contains('consumed') ||
        textLower.contains('spent')) {
      action = InventoryVoiceAction.useStock;
    } else {
      action = InventoryVoiceAction.addStock;
    }

    // Extract quantity
    double quantity = 1;
    final qtyMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(textLower);
    if (qtyMatch != null) {
      quantity = double.tryParse(qtyMatch.group(1)!) ?? 1;
    }

    // Match item name against known inventory items (case-insensitive)
    String itemName = 'unknown item';
    if (itemNames.isNotEmpty) {
      // Try exact substring match first
      for (final name in itemNames) {
        if (textLower.contains(name.toLowerCase())) {
          itemName = name;
          break;
        }
      }
      // Try partial word match if no exact hit
      if (itemName == 'unknown item') {
        for (final name in itemNames) {
          final words = name.toLowerCase().split(RegExp(r'[\s/()]+'));
          for (final word in words) {
            if (word.length > 2 && textLower.contains(word)) {
              itemName = name;
              break;
            }
          }
          if (itemName != 'unknown item') break;
        }
      }
    }

    // If still unknown, try to extract the item name from the text heuristically
    if (itemName == 'unknown item') {
      // "add 2 bottles of LA-200 to inventory" → extract "LA-200"
      final ofMatch = RegExp(r'(?:of|bottles?|boxes?|bags?|rolls?|packs?)\s+([a-zA-Z][a-zA-Z0-9\s-]+?)(?:\s+(?:to|from|in)\s|$)').firstMatch(textLower);
      if (ofMatch != null) {
        itemName = ofMatch.group(1)!.trim();
        if (itemName.isNotEmpty) {
          itemName = itemName[0].toUpperCase() + itemName.substring(1);
        }
      } else {
        // "used 12 syringes today" → extract "syringes"
        final usedMatch = RegExp(r'\d+\s+([a-zA-Z][a-zA-Z\s-]+?)(?:\s+(?:today|yesterday|this)\b|$)').firstMatch(textLower);
        if (usedMatch != null) {
          itemName = usedMatch.group(1)!.trim();
          if (itemName.isNotEmpty) {
            itemName = itemName[0].toUpperCase() + itemName.substring(1);
          }
        }
      }
    }

    return VoiceInventoryResult(
      action: action,
      itemName: itemName,
      quantity: quantity,
      rawText: rawText,
    );
  }

  // Backwards compatibility wrapper for original kidding tests and code
  static VoiceKiddingResult parse(String text, List<String> doeNames) {
    final result = parseCommand(text, doeNames);
    return result.kiddingResult ?? VoiceKiddingResult(
      damName: result.animalName,
      litterSize: 1,
      kids: [],
      rawText: text,
    );
  }
}
