import 'package:flutter_test/flutter_test.dart';
import 'package:flockkeeper/data/models/kidding_record_model.dart';
import 'package:flockkeeper/shared/services/voice_parser.dart';
import 'package:flockkeeper/shared/services/gemini_voice_service.dart';

void main() {
  group('GeminiVoiceService JSON Parsing Tests', () {
    test('Parses weight JSON response correctly', () {
      const rawText = 'weighed Daisy 75 pounds';
      const jsonResponse = '''
      {
        "intent": "weight",
        "animalName": "Daisy",
        "weightResult": {
          "weight": 75.0,
          "animalName": "Daisy"
        },
        "healthResult": null,
        "noteResult": null,
        "kiddingResult": null
      }
      ''';

      final result = GeminiVoiceService.parseJsonResponse(jsonResponse, rawText);

      expect(result.intent, equals(VoiceIntent.weight));
      expect(result.animalName, equals('Daisy'));
      expect(result.weightResult, isNotNull);
      expect(result.weightResult!.weight, equals(75.0));
      expect(result.weightResult!.animalName, equals('Daisy'));
    });

    test('Parses health JSON response correctly', () {
      const rawText = 'give 1001 2 ml of Ivomec';
      const jsonResponse = '''
      {
        "intent": "health",
        "animalName": "1001",
        "weightResult": null,
        "healthResult": {
          "treatment": "Ivomec",
          "dosage": "2 ml",
          "animalName": "1001"
        },
        "noteResult": null,
        "kiddingResult": null
      }
      ''';

      final result = GeminiVoiceService.parseJsonResponse(jsonResponse, rawText);

      expect(result.intent, equals(VoiceIntent.health));
      expect(result.animalName, equals('1001'));
      expect(result.healthResult, isNotNull);
      expect(result.healthResult!.treatment, equals('Ivomec'));
      expect(result.healthResult!.dosage, equals('2 ml'));
    });

    test('Parses kidding JSON response correctly', () {
      const rawText = '1002 had twins, a boy 1005 (8 lbs) and a girl 1006 (7.5 lbs)';
      const jsonResponse = '''
      {
        "intent": "kidding",
        "animalName": "1002",
        "weightResult": null,
        "healthResult": null,
        "noteResult": null,
        "kiddingResult": {
          "damName": "1002",
          "litterSize": 2,
          "kids": [
            {
              "earTag": "1005",
              "sex": "buck",
              "color": "Brown",
              "weight": 8.0
            },
            {
              "earTag": "1006",
              "sex": "doe",
              "color": "White",
              "weight": 7.5
            }
          ]
        }
      }
      ''';

      final result = GeminiVoiceService.parseJsonResponse(jsonResponse, rawText);

      expect(result.intent, equals(VoiceIntent.kidding));
      expect(result.animalName, equals('1002'));
      expect(result.kiddingResult, isNotNull);
      expect(result.kiddingResult!.litterSize, equals(2));
      expect(result.kiddingResult!.kids.length, equals(2));
      
      final kid1 = result.kiddingResult!.kids[0];
      expect(kid1.earTag, equals('1005'));
      expect(kid1.sex, equals(KidSex.buck));
      expect(kid1.color, equals('Brown'));
      expect(kid1.weight, equals(8.0));

      final kid2 = result.kiddingResult!.kids[1];
      expect(kid2.earTag, equals('1006'));
      expect(kid2.sex, equals(KidSex.doe));
      expect(kid2.color, equals('White'));
      expect(kid2.weight, equals(7.5));
    });

    test('Parses note JSON response correctly', () {
      const rawText = 'log a remark for Daisy: limping on front right hoof';
      const jsonResponse = '''
      {
        "intent": "note",
        "animalName": "Daisy",
        "weightResult": null,
        "healthResult": null,
        "noteResult": {
          "noteText": "limping on front right hoof",
          "animalName": "Daisy"
        },
        "kiddingResult": null
      }
      ''';

      final result = GeminiVoiceService.parseJsonResponse(jsonResponse, rawText);

      expect(result.intent, equals(VoiceIntent.note));
      expect(result.animalName, equals('Daisy'));
      expect(result.noteResult, isNotNull);
      expect(result.noteResult!.noteText, equals('limping on front right hoof'));
    });
  });
}
