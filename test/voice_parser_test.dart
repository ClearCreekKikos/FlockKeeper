import 'package:flutter_test/flutter_test.dart';
import 'package:flockkeeper/data/models/kidding_record_model.dart';
import 'package:flockkeeper/data/models/reminder_model.dart';
import 'package:flockkeeper/data/models/pasture_model.dart';
import 'package:flockkeeper/data/models/health_record_model.dart';
import 'package:flockkeeper/shared/services/voice_parser.dart';

void main() {
  group('VoiceParser Tests', () {
    final doeNames = ['SLS DOOZIE', 'SSK ROCHELLE', 'CBO HONEYBEE', 'Mama Doe', 'Huska'];

    test('Parses twin kidding with exact dam name and tags/colors/sexes', () {
      final input = "Goat SLS DOOZIE had 2 kids, I ear tagged them 1005 and 1006, colors are brown and tan";
      final result = VoiceParser.parse(input, doeNames);

      expect(result.damName, 'SLS DOOZIE');
      expect(result.litterSize, 2);
      expect(result.kids.length, 2);

      expect(result.kids[0].earTag, '1005');
      expect(result.kids[0].color, 'Brown');

      expect(result.kids[1].earTag, '1006');
      expect(result.kids[1].color, 'Tan');
    });

    test('Parses twin kidding with sibling terms and distinct sexes', () {
      final input = "Huska had twins, tag 1008 buck and tag 1009 doe";
      final result = VoiceParser.parse(input, doeNames);

      expect(result.damName, 'Huska');
      expect(result.litterSize, 2);
      expect(result.kids.length, 2);

      expect(result.kids[0].earTag, '1008');
      expect(result.kids[0].sex, KidSex.buck);

      expect(result.kids[1].earTag, '1009');
      expect(result.kids[1].sex, KidSex.doe);
    });

    test('Parses single kid with weights and colors', () {
      final input = "Mama Doe had a single buck color white weight 8.5 lbs tag 1007";
      final result = VoiceParser.parse(input, doeNames);

      expect(result.damName, 'Mama Doe');
      expect(result.litterSize, 1);
      expect(result.kids.length, 1);

      expect(result.kids[0].earTag, '1007');
      expect(result.kids[0].sex, KidSex.buck);
      expect(result.kids[0].color, 'White');
      expect(result.kids[0].weight, 8.5);
    });

    test('Resolves dam name by partial substring', () {
      final input = "tell me about rochelle having a kid";
      final result = VoiceParser.parse(input, doeNames);

      expect(result.damName, 'SSK ROCHELLE');
    });

    // ─── New Multi-Activity Commands Tests ───────────────────────────────────

    test('Parses weight logging command', () {
      final input = "Weighed SLS Doozie at 75.5 pounds";
      final result = VoiceParser.parseCommand(input, doeNames);

      expect(result.intent, VoiceIntent.weight);
      expect(result.animalName, 'SLS DOOZIE');
      expect(result.weightResult?.weight, 75.5);
    });

    test('Parses weight logging by tag lookup', () {
      final input = "Goat 1005 weighs 84 lbs";
      final tagToName = {'1005': 'SLS DOOZIE', '1006': 'SSK ROCHELLE'};
      final result = VoiceParser.parseCommand(input, doeNames, tagToNameMap: tagToName);

      expect(result.intent, VoiceIntent.weight);
      expect(result.animalName, 'SLS DOOZIE');
      expect(result.weightResult?.weight, 84.0);
    });

    test('Parses health deworming and vaccination commands', () {
      final input1 = "Vaccinated SLS Doozie with CD and T 2 cc";
      final result1 = VoiceParser.parseCommand(input1, doeNames);

      expect(result1.intent, VoiceIntent.health);
      expect(result1.animalName, 'SLS DOOZIE');
      expect(result1.healthResult?.treatment, 'CD&T');
      expect(result1.healthResult?.dosage, '2 cc');

      final input2 = "Dewormed Huska with Ivermectin 1.5 ml";
      final result2 = VoiceParser.parseCommand(input2, doeNames);

      expect(result2.intent, VoiceIntent.health);
      expect(result2.animalName, 'Huska');
      expect(result2.healthResult?.treatment, 'Ivermectin');
      expect(result2.healthResult?.dosage, '1.5 ml');
      expect(result2.healthResult?.type, HealthRecordType.deworming);
    });

    test('Parses a FAMACHA score as health, not a kidding (had + score)', () {
      final input = "Goat 602 had a FAMACHA score of 2";
      final tagToName = {'602': 'Huska'};
      final result =
          VoiceParser.parseCommand(input, doeNames, tagToNameMap: tagToName);

      expect(result.intent, VoiceIntent.health);
      expect(result.animalName, 'Huska');
      expect(result.healthResult!.type, HealthRecordType.famacha);
      expect(result.healthResult!.famachaScore, 2); // not the ear tag 602
    });

    test('Parses a body condition score (BCS) health record', () {
      final input = "Set Huska BCS to 3.5";
      final result = VoiceParser.parseCommand(input, doeNames);

      expect(result.intent, VoiceIntent.health);
      expect(result.healthResult!.type, HealthRecordType.bcs);
      expect(result.healthResult!.bcsScore, 3.5);
    });

    test('Parses a supplement health record', () {
      final input = "Gave Huska a selenium supplement";
      final result = VoiceParser.parseCommand(input, doeNames);

      expect(result.intent, VoiceIntent.health);
      expect(result.healthResult!.type, HealthRecordType.supplement);
    });

    test('Parses a herd-wide vaccination in one command', () {
      final input = "Vaccinate the whole herd with CD&T 2 cc";
      final result = VoiceParser.parseCommand(input, doeNames);

      expect(result.intent, VoiceIntent.health);
      expect(result.healthResult!.appliesToHerd, isTrue);
      expect(result.healthResult!.type, HealthRecordType.vaccination);
      expect(result.healthResult!.treatment, 'CD&T');
      expect(result.healthResult!.dosage, '2 cc');
    });

    test('Parses a herd-wide copper bolus supplement', () {
      final input = "Give the entire herd a copper bolus";
      final result = VoiceParser.parseCommand(input, doeNames);

      expect(result.intent, VoiceIntent.health);
      expect(result.healthResult!.appliesToHerd, isTrue);
      expect(result.healthResult!.type, HealthRecordType.supplement);
    });

    test('Parses notes logging command', () {
      final input = "Add a note for SLS Doozie: looking thin today and has slight limp";
      final result = VoiceParser.parseCommand(input, doeNames);

      expect(result.intent, VoiceIntent.note);
      expect(result.animalName, 'SLS DOOZIE');
      expect(result.noteResult?.noteText, 'looking thin today and has slight limp');
    });

    // ─── Scheduled Event / Reminder Commands ─────────────────────────────────

    test('Parses a herd-wide reminder with a relative date and type', () {
      final input = "Remind me to deworm the herd in 2 weeks";
      final result = VoiceParser.parseCommand(input, doeNames);

      expect(result.intent, VoiceIntent.reminder);
      expect(result.reminderResult, isNotNull);
      expect(result.reminderResult!.type, ReminderType.deworming);
      expect(result.reminderResult!.animalName, isNull); // herd-wide
      expect(result.reminderResult!.title.toLowerCase(), contains('deworm'));
      final now = DateTime.now();
      expect(result.reminderResult!.date.isAfter(now.add(const Duration(days: 12))), isTrue);
      expect(result.reminderResult!.date.isBefore(now.add(const Duration(days: 16))), isTrue);
    });

    test('Parses a reminder attached to a specific animal', () {
      final input = "Set a reminder to vaccinate Huska tomorrow";
      final result = VoiceParser.parseCommand(input, doeNames);

      expect(result.intent, VoiceIntent.reminder);
      expect(result.reminderResult!.animalName, 'Huska');
      expect(result.reminderResult!.type, ReminderType.vaccination);
      final now = DateTime.now();
      expect(result.reminderResult!.date.isAfter(now), isTrue);
      expect(result.reminderResult!.date.isBefore(now.add(const Duration(days: 2))), isTrue);
    });

    // ─── Pasture Management Commands ─────────────────────────────────────────

    final pastures = ['North Pasture', 'South Forty', 'Back Paddock'];

    test('Parses moving a single animal to a pasture', () {
      final input = "Move Huska to the North Pasture";
      final result =
          VoiceParser.parseCommand(input, doeNames, pastureNames: pastures);

      expect(result.intent, VoiceIntent.pasture);
      expect(result.pastureResult!.action, PastureVoiceAction.moveAnimal);
      expect(result.pastureResult!.animalName, 'Huska');
      expect(result.pastureResult!.pastureName, 'North Pasture');
    });

    test('Parses moving the whole herd to a pasture', () {
      final input = "Move the whole herd to South Forty";
      final result =
          VoiceParser.parseCommand(input, doeNames, pastureNames: pastures);

      expect(result.intent, VoiceIntent.pasture);
      expect(result.pastureResult!.action, PastureVoiceAction.moveHerd);
      expect(result.pastureResult!.pastureName, 'South Forty');
    });

    test('Parses rotating the herd to a pasture', () {
      final input = "Rotate to the Back Paddock";
      final result =
          VoiceParser.parseCommand(input, doeNames, pastureNames: pastures);

      expect(result.intent, VoiceIntent.pasture);
      expect(result.pastureResult!.action, PastureVoiceAction.rotate);
      expect(result.pastureResult!.pastureName, 'Back Paddock');
    });

    test('Parses setting a pasture status', () {
      final input = "Mark North Pasture as resting";
      final result =
          VoiceParser.parseCommand(input, doeNames, pastureNames: pastures);

      expect(result.intent, VoiceIntent.pasture);
      expect(result.pastureResult!.action, PastureVoiceAction.setStatus);
      expect(result.pastureResult!.pastureName, 'North Pasture');
      expect(result.pastureResult!.status, PastureStatus.resting);
    });

    test('Unrecognized command returns unknown intent (not kidding)', () {
      final input = "What is the weather like outside";
      final result = VoiceParser.parseCommand(input, doeNames);

      expect(result.intent, VoiceIntent.unknown);
      expect(result.kiddingResult, isNull);
    });
  });
}
