// lib/features/import/templates/import_template.dart

abstract class ImportTemplate {
  String get name;
  String get description;
  String get softwareName;

  /// Auto-maps source columns to FlockKeeper fields
  Map<String, String> autoMap(List<String> sourceHeaders);
}

// Example: Generic NSIP-style template
class NsipTemplate extends ImportTemplate {
  @override
  String get name => 'NSIP Standard';
  @override
  String get description => 'National Sheep Improvement Program format';
  @override
  String get softwareName => 'NSIP';

  @override
  Map<String, String> autoMap(List<String> sourceHeaders) {
    // Maps known NSIP column names → FlockKeeper fields
    return {
      'ANIMAL_ID':    'nkrRegNumber',
      'ANIMAL_NAME':  'name',
      'BIRTH_DATE':   'dob',
      'SEX':          'sex',
      'SIRE_ID':      'sireRegNumber',
      'DAM_ID':       'damRegNumber',
      'BWT':          'birthWeight',
      'COLOR':        'color',
    };
  }
}

// Generic smart auto-mapper using fuzzy matching
class SmartAutoMapper {
  static Map<String, String> autoMap(List<String> sourceHeaders) {
    final mappings = <String, String>{};
    final knownMappings = _buildKnownMappings();

    for (final header in sourceHeaders) {
      final normalized = header.toLowerCase()
          .replaceAll(RegExp(r'[_\s-]'), '');

      for (final entry in knownMappings.entries) {
        if (normalized.contains(entry.key) ||
            entry.key.contains(normalized)) {
          mappings[header] = entry.value;
          break;
        }
      }
    }
    return mappings;
  }

  static Map<String, String> _buildKnownMappings() => {
    // Name variations
    'name':           'name',
    'animalname':     'name',
    'goatname':       'name',
    'tagname':        'name',
    'barnname':       'barnName',

    // Registration & Registry
    'reg':            'nkrRegNumber',
    'registration':   'nkrRegNumber',
    'nkr':            'nkrRegNumber',
    'regno':          'nkrRegNumber',
    'registry':       'registry',
    'registered':     'isRegistered',

    // Tattoo / Tag
    'tattoo':         'tattoo',
    'tag':            'earTag',
    'tagno':          'earTag',
    'eartag':         'earTag',
    'rfid':           'rfidTag',
    'rfidtag':        'rfidTag',
    'eid':            'rfidTag',
    'eidnumber':      'rfidTag',
    'eidtype':        'eidType',
    'eidplacement':   'eidPlacement',
    'idtag':          'idTagNumber',
    'idtagnumber':    'idTagNumber',
    'idtagplacement': 'idTagPlacement',
    'scrapie':        'scrapieTag',
    'scrapienumber':  'scrapieTag',
    'vgl':            'vglId',
    'vglid':          'vglId',
    'vglno':          'vglId',
    'vglnumber':      'vglId',
    'ucdavisvgl':     'vglId',

    // Dates
    'dob':            'dob',
    'birthdate':      'dob',
    'dateofbirth':    'dob',
    'born':           'dob',

    // Sex
    'sex':            'sex',
    'gender':         'sex',

    // Breed & Characteristics
    'breed':          'breed',
    'breedtype':      'breedType',
    'herdbook':       'herdBook',
    'classification': 'herdBook',
    'eyecolor':       'eyeColor',
    'eartype':        'earType',
    'horntype':       'hornType',
    'herdsire':       'isHerdSire',

    // Parents
    'dam':            'damName',
    'damname':        'damName',
    'mother':         'damName',
    'damreg':         'damRegNumber',
    'damregnumber':   'damRegNumber',
    'sire':           'sireName',
    'sirename':       'sireName',
    'father':         'sireName',
    'sirereg':        'sireRegNumber',
    'sireregnumber':  'sireRegNumber',

    // Weight
    'weight':         'weightLbs',
    'wt':             'weightLbs',
    'weightlbs':      'weightLbs',
    'weightkg':       'weightKg',
    'birthweight':    'birthWeightLbs',
    'birthweightlbs': 'birthWeightLbs',
    'bwt':            'birthWeightLbs',

    // Status & Description
    'status':         'status',
    'active':         'status',
    'description':    'description',
    'notes':          'notes',

    // Ownership & Sales
    'ownership':      'ownershipStatus',
    'ownershipstatus':'ownershipStatus',
    'purchase':       'purchaseDate',
    'purchasedate':   'purchaseDate',
    'purchaseprice':  'purchasePrice',
    'solddate':       'soldDate',
    'soldprice':      'soldPrice',
    'soldto':         'soldTo',
    'deceaseddate':   'deceasedDate',
    'deceasedreason': 'deceasedReason',
  };
}
