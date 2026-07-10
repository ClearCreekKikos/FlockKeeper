import 'package:flutter_test/flutter_test.dart';
import 'package:flockkeeper/data/models/animal_model.dart';

void main() {
  group('Animal Model and Status Integration Tests', () {
    test('Animal maps serialization and deserialization with status', () {
      final now = DateTime.now();
      final animal = Animal(
        id: 101,
        name: 'Grand sire Buck',
        sex: Sex.buck,
        status: AnimalStatus.ancestor,
        breed: 'Kiko',
        herdBook: '100% New Zealand',
        earTag: 'ET-123',
        vglId: 'VGL-7890',
        createdAt: now,
        updatedAt: now,
      );

      // Convert to map
      final map = animal.toMap();
      expect(map['id'], 101);
      expect(map['name'], 'Grand sire Buck');
      expect(map['status'], 'ancestor');
      expect(map['sex'], 'buck');
      expect(map['breed'], 'Kiko');
      expect(map['herd_book'], '100% New Zealand');
      expect(map['ear_tag'], 'ET-123');
      expect(map['vgl_id'], 'VGL-7890');

      // Deserialize back to Animal
      final parsed = Animal.fromMap(map);
      expect(parsed.id, 101);
      expect(parsed.name, 'Grand sire Buck');
      expect(parsed.status, AnimalStatus.ancestor);
      expect(parsed.statusDisplay, 'Ancestor');
      expect(parsed.sex, Sex.buck);
      expect(parsed.sexDisplay, 'Buck');
      expect(parsed.breed, 'Kiko');
      expect(parsed.herdBook, '100% New Zealand');
      expect(parsed.earTag, 'ET-123');
      expect(parsed.vglId, 'VGL-7890');
    });

    test('Animal parsing handles fallback and alternative strings', () {
      final map = {
        'id': 202,
        'name': 'Granddam Doe',
        'sex': 'female',
        'status': 'ANCESTOR',
        'ear_tag': 'ET-456',
        'breed_type': 'Purebred Kiko', // older field fallback
        'created_at': '2026-06-18T23:00:00.000Z',
        'updated_at': '2026-06-18T23:30:00.000Z',
      };

      final parsed = Animal.fromMap(map);
      expect(parsed.id, 202);
      expect(parsed.name, 'Granddam Doe');
      expect(parsed.sex, Sex.doe);
      expect(parsed.status, AnimalStatus.ancestor);
      expect(parsed.earTag, 'ET-456');
      expect(parsed.herdBook, 'Purebred Kiko'); // correctly fell back to breed_type value
    });

    test('Animal copyWith updates fields correctly', () {
      final animal = Animal(
        id: 1,
        name: 'Original Kid',
        sex: Sex.wether,
        earTag: 'ET-001',
        breed: 'Spanish',
        herdBook: 'Purebred Spanish',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = animal.copyWith(
        name: 'Updated Kid',
        status: AnimalStatus.ancestor,
        earTag: 'ET-002',
        breed: 'Boer',
        herdBook: 'Fullblood',
      );

      expect(updated.id, 1);
      expect(updated.name, 'Updated Kid');
      expect(updated.status, AnimalStatus.ancestor);
      expect(updated.earTag, 'ET-002');
      expect(updated.breed, 'Boer');
      expect(updated.herdBook, 'Fullblood');
    });

    test('Animal serialization preserves sold and deceased details', () {
      final now = DateTime.now();
      final animal = Animal(
        id: 303,
        name: 'Sold Goat',
        sex: Sex.doe,
        status: AnimalStatus.sold,
        soldDate: now,
        soldPrice: 250.0,
        soldTo: 'John Doe',
        createdAt: now,
        updatedAt: now,
      );

      final map = animal.toMap();
      expect(map['status'], 'sold');
      expect(map['sold_price'], 250.0);
      expect(map['sold_to'], 'John Doe');

      final parsed = Animal.fromMap(map);
      expect(parsed.status, AnimalStatus.sold);
      expect(parsed.soldPrice, 250.0);
      expect(parsed.soldTo, 'John Doe');
      expect(parsed.soldDate, isNotNull);
    });

    test('Animal displayName formats correctly with earTag or rfidTag', () {
      final animal = Animal(
        name: 'Goat A',
        sex: Sex.doe,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(animal.displayName, 'Goat A');

      final withRfid = animal.copyWith(rfidTag: 'RFID123');
      expect(withRfid.displayName, 'Goat A');

      final withEarTag = animal.copyWith(earTag: 'ET999');
      expect(withEarTag.displayName, 'Goat A (ET999)');

      final withBoth = animal.copyWith(earTag: 'ET999', rfidTag: 'RFID123');
      expect(withBoth.displayName, 'Goat A (ET999)');
    });
  });
}
