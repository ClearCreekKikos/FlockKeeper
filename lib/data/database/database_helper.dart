// lib/data/database/database_helper.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../shared/utils/date_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  final Map<String, Set<String>> _tableColumnsCache = {};

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // ─── Database Version ────────────────────────────────────────────────────
  static const int _dbVersion = 13;
  static const String _dbName = 'flockkeeper.db';

  // ─── Table Names ─────────────────────────────────────────────────────────
  static const String tableAnimals = 'animals';
  static const String tableWeightRecords = 'weight_records';
  static const String tableBreedingEvents = 'incubation_batches';
  static const String tableKiddingRecords = 'hatch_records';
  static const String tableHealthRecords = 'health_records';
  static const String tablePastures = 'pastures';
  static const String tablePastureHistory = 'pasture_history';
  static const String tableVaccinations = 'vaccinations';
  static const String tableDewormings = 'dewormings';
  static const String tableFinancialRecords = 'financial_records';
  static const String tableReminders = 'reminders';
  static const String tableNotes = 'notes';
  static const String tableInventoryItems = 'inventory_items';
  static const String tableInventoryUsage = 'inventory_usage';
  static const String tableSuppliers = 'suppliers';
  static const String tableSettings = 'settings';
  static const String tableMilkingRecords = 'egg_collections';
  static const String tableMeatRecords = 'meat_records';

  // ─── Singleton Database Getter ────────────────────────────────────────────
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<String> _getDatabasePathInternal() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return inMemoryDatabasePath;
    }
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        final appDir = join(localAppData, 'FlockKeeper');
        await Directory(appDir).create(recursive: true);
        return join(appDir, _dbName);
      }
    }
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  // ─── Initialize Database ──────────────────────────────────────────────────
  Future<Database> _initDatabase() async {
    final path = await _getDatabasePathInternal();
    debugPrint('DEBUG: SQLite Database is located at: $path');

    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );

    await _normalizeDateFormats(db);
    return db;
  }

  Future<void> _normalizeDateFormats(Database db) async {
    final tables = [
      'animals',
      'weight_records',
      'breeding_events',
      'kidding_records',
      'health_records',
      'pastures',
      'pasture_history',
      'vaccinations',
      'dewormings',
      'financial_records',
      'reminders',
      'notes',
      'settings',
      'inventory_items',
      'inventory_usage',
      'suppliers',
    ];

    await db.transaction((txn) async {
      for (final table in tables) {
        try {
          // Query the actual columns in this table to avoid referencing
          // columns that don't exist (e.g. inventory_usage has no updated_at).
          final columns = await txn.rawQuery('PRAGMA table_info($table)');
          final columnNames = columns.map((c) => c['name'] as String).toSet();

          final hasUpdatedAt = columnNames.contains('updated_at');
          final hasCreatedAt = columnNames.contains('created_at');

          if (hasUpdatedAt) {
            await txn.execute('''
              UPDATE $table 
              SET updated_at = replace(updated_at, ' ', 'T') || 'Z'
              WHERE updated_at LIKE '% %' AND updated_at NOT LIKE '%T%'
            ''');
            await txn.execute('''
              UPDATE $table 
              SET updated_at = replace(updated_at, 'ZZ', 'Z')
              WHERE updated_at LIKE '%ZZ'
            ''');
          }

          if (hasCreatedAt) {
            await txn.execute('''
              UPDATE $table 
              SET created_at = replace(created_at, ' ', 'T') || 'Z'
              WHERE created_at LIKE '% %' AND created_at NOT LIKE '%T%'
            ''');
            await txn.execute('''
              UPDATE $table 
              SET created_at = replace(created_at, 'ZZ', 'Z')
              WHERE created_at LIKE '%ZZ'
            ''');
          }
        } catch (e) {
          debugPrint('Error normalizing dates in $table: $e');
        }
      }

      // Also normalize deleted_records table
      try {
        await txn.execute('''
          UPDATE deleted_records 
          SET deleted_at = replace(deleted_at, ' ', 'T') || 'Z'
          WHERE deleted_at LIKE '% %' AND deleted_at NOT LIKE '%T%'
        ''');
        await txn.execute('''
          UPDATE deleted_records 
          SET deleted_at = replace(deleted_at, 'ZZ', 'Z')
          WHERE deleted_at LIKE '%ZZ'
        ''');
      } catch (e) {
        debugPrint('Error normalizing dates in deleted_records: $e');
      }
    });
  }

  // Enable foreign keys
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // ─── Create Tables ────────────────────────────────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    await _createAnimalsTable(db);
    await _createWeightRecordsTable(db);
    await _createBreedingEventsTable(db);
    await _createKiddingRecordsTable(db);
    await _createHealthRecordsTable(db);
    await _createPasturesTable(db);
    await _createPastureHistoryTable(db);
    await _createVaccinationsTable(db);
    await _createDewormingsTable(db);
    await _createFinancialRecordsTable(db);
    await _createRemindersTable(db);
    await _createNotesTable(db);
    await _createSettingsTable(db);
    await _createSuppliersTable(db);
    await _createInventoryItemsTable(db);
    await _createInventoryUsageTable(db);
    await _createDeletedRecordsTable(db);
    await _createMilkingRecordsTable(db);
    await _createMeatRecordsTable(db);
    await _createDeleteTriggers(db);
    await _insertDefaultSettings(db);
    await _insertDefaultSuppliers(db);
    await _insertDefaultInventoryItems(db);
  }

  // ─── Animals Table ────────────────────────────────────────────────────────
  Future<void> _createAnimalsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableAnimals (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        name              TEXT NOT NULL,
        barn_name         TEXT,
        band_number       TEXT,
        nkr_reg_number    TEXT, -- Retained for compatibility
        tattoo            TEXT,
        ear_tag           TEXT,
        rfid_tag          TEXT,
        dob               TEXT,
        sex               TEXT NOT NULL CHECK(sex IN ('hen','rooster','pullet','cockerel','chick','mixed','unknown','doe','buck','wether')),
        color             TEXT,
        markings          TEXT,
        registry          TEXT,
        breed_type        TEXT,
        herd_book         TEXT,
        vgl_id            TEXT,
        eid_type          TEXT,
        eid_placement     TEXT,
        id_tag_number     TEXT,
        id_tag_placement  TEXT,
        scrapie_tag       TEXT,
        eye_color         TEXT,
        ear_type          TEXT,
        horn_type         TEXT,
        description       TEXT,
        ownership_status  TEXT,
        breed             TEXT DEFAULT 'Mixed',
        dam_id            INTEGER,
        sire_id           INTEGER,
        dam_name          TEXT,
        sire_name         TEXT,
        dam_reg_number    TEXT,
        sire_reg_number   TEXT,
        status            TEXT NOT NULL DEFAULT 'active'
                          CHECK(status IN ('active','sold','deceased','culled','transferred','ancestor')),
        birth_weight_lbs  REAL,
        purchase_date     TEXT,
        purchase_price    REAL,
        sold_date         TEXT,
        sold_price        REAL,
        sold_to           TEXT,
        deceased_date     TEXT,
        deceased_reason   TEXT,
        photo_path        TEXT,
        notes             TEXT,
        is_herd_sire      INTEGER NOT NULL DEFAULT 0,
        is_registered     INTEGER NOT NULL DEFAULT 0,
        second_registry   TEXT,
        second_reg_number TEXT,
        is_flock          INTEGER NOT NULL DEFAULT 0,
        quantity          INTEGER NOT NULL DEFAULT 1,
        created_at        TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (dam_id)  REFERENCES $tableAnimals(id) ON DELETE SET NULL,
        FOREIGN KEY (sire_id) REFERENCES $tableAnimals(id) ON DELETE SET NULL
      )
    ''');

    // Indexes for common queries
    await db.execute(
      'CREATE INDEX idx_animals_status ON $tableAnimals(status)',
    );
    await db.execute('CREATE INDEX idx_animals_sex ON $tableAnimals(sex)');
    await db.execute(
      'CREATE INDEX idx_animals_band ON $tableAnimals(band_number)',
    );
  }

  // ─── Weight Records Table ─────────────────────────────────────────────────
  Future<void> _createWeightRecordsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableWeightRecords (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id   INTEGER NOT NULL,
        weigh_date  TEXT NOT NULL,
        weight_lbs  REAL NOT NULL,
        weight_kg   REAL,
        body_condition_score  INTEGER CHECK(body_condition_score BETWEEN 1 AND 5),
        notes       TEXT,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (animal_id) REFERENCES $tableAnimals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_weights_animal ON $tableWeightRecords(animal_id)',
    );
    await db.execute(
      'CREATE INDEX idx_weights_date ON $tableWeightRecords(weigh_date)',
    );
  }

  // ─── Breeding Events Table ────────────────────────────────────────────────
  Future<void> _createBreedingEventsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableBreedingEvents (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        rooster_id          INTEGER,
        buck_id             INTEGER, -- Retained for compatibility
        flock_id            INTEGER NOT NULL,
        doe_id              INTEGER NOT NULL, -- Retained for compatibility
        rooster_name        TEXT,
        buck_name           TEXT, -- Retained for compatibility
        flock_name          TEXT,
        doe_name            TEXT, -- Retained for compatibility
        set_date            TEXT NOT NULL,
        breeding_date       TEXT NOT NULL, -- Retained for compatibility
        expected_hatch_date TEXT,
        expected_kid_date   TEXT, -- Retained for compatibility
        actual_hatch_date   TEXT,
        actual_kid_date     TEXT, -- Retained for compatibility
        method              TEXT DEFAULT 'incubator'
                            CHECK(method IN ('incubator','broody_hen')),
        eggs_set            INTEGER NOT NULL DEFAULT 0,
        confirmed_pregnant  INTEGER NOT NULL DEFAULT 0, -- Retained for compatibility
        fertile_count       INTEGER NOT NULL DEFAULT 0,
        outcome             TEXT CHECK(outcome IN ('hatched','failed','ongoing','unknown')),
        notes               TEXT,
        created_at          TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at          TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (rooster_id) REFERENCES $tableAnimals(id) ON DELETE SET NULL,
        FOREIGN KEY (flock_id)   REFERENCES $tableAnimals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_incubation_flock ON $tableBreedingEvents(flock_id)',
    );
    await db.execute(
      'CREATE INDEX idx_incubation_rooster ON $tableBreedingEvents(rooster_id)',
    );
    await db.execute(
      'CREATE INDEX idx_incubation_date ON $tableBreedingEvents(set_date)',
    );
  }

  // ─── Kidding Records Table ────────────────────────────────────────────────
  Future<void> _createKiddingRecordsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableKiddingRecords (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_id            INTEGER,
        breeding_event_id   INTEGER, -- Retained for compatibility
        flock_id            INTEGER NOT NULL,
        doe_id              INTEGER NOT NULL, -- Retained for compatibility
        rooster_id          INTEGER,
        buck_id             INTEGER, -- Retained for compatibility
        chick_id            INTEGER,
        kid_id              INTEGER, -- Retained for compatibility
        chick_name          TEXT,
        kid_name            TEXT, -- Retained for compatibility
        hatch_date          TEXT NOT NULL,
        kidding_date        TEXT NOT NULL, -- Retained for compatibility
        hatch_order         INTEGER,
        birth_order         INTEGER, -- Retained for compatibility
        chicks_hatched      INTEGER,
        litter_size         INTEGER, -- Retained for compatibility
        birth_weight_lbs    REAL,
        sex                 TEXT,
        survival_status     TEXT DEFAULT 'alive'
                            CHECK(survival_status IN ('alive','deceased','sold')),
        complications       TEXT,
        dam_condition_score INTEGER,
        received_colostrum  INTEGER,
        bottle_fed          INTEGER,
        presentation        TEXT,
        birth_type          TEXT,
        notes               TEXT,
        created_at          TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at          TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (batch_id) REFERENCES $tableBreedingEvents(id) ON DELETE SET NULL,
        FOREIGN KEY (flock_id)  REFERENCES $tableAnimals(id) ON DELETE CASCADE,
        FOREIGN KEY (rooster_id) REFERENCES $tableAnimals(id) ON DELETE SET NULL,
        FOREIGN KEY (chick_id)  REFERENCES $tableAnimals(id) ON DELETE SET NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_hatch_flock ON $tableKiddingRecords(flock_id)',
    );
    await db.execute(
      'CREATE INDEX idx_hatch_date ON $tableKiddingRecords(hatch_date)',
    );
  }

  // ─── Health Records Table ─────────────────────────────────────────────────
  Future<void> _createHealthRecordsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableHealthRecords (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id         INTEGER NOT NULL,
        record_date       TEXT NOT NULL,
        record_type       TEXT NOT NULL,
        diagnosis         TEXT,
        treatment         TEXT,
        dosage            TEXT,
        administrator     TEXT,
        famacha_score     INTEGER,
        bcs_score         REAL,
        withdrawal_days   INTEGER,
        withdrawal_date   TEXT,
        lab_name          TEXT,
        lab_reference_number TEXT,
        follow_up_date    TEXT,
        cost              REAL,
        resolved          INTEGER NOT NULL DEFAULT 1,
        notes             TEXT,
        created_at        TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (animal_id) REFERENCES $tableAnimals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_health_animal ON $tableHealthRecords(animal_id)',
    );
    await db.execute(
      'CREATE INDEX idx_health_date ON $tableHealthRecords(record_date)',
    );
    await db.execute(
      'CREATE INDEX idx_health_type ON $tableHealthRecords(record_type)',
    );
  }

  // ─── Pastures Table ───────────────────────────────────────────────────────
  Future<void> _createPasturesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablePastures (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        name                  TEXT NOT NULL,
        acreage               REAL,
        description           TEXT,
        forage_type           TEXT,
        water_source          TEXT,
        fencing_type          TEXT,
        carrying_capacity     INTEGER,
        current_animal_count  INTEGER DEFAULT 0,
        status                TEXT DEFAULT 'available'
                              CHECK(status IN ('available','occupied',
                                               'resting','maintenance')),
        last_grazed_date      TEXT,
        available_date        TEXT,
        rest_days_target      INTEGER DEFAULT 30,
        notes                 TEXT,
        boundary_polygon      TEXT,
        created_at            TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at            TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  // ─── Pasture History Table ────────────────────────────────────────────────
  Future<void> _createPastureHistoryTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tablePastureHistory (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        pasture_id      INTEGER NOT NULL,
        animal_id       INTEGER,
        group_name      TEXT,
        move_in_date    TEXT NOT NULL,
        move_out_date   TEXT,
        animal_count    INTEGER,
        forage_condition_in   TEXT
                              CHECK(forage_condition_in IN
                                ('excellent','good','fair','poor')),
        forage_condition_out  TEXT
                              CHECK(forage_condition_out IN
                                ('excellent','good','fair','poor')),
        notes           TEXT,
        created_at      TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (pasture_id) REFERENCES $tablePastures(id) ON DELETE CASCADE,
        FOREIGN KEY (animal_id)  REFERENCES $tableAnimals(id)  ON DELETE SET NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_pasture_hist_pasture ON $tablePastureHistory(pasture_id)',
    );
  }

  // ─── Vaccinations Table ───────────────────────────────────────────────────
  Future<void> _createVaccinationsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableVaccinations (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id         INTEGER NOT NULL,
        vaccine_name      TEXT NOT NULL,
        vaccine_type      TEXT,
        given_date        TEXT NOT NULL,
        next_due_date     TEXT,
        lot_number        TEXT,
        manufacturer      TEXT,
        dosage_ml         REAL,
        administered_by   TEXT,
        injection_site    TEXT,
        cost              REAL,
        notes             TEXT,
        created_at        TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (animal_id) REFERENCES $tableAnimals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_vacc_animal ON $tableVaccinations(animal_id)',
    );
    await db.execute(
      'CREATE INDEX idx_vacc_due ON $tableVaccinations(next_due_date)',
    );
  }

  // ─── Dewormings Table ─────────────────────────────────────────────────────
  Future<void> _createDewormingsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableDewormings (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id         INTEGER NOT NULL,
        deworming_date    TEXT NOT NULL,
        famacha_score     INTEGER CHECK(famacha_score BETWEEN 1 AND 5),
        fec_count         REAL,
        product_name      TEXT,
        active_ingredient TEXT,
        dosage_ml         REAL,
        weight_at_time_lbs REAL,
        withdrawal_days   INTEGER,
        withdrawal_date   TEXT,
        administered_by   TEXT,
        cost              REAL,
        next_check_date   TEXT,
        notes             TEXT,
        created_at        TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (animal_id) REFERENCES $tableAnimals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_deworm_animal ON $tableDewormings(animal_id)',
    );
    await db.execute(
      'CREATE INDEX idx_deworm_date ON $tableDewormings(deworming_date)',
    );
  }

  // ─── Financial Records Table ──────────────────────────────────────────────
  Future<void> _createFinancialRecordsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableFinancialRecords (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id       INTEGER,
        record_date     TEXT NOT NULL,
        category        TEXT NOT NULL
                        CHECK(category IN ('purchase','sale','feed','medication',
                                           'veterinary','equipment','pasture',
                                           'registration','other')),
        type            TEXT NOT NULL CHECK(type IN ('income','expense')),
        amount          REAL NOT NULL,
        description     TEXT,
        vendor_buyer    TEXT,
        receipt_number  TEXT,
        notes           TEXT,
        created_at      TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (animal_id) REFERENCES $tableAnimals(id) ON DELETE SET NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_finance_date ON $tableFinancialRecords(record_date)',
    );
    await db.execute(
      'CREATE INDEX idx_finance_category ON $tableFinancialRecords(category)',
    );
  }

  // ─── Reminders Table ──────────────────────────────────────────────────────
  Future<void> _createRemindersTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableReminders (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id       INTEGER,
        title           TEXT NOT NULL,
        description     TEXT,
        reminder_date   TEXT NOT NULL,
        reminder_type   TEXT
                        CHECK(reminder_type IN ('vaccination','deworming',
                                                'breeding','kidding','weigh',
                                                'vet','pasture','custom')),
        is_completed    INTEGER NOT NULL DEFAULT 0,
        completed_date  TEXT,
        is_recurring    INTEGER NOT NULL DEFAULT 0,
        recurrence_days INTEGER,
        notify_days_before INTEGER DEFAULT 3,
        created_at      TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (animal_id) REFERENCES $tableAnimals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_reminders_date ON $tableReminders(reminder_date)',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_completed ON $tableReminders(is_completed)',
    );
  }

  // ─── Notes Table ──────────────────────────────────────────────────────────
  Future<void> _createNotesTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableNotes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id   INTEGER,
        pasture_id  INTEGER,
        note_date   TEXT NOT NULL,
        title       TEXT,
        body        TEXT NOT NULL,
        category    TEXT,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (animal_id)  REFERENCES $tableAnimals(id)  ON DELETE CASCADE,
        FOREIGN KEY (pasture_id) REFERENCES $tablePastures(id) ON DELETE CASCADE
      )
    ''');
  }

  // ─── Settings Table ───────────────────────────────────────────────────────
  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableSettings (
        key         TEXT PRIMARY KEY,
        value       TEXT NOT NULL,
        updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final defaults = {
      'farm_name': 'My Chicken Ranch',
      'owner_name': '',
      'weight_unit': 'lbs',
      'dark_mode': 'false',
      'default_breed': 'Mixed',
      'gestation_days': '21',
      'notify_days_before': '3',
      'currency': 'USD',
      'backup_enabled': 'false',
    };

    for (final entry in defaults.entries) {
      await db.insert(tableSettings, {
        'key': entry.key,
        'value': entry.value,
        'updated_at': '1970-01-01T00:00:00.000Z',
      });
    }
  }

  // ─── Migration Handler ────────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _migrateV1toV2(db);
    }
    if (oldVersion < 3) {
      await _migrateV2toV3(db);
    }
    if (oldVersion < 4) {
      await _migrateV3toV4(db);
    }
    if (oldVersion < 5) {
      await _migrateV4toV5(db);
    }
    if (oldVersion < 6) {
      await _migrateV5toV6(db);
    }
    if (oldVersion < 7) {
      await _migrateV6toV7(db);
    }
    if (oldVersion < 8) {
      await _migrateV7toV8(db);
    }
    if (oldVersion < 9) {
      await _migrateV8toV9(db);
    }
    if (oldVersion < 10) {
      await _migrateV9toV10(db);
    }
    if (oldVersion < 11) {
      await _migrateV10toV11(db);
    }
    if (oldVersion < 12) {
      await _migrateV11toV12(db);
    }
    if (oldVersion < 13) {
      await _migrateV12toV13(db);
    }
  }

  Future<void> _migrateV12toV13(Database db) async {
    await _createMilkingRecordsTable(db);
    await _createMeatRecordsTable(db);
  }

  Future<void> _migrateV11toV12(Database db) async {
    await _addColumnIfNotExists(db, tablePastures, 'boundary_polygon', 'TEXT');
  }

  Future<void> _migrateV10toV11(Database db) async {
    await _addColumnIfNotExists(db, tableAnimals, 'second_registry', 'TEXT');
    await _addColumnIfNotExists(db, tableAnimals, 'second_reg_number', 'TEXT');
  }

  Future<void> _migrateV9toV10(Database db) async {
    // Set all default-like un-tracked items to inactive
    await db.execute('''
      UPDATE $tableInventoryItems
      SET is_active = 0
      WHERE current_quantity = 0 
        AND cost_per_unit = 0 
        AND supplier_id IS NULL
        AND barcode IS NULL
        AND (notes IS NULL OR notes = '')
    ''');
  }

  Future<void> _migrateV6toV7(Database db) async {
    await _addColumnIfNotExists(db, tableAnimals, 'vgl_id', 'TEXT');
    await db.execute(
      "UPDATE $tableAnimals SET ear_tag = id_tag_number WHERE (ear_tag IS NULL OR ear_tag = '') AND (id_tag_number IS NOT NULL AND id_tag_number != '')",
    );
    // Only clear id_tag_number for rows where it now duplicates ear_tag (i.e.
    // the value was just copied above, or was already identical). Rows whose
    // ear_tag holds a different value keep their distinct id_tag_number so it
    // is not silently destroyed on upgrade.
    await db.execute(
      "UPDATE $tableAnimals SET id_tag_number = NULL WHERE id_tag_number = ear_tag",
    );
  }

  Future<void> _migrateV7toV8(Database db) async {
    await _createSuppliersTable(db);
    await _createInventoryItemsTable(db);
    await _createInventoryUsageTable(db);
    await _insertDefaultSuppliers(db);
    await _insertDefaultInventoryItems(db);
    // Register delete triggers for the new tables
    for (final table in ['inventory_items', 'inventory_usage', 'suppliers']) {
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${table}_delete
        AFTER DELETE ON $table
        BEGIN
          INSERT INTO deleted_records (table_name, record_id)
          VALUES ('$table', OLD.id);
        END;
      ''');
    }
  }

  Future<void> _migrateV8toV9(Database db) async {
    await _addColumnIfNotExists(
      db,
      tableInventoryItems,
      'is_active',
      'INTEGER NOT NULL DEFAULT 1',
    );
  }

  // ─── Suppliers Table ──────────────────────────────────────────────────────
  Future<void> _createSuppliersTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSuppliers (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT NOT NULL,
        contact_info  TEXT,
        website       TEXT,
        notes         TEXT,
        created_at    TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  // ─── Inventory Items Table ────────────────────────────────────────────────
  Future<void> _createInventoryItemsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableInventoryItems (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        name              TEXT NOT NULL,
        category          TEXT NOT NULL,
        unit              TEXT NOT NULL DEFAULT 'each',
        current_quantity  REAL NOT NULL DEFAULT 0,
        minimum_quantity  REAL NOT NULL DEFAULT 1,
        cost_per_unit     REAL NOT NULL DEFAULT 0,
        supplier_id       INTEGER,
        supplier_name     TEXT,
        expiration_date   TEXT,
        barcode           TEXT,
        notes             TEXT,
        is_active         INTEGER NOT NULL DEFAULT 1,
        created_at        TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (supplier_id) REFERENCES $tableSuppliers(id) ON DELETE SET NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inventory_category ON $tableInventoryItems(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inventory_barcode ON $tableInventoryItems(barcode)',
    );
  }

  // ─── Inventory Usage Table ────────────────────────────────────────────────
  Future<void> _createInventoryUsageTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableInventoryUsage (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        inventory_item_id   INTEGER NOT NULL,
        quantity_used       REAL NOT NULL,
        usage_date          TEXT NOT NULL,
        notes               TEXT,
        created_at          TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (inventory_item_id) REFERENCES $tableInventoryItems(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_usage_item ON $tableInventoryUsage(inventory_item_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_usage_date ON $tableInventoryUsage(usage_date)',
    );
  }

  // ─── Default Suppliers Seed ───────────────────────────────────────────────
  Future<void> _insertDefaultSuppliers(dynamic db) async {
    final suppliers = [
      {'name': 'Tractor Supply Co.', 'website': 'https://www.tractorsupply.com'},
      {'name': 'Premier1 Supplies', 'website': 'https://www.premier1supplies.com'},
      {'name': 'Jeffers Pet', 'website': 'https://www.jefferspet.com'},
      {'name': 'Valley Vet Supply', 'website': 'https://www.valleyvet.com'},
      {'name': 'PBS Animal Health', 'website': 'https://www.pbsanimalhealth.com'},
      {'name': 'Hoegger Supply', 'website': 'https://hfrgoats.com'},
      {'name': 'Caprine Supply', 'website': 'https://www.caprinesupply.com'},
    ];
    final now = DateTime.now().toUtc().toIso8601String();
    for (final s in suppliers) {
      await db.insert(tableSuppliers, {
        ...s,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // ─── Default Inventory Items Seed ─────────────────────────────────────────
  Future<void> _insertDefaultInventoryItems(dynamic db) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final items = <Map<String, dynamic>>[
      // ── Health & Medical ──────────────────────────────────────────────────
      {'name': 'CDT Vaccine', 'category': 'health_medical', 'unit': 'doses'},
      {'name': 'BoSe', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'LA-200 (Oxytetracycline)', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Penicillin G', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Banamine (Flunixin)', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Electrolytes (Bounce Back / ReSorb)', 'category': 'health_medical', 'unit': 'packets'},
      {'name': 'Probiotics', 'category': 'health_medical', 'unit': 'tubes'},
      {'name': 'Activated Charcoal', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Kaolin-Pectin', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Red Cell (Iron Supplement)', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Vitamin B Complex', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Vitamin B12', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Nutri-Drench', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Ivermectin', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Cydectin', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Valbazen', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'SafeGuard', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Toltrazuril / Baycox (Coccidia)', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Needles 18g', 'category': 'health_medical', 'unit': 'boxes'},
      {'name': 'Needles 20g', 'category': 'health_medical', 'unit': 'boxes'},
      {'name': 'Needles 22g', 'category': 'health_medical', 'unit': 'boxes'},
      {'name': 'Syringes 3cc', 'category': 'health_medical', 'unit': 'boxes'},
      {'name': 'Syringes 6cc', 'category': 'health_medical', 'unit': 'boxes'},
      {'name': 'Syringes 12cc', 'category': 'health_medical', 'unit': 'boxes'},
      {'name': 'Syringes 20cc', 'category': 'health_medical', 'unit': 'boxes'},
      {'name': 'Alcohol Wipes', 'category': 'health_medical', 'unit': 'boxes'},
      {'name': 'Betadine / Chlorhexidine', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Blu-Kote / Wound Spray', 'category': 'health_medical', 'unit': 'cans'},
      {'name': 'Blood Stop Powder', 'category': 'health_medical', 'unit': 'bottles'},
      {'name': 'Vet Wrap', 'category': 'health_medical', 'unit': 'rolls'},
      {'name': 'Gauze Pads', 'category': 'health_medical', 'unit': 'boxes'},
      {'name': 'Digital Thermometer', 'category': 'health_medical', 'unit': 'each'},
      {'name': 'Stethoscope', 'category': 'health_medical', 'unit': 'each'},
      {'name': 'Hoof Rot Treatment (Kopertox)', 'category': 'health_medical', 'unit': 'bottles'},

      // ── Hoof & Grooming ───────────────────────────────────────────────────
      {'name': 'Hoof Trimmers', 'category': 'hoof_grooming', 'unit': 'pairs'},
      {'name': 'Hoof Rasp', 'category': 'hoof_grooming', 'unit': 'each'},
      {'name': 'Hoof Pick', 'category': 'hoof_grooming', 'unit': 'each'},
      {'name': 'Hoof Blocks', 'category': 'hoof_grooming', 'unit': 'each'},
      {'name': 'Clippers', 'category': 'hoof_grooming', 'unit': 'each'},
      {'name': 'Blade Oil & Cleaner', 'category': 'hoof_grooming', 'unit': 'bottles'},

      // ── Kidding Supplies ──────────────────────────────────────────────────
      {'name': 'OB Gloves', 'category': 'kidding', 'unit': 'boxes'},
      {'name': 'Lubricant', 'category': 'kidding', 'unit': 'bottles'},
      {'name': 'Kid Puller', 'category': 'kidding', 'unit': 'each'},
      {'name': 'Iodine / Navel Dip', 'category': 'kidding', 'unit': 'bottles'},
      {'name': 'Towels', 'category': 'kidding', 'unit': 'packs'},
      {'name': 'Kid Bottles', 'category': 'kidding', 'unit': 'each'},
      {'name': 'Pritchard Nipples', 'category': 'kidding', 'unit': 'each'},
      {'name': 'Colostrum Replacer', 'category': 'kidding', 'unit': 'bags'},
      {'name': 'Milk Replacer', 'category': 'kidding', 'unit': 'bags'},
      {'name': 'Tube-Feeding Kit', 'category': 'kidding', 'unit': 'each'},
      {'name': 'Heat Lamps / Heat Pads', 'category': 'kidding', 'unit': 'each'},
      {'name': 'Kidding Record Sheets', 'category': 'kidding', 'unit': 'pads'},

      // ── Working / Chute Day ───────────────────────────────────────────────
      {'name': 'FAMACHA Cards', 'category': 'working_chute', 'unit': 'each'},
      {'name': 'Body Condition Score Chart', 'category': 'working_chute', 'unit': 'each'},
      {'name': 'Scale Batteries', 'category': 'working_chute', 'unit': 'packs'},
      {'name': 'Extra Ear Tags', 'category': 'working_chute', 'unit': 'bags'},
      {'name': 'Tagger (Qwik-Tag / Shearwell)', 'category': 'working_chute', 'unit': 'each'},
      {'name': 'Tattoo Kit', 'category': 'working_chute', 'unit': 'each'},
      {'name': 'Tattoo Ink', 'category': 'working_chute', 'unit': 'bottles'},
      {'name': 'Castration Bands', 'category': 'working_chute', 'unit': 'bags'},
      {'name': 'Bander Tool', 'category': 'working_chute', 'unit': 'each'},
      {'name': 'Gloves', 'category': 'working_chute', 'unit': 'boxes'},
      {'name': 'Spray Paint / Chalk Markers', 'category': 'working_chute', 'unit': 'cans'},
      {'name': 'Sorting Panels', 'category': 'working_chute', 'unit': 'each'},
      {'name': 'Halters', 'category': 'working_chute', 'unit': 'each'},
      {'name': 'Ropes', 'category': 'working_chute', 'unit': 'each'},
      {'name': 'Extra Batteries for Devices', 'category': 'working_chute', 'unit': 'packs'},

      // ── Cleaning & Sanitation ─────────────────────────────────────────────
      {'name': 'Bleach', 'category': 'cleaning', 'unit': 'gallons'},
      {'name': 'Chlorhexidine Solution', 'category': 'cleaning', 'unit': 'bottles'},
      {'name': 'Barn Lime', 'category': 'cleaning', 'unit': 'bags'},
      {'name': 'Fly Spray', 'category': 'cleaning', 'unit': 'bottles'},
      {'name': 'Fly Traps', 'category': 'cleaning', 'unit': 'packs'},
      {'name': 'Disinfectant Wipes', 'category': 'cleaning', 'unit': 'containers'},
      {'name': 'Trash Bags', 'category': 'cleaning', 'unit': 'rolls'},
      {'name': 'Paper Towels', 'category': 'cleaning', 'unit': 'rolls'},

      // ── Feed & Nutrition ──────────────────────────────────────────────────
      {'name': 'Loose Minerals (Goat-Specific)', 'category': 'feed_nutrition', 'unit': 'bags'},
      {'name': 'Baking Soda', 'category': 'feed_nutrition', 'unit': 'bags'},
      {'name': 'Mineral Feeders', 'category': 'feed_nutrition', 'unit': 'each'},
      {'name': 'Salt Blocks', 'category': 'feed_nutrition', 'unit': 'each'},
      {'name': 'Grain', 'category': 'feed_nutrition', 'unit': 'bags'},
      {'name': 'Alfalfa Pellets', 'category': 'feed_nutrition', 'unit': 'bags'},
      {'name': 'Black Oil Sunflower Seeds (BOSS)', 'category': 'feed_nutrition', 'unit': 'bags'},
      {'name': 'Molasses', 'category': 'feed_nutrition', 'unit': 'gallons'},
      {'name': 'Feed Scoops', 'category': 'feed_nutrition', 'unit': 'each'},
      {'name': 'Feed Buckets', 'category': 'feed_nutrition', 'unit': 'each'},
      {'name': 'Hay Nets / Feeders', 'category': 'feed_nutrition', 'unit': 'each'},

      // ── Fencing & Pasture ─────────────────────────────────────────────────
      {'name': 'Electric Fence Polywire', 'category': 'fencing_pasture', 'unit': 'rolls'},
      {'name': 'Step-In Posts', 'category': 'fencing_pasture', 'unit': 'each'},
      {'name': 'Insulators', 'category': 'fencing_pasture', 'unit': 'bags'},
      {'name': 'Fence Tester', 'category': 'fencing_pasture', 'unit': 'each'},
      {'name': 'Extra Energizer Batteries', 'category': 'fencing_pasture', 'unit': 'packs'},
      {'name': 'T-Post Clips', 'category': 'fencing_pasture', 'unit': 'bags'},
      {'name': 'Zip Ties (Fencing)', 'category': 'fencing_pasture', 'unit': 'bags'},
      {'name': 'Gate Hardware', 'category': 'fencing_pasture', 'unit': 'sets'},
      {'name': 'Water Hose Repair Ends', 'category': 'fencing_pasture', 'unit': 'packs'},
      {'name': 'Float Valves', 'category': 'fencing_pasture', 'unit': 'each'},
      {'name': 'Water Trough Plugs', 'category': 'fencing_pasture', 'unit': 'each'},

      // ── General Ranch Tools ───────────────────────────────────────────────
      {'name': 'Zip Ties', 'category': 'general_tools', 'unit': 'bags'},
      {'name': 'Duct Tape', 'category': 'general_tools', 'unit': 'rolls'},
      {'name': 'Baling Twine', 'category': 'general_tools', 'unit': 'rolls'},
      {'name': 'Utility Knife', 'category': 'general_tools', 'unit': 'each'},
      {'name': 'Flashlights', 'category': 'general_tools', 'unit': 'each'},
      {'name': 'Headlamps', 'category': 'general_tools', 'unit': 'each'},
      {'name': 'Batteries (AA/AAA/D)', 'category': 'general_tools', 'unit': 'packs'},
      {'name': 'Extension Cords', 'category': 'general_tools', 'unit': 'each'},
      {'name': '5-Gallon Buckets', 'category': 'general_tools', 'unit': 'each'},
      {'name': 'S-Hooks', 'category': 'general_tools', 'unit': 'packs'},
      {'name': 'Carabiners', 'category': 'general_tools', 'unit': 'packs'},
      {'name': 'Ratchet Straps', 'category': 'general_tools', 'unit': 'each'},

      // ── Paperwork & Admin ─────────────────────────────────────────────────
      {'name': 'Bill of Sale Forms', 'category': 'paperwork', 'unit': 'pads'},
      {'name': 'Registry Forms', 'category': 'paperwork', 'unit': 'pads'},
      {'name': 'Weigh-In Sheets', 'category': 'paperwork', 'unit': 'pads'},
      {'name': 'Breeding Cards', 'category': 'paperwork', 'unit': 'pads'},
      {'name': 'Pasture Rotation Notes', 'category': 'paperwork', 'unit': 'pads'},
      {'name': 'Buyer Packets', 'category': 'paperwork', 'unit': 'packs'},
    ];

    for (final item in items) {
      await db.insert(tableInventoryItems, {
        ...item,
        'current_quantity': 0,
        'minimum_quantity': 1,
        'cost_per_unit': 0,
        'is_active': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> _migrateV5toV6(Database db) async {
    await _addColumnIfNotExists(db, tableAnimals, 'herd_book', 'TEXT');
    await db.execute('UPDATE $tableAnimals SET herd_book = breed_type');
  }

  Future<void> _migrateV2toV3(Database db) async {
    await db.transaction((txn) async {
      // Create deleted_records table
      await _createDeletedRecordsTable(txn);

      // Add updated_at column to tables that don't have it
      final tablesToAlter = [
        'weight_records',
        'kidding_records',
        'pasture_history',
        'vaccinations',
        'dewormings',
        'financial_records',
        'reminders',
      ];

      for (final table in tablesToAlter) {
        try {
          await txn.execute(
            'ALTER TABLE $table ADD COLUMN updated_at TEXT NOT NULL DEFAULT (datetime(\'now\'))',
          );
        } catch (_) {
          // Ignore if column already exists
        }
      }

      // Create triggers
      await _createDeleteTriggers(txn);
    });
  }

  Future<void> _migrateV3toV4(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.transaction((txn) async {
      // Recreate all tables whose foreign keys might be pointing to animals_old

      // 1. weight_records
      await txn.execute('DROP INDEX IF EXISTS idx_weights_animal');
      await txn.execute('DROP INDEX IF EXISTS idx_weights_date');
      await txn.execute(
        'ALTER TABLE $tableWeightRecords RENAME TO weight_records_old',
      );
      await _createWeightRecordsTable(txn);
      await txn.execute(
        'INSERT INTO $tableWeightRecords (id, animal_id, weigh_date, weight_lbs, body_condition_score, notes, created_at, updated_at) SELECT id, animal_id, weigh_date, weight_lbs, body_condition_score, notes, created_at, updated_at FROM weight_records_old',
      );
      await txn.execute('DROP TABLE weight_records_old');

      // 2. breeding_events
      await txn.execute('DROP INDEX IF EXISTS idx_breeding_doe');
      await txn.execute('DROP INDEX IF EXISTS idx_breeding_buck');
      await txn.execute('DROP INDEX IF EXISTS idx_breeding_date');
      await txn.execute(
        'ALTER TABLE $tableBreedingEvents RENAME TO breeding_events_old',
      );
      await _createBreedingEventsTable(txn);
      await txn.execute(
        'INSERT INTO $tableBreedingEvents (id, buck_id, doe_id, buck_name, doe_name, breeding_date, expected_kid_date, actual_kid_date, method, confirmed_pregnant, confirmation_date, confirmation_method, outcome, notes, created_at, updated_at) SELECT id, buck_id, doe_id, buck_name, doe_name, breeding_date, expected_kid_date, actual_kid_date, method, confirmed_pregnant, confirmation_date, confirmation_method, outcome, notes, created_at, updated_at FROM breeding_events_old',
      );
      await txn.execute('DROP TABLE breeding_events_old');

      // 3. kidding_records
      await txn.execute('DROP INDEX IF EXISTS idx_kidding_doe');
      await txn.execute('DROP INDEX IF EXISTS idx_kidding_date');
      await txn.execute(
        'ALTER TABLE $tableKiddingRecords RENAME TO kidding_records_old',
      );
      await _createKiddingRecordsTable(txn);
      await txn.execute(
        'INSERT INTO $tableKiddingRecords (id, breeding_event_id, doe_id, buck_id, kid_id, kid_name, kidding_date, birth_order, litter_size, birth_weight_lbs, sex, birth_type, presentation, survival_status, received_colostrum, bottle_fed, dam_condition_score, complications, notes, created_at, updated_at) SELECT id, breeding_event_id, doe_id, buck_id, kid_id, kid_name, kidding_date, birth_order, litter_size, birth_weight_lbs, sex, birth_type, presentation, survival_status, received_colostrum, bottle_fed, dam_condition_score, complications, notes, created_at, updated_at FROM kidding_records_old',
      );
      await txn.execute('DROP TABLE kidding_records_old');

      // 4. health_records
      await txn.execute('DROP INDEX IF EXISTS idx_health_animal');
      await txn.execute('DROP INDEX IF EXISTS idx_health_date');
      await txn.execute('DROP INDEX IF EXISTS idx_health_type');
      await txn.execute(
        'ALTER TABLE $tableHealthRecords RENAME TO health_records_old',
      );
      await _createHealthRecordsTable(txn);
      await txn.execute(
        'INSERT INTO $tableHealthRecords (id, animal_id, record_date, record_type, diagnosis, treatment, dosage, administrator, famacha_score, bcs_score, withdrawal_days, withdrawal_date, lab_name, lab_reference_number, follow_up_date, cost, resolved, notes, created_at, updated_at) SELECT id, animal_id, record_date, record_type, diagnosis, treatment, dosage, administrator, famacha_score, bcs_score, withdrawal_days, withdrawal_date, lab_name, lab_reference_number, follow_up_date, cost, resolved, notes, created_at, updated_at FROM health_records_old',
      );
      await txn.execute('DROP TABLE health_records_old');

      // 5. pasture_history
      await txn.execute('DROP INDEX IF EXISTS idx_pasture_hist_pasture');
      await txn.execute(
        'ALTER TABLE $tablePastureHistory RENAME TO pasture_history_old',
      );
      await _createPastureHistoryTable(txn);
      await txn.execute(
        'INSERT INTO $tablePastureHistory (id, pasture_id, animal_id, group_name, move_in_date, move_out_date, animal_count, forage_condition_in, forage_condition_out, notes, created_at, updated_at) SELECT id, pasture_id, animal_id, group_name, move_in_date, move_out_date, animal_count, forage_condition_in, forage_condition_out, notes, created_at, updated_at FROM pasture_history_old',
      );
      await txn.execute('DROP TABLE pasture_history_old');

      // 6. vaccinations
      await txn.execute('DROP INDEX IF EXISTS idx_vacc_animal');
      await txn.execute('DROP INDEX IF EXISTS idx_vacc_due');
      await txn.execute(
        'ALTER TABLE $tableVaccinations RENAME TO vaccinations_old',
      );
      await _createVaccinationsTable(txn);
      await txn.execute(
        'INSERT INTO $tableVaccinations (id, animal_id, vaccine_name, vaccine_type, given_date, next_due_date, lot_number, manufacturer, dosage_ml, administered_by, injection_site, cost, notes, created_at, updated_at) SELECT id, animal_id, vaccine_name, vaccine_type, given_date, next_due_date, lot_number, manufacturer, dosage_ml, administered_by, injection_site, cost, notes, created_at, updated_at FROM vaccinations_old',
      );
      await txn.execute('DROP TABLE vaccinations_old');

      // 7. dewormings
      await txn.execute('DROP INDEX IF EXISTS idx_deworm_animal');
      await txn.execute('DROP INDEX IF EXISTS idx_deworm_date');
      await txn.execute(
        'ALTER TABLE $tableDewormings RENAME TO dewormings_old',
      );
      await _createDewormingsTable(txn);
      await txn.execute(
        'INSERT INTO $tableDewormings (id, animal_id, deworming_date, famacha_score, fec_count, product_name, active_ingredient, dosage_ml, weight_at_time_lbs, withdrawal_days, withdrawal_date, administered_by, cost, next_check_date, notes, created_at, updated_at) SELECT id, animal_id, deworming_date, famacha_score, fec_count, product_name, active_ingredient, dosage_ml, weight_at_time_lbs, withdrawal_days, withdrawal_date, administered_by, cost, next_check_date, notes, created_at, updated_at FROM dewormings_old',
      );
      await txn.execute('DROP TABLE dewormings_old');

      // 8. financial_records
      await txn.execute('DROP INDEX IF EXISTS idx_finance_date');
      await txn.execute('DROP INDEX IF EXISTS idx_finance_category');
      await txn.execute(
        'ALTER TABLE $tableFinancialRecords RENAME TO financial_records_old',
      );
      await _createFinancialRecordsTable(txn);
      await txn.execute(
        'INSERT INTO $tableFinancialRecords (id, animal_id, record_date, category, type, amount, description, vendor_buyer, receipt_number, notes, created_at, updated_at) SELECT id, animal_id, record_date, category, type, amount, description, vendor_buyer, receipt_number, notes, created_at, updated_at FROM financial_records_old',
      );
      await txn.execute('DROP TABLE financial_records_old');

      // 9. reminders
      await txn.execute('DROP INDEX IF EXISTS idx_reminders_date');
      await txn.execute('DROP INDEX IF EXISTS idx_reminders_completed');
      await txn.execute('ALTER TABLE $tableReminders RENAME TO reminders_old');
      await _createRemindersTable(txn);
      await txn.execute(
        'INSERT INTO $tableReminders (id, animal_id, title, description, reminder_date, reminder_type, is_completed, completed_date, is_recurring, recurrence_days, notify_days_before, created_at, updated_at) SELECT id, animal_id, title, description, reminder_date, reminder_type, is_completed, completed_date, is_recurring, recurrence_days, notify_days_before, created_at, updated_at FROM reminders_old',
      );
      await txn.execute('DROP TABLE reminders_old');

      // 10. notes
      await txn.execute('ALTER TABLE $tableNotes RENAME TO notes_old');
      await _createNotesTable(txn);
      await txn.execute(
        'INSERT INTO $tableNotes (id, animal_id, pasture_id, note_date, title, body, category, created_at, updated_at) SELECT id, animal_id, pasture_id, note_date, title, body, category, created_at, updated_at FROM notes_old',
      );
      await txn.execute('DROP TABLE notes_old');

      // Recreate all triggers for these tables since dropping tables automatically drops their triggers
      await _createDeleteTriggers(txn);
    });
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _migrateV4toV5(Database db) async {
    await _addColumnIfNotExists(db, tableAnimals, 'ear_tag', 'TEXT');
  }

  Future<void> _addColumnIfNotExists(
    Database db,
    String tableName,
    String columnName,
    String columnDefinition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final hasColumn = columns.any((column) => column['name'] == columnName);
    if (!hasColumn) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition',
      );
    }
  }

  Future<void> _createDeletedRecordsTable(dynamic dbOrTxn) async {
    await dbOrTxn.execute('''
      CREATE TABLE IF NOT EXISTS deleted_records (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name  TEXT NOT NULL,
        record_id   INTEGER NOT NULL,
        deleted_at  TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _createMilkingRecordsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMilkingRecords (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id       INTEGER NOT NULL,
        collection_date TEXT NOT NULL,
        milking_date    TEXT NOT NULL, -- Retained for compatibility
        session         TEXT,
        egg_count       INTEGER NOT NULL,
        yield_lbs       REAL NOT NULL, -- Retained for compatibility
        broken_count    INTEGER DEFAULT 0,
        average_weight_g REAL,
        fat_percent     REAL, -- Retained for compatibility
        notes           TEXT,
        created_at      TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (animal_id) REFERENCES $tableAnimals(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_milking_animal ON $tableMilkingRecords(animal_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_milking_date ON $tableMilkingRecords(milking_date)');
  }

  Future<void> _createMeatRecordsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableMeatRecords (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id           INTEGER NOT NULL,
        record_date         TEXT NOT NULL,
        slaughter_date      TEXT,
        live_weight_lbs     REAL,
        hanging_weight_lbs  REAL,
        dressing_percent    REAL,
        cut_yield_lbs       REAL,
        yield_grade         TEXT,
        notes               TEXT,
        created_at          TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at          TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (animal_id) REFERENCES $tableAnimals(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_meat_animal ON $tableMeatRecords(animal_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_meat_date ON $tableMeatRecords(record_date)');
  }

  Future<void> _createDeleteTriggers(dynamic dbOrTxn) async {
    final tablesToTrack = [
      'animals',
      'weight_records',
      'incubation_batches',
      'hatch_records',
      'health_records',
      'pastures',
      'pasture_history',
      'vaccinations',
      'dewormings',
      'financial_records',
      'reminders',
      'notes',
      'inventory_items',
      'inventory_usage',
      'suppliers',
    ];

    for (final table in tablesToTrack) {
      await dbOrTxn.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_${table}_delete
        AFTER DELETE ON $table
        BEGIN
          INSERT INTO deleted_records (table_name, record_id)
          VALUES ('$table', OLD.id);
        END;
      ''');
    }
  }

  Future<void> _migrateV1toV2(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.transaction((txn) async {
      // 1. Rename existing table
      await txn.execute('ALTER TABLE $tableAnimals RENAME TO animals_old');

      // 2. Create new table with updated check constraint
      await txn.execute('''
        CREATE TABLE $tableAnimals (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          name              TEXT NOT NULL,
          barn_name         TEXT,
          nkr_reg_number    TEXT,
          tattoo            TEXT,
          rfid_tag          TEXT,
          dob               TEXT,
          sex               TEXT NOT NULL CHECK(sex IN ('doe','buck','wether','unknown')),
          color             TEXT,
          markings          TEXT,
          registry          TEXT,
          breed_type        TEXT,
          eid_type          TEXT,
          eid_placement     TEXT,
          id_tag_number     TEXT,
          id_tag_placement  TEXT,
          scrapie_tag       TEXT,
          eye_color         TEXT,
          ear_type          TEXT,
          horn_type         TEXT,
          description       TEXT,
          ownership_status  TEXT,
          breed             TEXT DEFAULT 'Kiko',
          dam_id            INTEGER,
          sire_id           INTEGER,
          dam_name          TEXT,
          sire_name         TEXT,
          dam_reg_number    TEXT,
          sire_reg_number   TEXT,
          status            TEXT NOT NULL DEFAULT 'active'
                            CHECK(status IN ('active','sold','deceased','culled','transferred','ancestor')),
          birth_weight_lbs  REAL,
          purchase_date     TEXT,
          purchase_price    REAL,
          sold_date         TEXT,
          sold_price        REAL,
          sold_to           TEXT,
          deceased_date     TEXT,
          deceased_reason   TEXT,
          photo_path        TEXT,
          notes             TEXT,
          is_herd_sire      INTEGER NOT NULL DEFAULT 0,
          is_registered     INTEGER NOT NULL DEFAULT 0,
          created_at        TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at        TEXT NOT NULL DEFAULT (datetime('now')),
          FOREIGN KEY (dam_id)  REFERENCES $tableAnimals(id) ON DELETE SET NULL,
          FOREIGN KEY (sire_id) REFERENCES $tableAnimals(id) ON DELETE SET NULL
        )
      ''');

      // 3. Copy data from old to new
      await txn.execute('''
        INSERT INTO $tableAnimals (
          id, name, barn_name, nkr_reg_number, tattoo, rfid_tag, dob, sex, color,
          markings, registry, breed_type, eid_type, eid_placement, id_tag_number,
          id_tag_placement, scrapie_tag, eye_color, ear_type, horn_type, description,
          ownership_status, breed, dam_id, sire_id, dam_name, sire_name, dam_reg_number,
          sire_reg_number, status, birth_weight_lbs, purchase_date, purchase_price,
          sold_date, sold_price, sold_to, deceased_date, deceased_reason, photo_path,
          notes, is_herd_sire, is_registered, created_at, updated_at
        )
        SELECT 
          id, name, barn_name, nkr_reg_number, tattoo, rfid_tag, dob, sex, color,
          markings, registry, breed_type, eid_type, eid_placement, id_tag_number,
          id_tag_placement, scrapie_tag, eye_color, ear_type, horn_type, description,
          ownership_status, breed, dam_id, sire_id, dam_name, sire_name, dam_reg_number,
          sire_reg_number, status, birth_weight_lbs, purchase_date, purchase_price,
          sold_date, sold_price, sold_to, deceased_date, deceased_reason, photo_path,
          notes, is_herd_sire, is_registered, created_at, updated_at
        FROM animals_old
      ''');

      // 4. Drop old table
      await txn.execute('DROP TABLE animals_old');

      // 5. Recreate indexes
      await txn.execute(
        'CREATE INDEX idx_animals_status ON $tableAnimals(status)',
      );
      await txn.execute('CREATE INDEX idx_animals_sex ON $tableAnimals(sex)');
      await txn.execute(
        'CREATE INDEX idx_animals_nkr ON $tableAnimals(nkr_reg_number)',
      );
    });
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // ─── Generic CRUD Helpers ─────────────────────────────────────────────────

  Future<Set<String>> _getTableColumns(String table) async {
    if (_tableColumnsCache.containsKey(table)) {
      return _tableColumnsCache[table]!;
    }
    final db = await database;
    final results = await db.rawQuery('PRAGMA table_info($table)');
    final columns = results.map((c) => c['name'] as String).toSet();
    _tableColumnsCache[table] = columns;
    return columns;
  }

  /// Insert a row and return the new row id
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    final Map<String, dynamic> mutableData = Map.from(data);
    mutableData.remove('user_id');

    final columns = await _getTableColumns(table);
    mutableData.removeWhere((key, value) => !columns.contains(key));

    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (table != 'settings' && table != 'deleted_records') {
      if (!mutableData.containsKey('updated_at') ||
          mutableData['updated_at'] == null) {
        mutableData['updated_at'] = nowIso;
      } else {
        final val = mutableData['updated_at'];
        mutableData['updated_at'] = parseDateTimeSafe(
          val,
        ).toUtc().toIso8601String();
      }
      if (!mutableData.containsKey('created_at') ||
          mutableData['created_at'] == null) {
        mutableData['created_at'] = nowIso;
      } else {
        final val = mutableData['created_at'];
        mutableData['created_at'] = parseDateTimeSafe(
          val,
        ).toUtc().toIso8601String();
      }
    } else if (table == 'settings') {
      if (!mutableData.containsKey('updated_at') ||
          mutableData['updated_at'] == null) {
        mutableData['updated_at'] = nowIso;
      } else {
        final val = mutableData['updated_at'];
        mutableData['updated_at'] = parseDateTimeSafe(
          val,
        ).toUtc().toIso8601String();
      }
    } else if (table == 'deleted_records') {
      if (!mutableData.containsKey('deleted_at') ||
          mutableData['deleted_at'] == null) {
        mutableData['deleted_at'] = nowIso;
      } else {
        final val = mutableData['deleted_at'];
        mutableData['deleted_at'] = parseDateTimeSafe(
          val,
        ).toUtc().toIso8601String();
      }
    }

    return await db.insert(
      table,
      mutableData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Query rows with optional where clause
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
    List<String>? columns,
  }) async {
    final db = await database;
    return await db.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Update rows matching the where clause
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    final Map<String, dynamic> mutableData = Map.from(data);
    mutableData.remove('user_id');

    final columns = await _getTableColumns(table);
    mutableData.removeWhere((key, value) => !columns.contains(key));

    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (table == 'deleted_records') {
      mutableData['deleted_at'] = nowIso;
    } else {
      mutableData['updated_at'] = nowIso;
    }

    if (mutableData.containsKey('created_at')) {
      final val = mutableData['created_at'];
      mutableData['created_at'] = parseDateTimeSafe(
        val,
      ).toUtc().toIso8601String();
    }

    return await db.update(
      table,
      mutableData,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Delete rows matching the where clause
  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Execute a raw SQL query (for complex joins, etc.)
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, args);
  }

  /// Execute raw SQL (for updates/deletes with complex logic)
  Future<void> execute(String sql, [List<dynamic>? args]) async {
    final db = await database;
    await db.execute(sql, args);
  }

  /// Run multiple operations in a single transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // ─── Settings Helpers ─────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final results = await query(
      tableSettings,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(tableSettings, {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Clear all user data from the database (e.g. on logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      final tables = [
        tableAnimals,
        tableWeightRecords,
        tableBreedingEvents,
        tableKiddingRecords,
        tableHealthRecords,
        tablePastures,
        tablePastureHistory,
        tableVaccinations,
        tableDewormings,
        tableFinancialRecords,
        tableReminders,
        tableNotes,
        tableMilkingRecords,
        tableMeatRecords,
        'deleted_records',
      ];
      for (final table in tables) {
        await txn.delete(table);
      }

      // Reset settings
      await txn.delete(tableSettings);
    });
    // Re-insert default settings
    await _insertDefaultSettings(db);
  }

  // ─── Database Maintenance ─────────────────────────────────────────────────

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Per-user profile/identity settings that must NOT leak across user
  /// switches. Device/app preferences (theme, voice) and sync/auth keys
  /// (sync_*, logged_in_user_id) are intentionally excluded so they survive.
  static const List<String> userProfileSettingKeys = [
    'farm_name',
    'farm_logo_path',
    'farm_address',
    'farm_phone',
    'farm_email',
    'owner_name',
    'nkr_client_id',
    'nkr_herd_prefix',
    'is_premium',
  ];

  /// Clear all user-owned data tables and per-user profile settings.
  /// Called when a different user logs in so they start with a clean local
  /// slate. Supabase sync repopulates data and profile for the new user
  /// afterwards. Device preferences and sync/auth settings are preserved.
  Future<void> clearUserData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in [
        tableAnimals,
        tableWeightRecords,
        tableBreedingEvents,
        tableKiddingRecords,
        tableHealthRecords,
        tablePastures,
        tablePastureHistory,
        tableVaccinations,
        tableDewormings,
        tableFinancialRecords,
        tableReminders,
        tableNotes,
      ]) {
        await txn.delete(table);
      }

      // Clear the previous user's profile/identity so it is not displayed
      // for — or pushed up to the cloud account of — the new user.
      for (final key in userProfileSettingKeys) {
        await txn.delete(tableSettings, where: 'key = ?', whereArgs: [key]);
      }

      // The deletes above fire AFTER DELETE triggers that log every row into
      // deleted_records. This is a local cache reset for a user switch, NOT a
      // user-initiated deletion, so those entries must be purged — otherwise
      // the next sync would push them as cloud deletions and could remove the
      // NEW user's cloud records that happen to share the same local IDs.
      // Must run last, after the table deletes have fired their triggers.
      await txn.delete('deleted_records');
    });
    debugPrint('🗄️ Local user data and profile cleared for new user session');
  }

  /// Clears only the per-user profile/identity settings from this device,
  /// leaving all herd data, device preferences, and sync/auth keys intact.
  /// Used by the in-app "Reset Ranch Profile" action.
  Future<void> clearLocalProfileSettings() async {
    final db = await database;
    for (final key in userProfileSettingKeys) {
      await db.delete(tableSettings, where: 'key = ?', whereArgs: [key]);
    }
  }

  /// Delete the entire database (use with extreme caution!)
  Future<void> deleteDatabase() async {
    final path = await _getDatabasePathInternal();
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  /// Get database file path (useful for backup)
  Future<String> getDatabasePath() async {
    return await _getDatabasePathInternal();
  }
}
