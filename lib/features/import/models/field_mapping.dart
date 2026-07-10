// lib/features/import/models/field_mapping.dart

class FieldMapping {
  /// The column name from the imported file
  final String sourceField;

  /// The FlockKeeper internal field name
  final String? targetField;

  /// Whether this mapping is required
  final bool isRequired;

  /// A sample value from the file for preview
  final String? sampleValue;

  const FieldMapping({
    required this.sourceField,
    this.targetField,
    this.isRequired = false,
    this.sampleValue,
  });

  FieldMapping copyWith({String? targetField}) {
    return FieldMapping(
      sourceField: sourceField,
      targetField: targetField ?? this.targetField,
      isRequired: isRequired,
      sampleValue: sampleValue,
    );
  }
}

/// All available FlockKeeper target fields
class FlockKeeperFields {
  static const animalFields = [
    // Vital Information
    TargetField('name',           'Animal Name',          true),
    TargetField('barnName',       'Barn Name',            false),
    TargetField('dob',            'Date of Birth',        false),
    TargetField('sex',            'Sex',                  true),
    TargetField('breed',          'Breed',                false),
    TargetField('status',         'Status',               false),
    TargetField('birthWeightLbs', 'Birth Weight (lbs)',   false),
    TargetField('isHerdSire',     'Is Herd Sire (Y/N)',   false),
    TargetField('isRegistered',   'Is Registered (Y/N)',  false),
    
    // Identifying Information
    TargetField('nkrRegNumber',   'NKR Reg. Number',      false),
    TargetField('earTag',         'Ear Tag',              false),
    TargetField('tattoo',         'Tattoo',               false),
    TargetField('rfidTag',        'EID Number / RFID Tag', false),
    TargetField('eidType',        'EID Type',             false),
    TargetField('eidPlacement',   'EID Placement',        false),
    TargetField('idTagNumber',    'Neck Chain Tag',       false),
    TargetField('idTagPlacement', 'Neck Chain Placement',  false),
    TargetField('scrapieTag',     'USDA Scrapie Tag',     false),
    TargetField('vglId',          'UC-Davis VGL#',        false),
    TargetField('registry',       'Registry Name',        false),

    // Description
    TargetField('color',          'Color',                false),
    TargetField('markings',       'Markings',             false),
    TargetField('breedType',      'Breed Type',           false),
    TargetField('herdBook',       'Herd Book',            false),
    TargetField('eyeColor',       'Eye Color',            false),
    TargetField('earType',        'Ear Type',             false),
    TargetField('hornType',       'Horn Type',            false),
    TargetField('description',    'Description',          false),
    TargetField('notes',          'Notes',                false),

    // Ancestry
    TargetField('damName',        'Dam Name',             false),
    TargetField('sireName',       'Sire Name',            false),
    TargetField('damRegNumber',   'Dam Reg. Number',      false),
    TargetField('sireRegNumber',  'Sire Reg. Number',     false),

    // Ownership & Status Details
    TargetField('ownershipStatus','Ownership Status',     false),
    TargetField('purchaseDate',   'Purchase Date',        false),
    TargetField('purchasePrice',  'Purchase Price (\$)',   false),
    TargetField('soldDate',       'Sold Date',            false),
    TargetField('soldPrice',      'Sold Price (\$)',       false),
    TargetField('soldTo',         'Sold To (Buyer)',      false),
    TargetField('deceasedDate',   'Deceased Date',        false),
    TargetField('deceasedReason', 'Deceased Reason',      false),
  ];

  static const weightFields = [
    TargetField('animalId',   'Animal Name/ID',   true),
    TargetField('weightDate', 'Weigh Date',       true),
    TargetField('weightLbs',  'Weight (lbs)',     false),
    TargetField('weightKg',   'Weight (kg)',      false),
    TargetField('notes',      'Notes',            false),
  ];

  static const healthFields = [
    TargetField('animalId',     'Animal Name/ID',   true),
    TargetField('date',         'Record Date',      true),
    TargetField('recordType',   'Record Type',      true),
    TargetField('description',  'Description',      false),
    TargetField('medication',   'Medication',       false),
    TargetField('dosage',       'Dosage',           false),
    TargetField('famachaScore', 'FAMACHA Score',    false),
    TargetField('fecCount',     'FEC Count',        false),
  ];

  static const breedingFields = [
    TargetField('doeName',        'Doe Name/ID',          true),
    TargetField('buckName',       'Buck Name/ID',         true),
    TargetField('breedingDate',   'Breeding Date',        true),
    TargetField('expectedKidDate','Expected Kid Date',    false),
    TargetField('method',         'Breeding Method',      false),
    TargetField('confirmed',      'Confirmed Pregnant',   false),
  ];
}

class TargetField {
  final String key;
  final String displayName;
  final bool isRequired;
  const TargetField(this.key, this.displayName, this.isRequired);
}
