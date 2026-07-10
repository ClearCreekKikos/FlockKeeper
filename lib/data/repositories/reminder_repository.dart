// lib/data/repositories/reminder_repository.dart

import '../database/database_helper.dart';
import '../models/reminder_model.dart';

class ReminderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Create ───────────────────────────────────────────────────────────────
  Future<int> insertReminder(Reminder reminder) async {
    final now = DateTime.now();
    final toSave = reminder.copyWith(
      createdAt: now,
      updatedAt: now,
    );

    return await _dbHelper.insert(
      DatabaseHelper.tableReminders,
      toSave.toMap(),
    );
  }

  // ─── Read ─────────────────────────────────────────────────────────────────
  Future<Reminder?> getReminderById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*, a.name as animal_name
      FROM ${DatabaseHelper.tableReminders} r
      LEFT JOIN ${DatabaseHelper.tableAnimals} a ON r.animal_id = a.id
      WHERE r.id = ?
    ''', [id]);

    if (maps.isEmpty) return null;
    return Reminder.fromMap(maps.first);
  }

  Future<List<Reminder>> getAllReminders() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*, a.name as animal_name
      FROM ${DatabaseHelper.tableReminders} r
      LEFT JOIN ${DatabaseHelper.tableAnimals} a ON r.animal_id = a.id
      ORDER BY r.reminder_date ASC
    ''');
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  Future<List<Reminder>> getRemindersForAnimal(int animalId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*, a.name as animal_name
      FROM ${DatabaseHelper.tableReminders} r
      LEFT JOIN ${DatabaseHelper.tableAnimals} a ON r.animal_id = a.id
      WHERE r.animal_id = ? OR r.animal_id IS NULL
      ORDER BY r.reminder_date ASC
    ''', [animalId]);
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  Future<List<Reminder>> getUpcomingActiveReminders() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT r.*, a.name as animal_name
      FROM ${DatabaseHelper.tableReminders} r
      LEFT JOIN ${DatabaseHelper.tableAnimals} a ON r.animal_id = a.id
      WHERE r.is_completed = 0
      ORDER BY r.reminder_date ASC
    ''');
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  // ─── Update ───────────────────────────────────────────────────────────────
  Future<int> updateReminder(Reminder reminder) async {
    if (reminder.id == null) {
      throw Exception('Cannot update a reminder without an ID');
    }

    final toSave = reminder.copyWith(
      updatedAt: DateTime.now(),
    );

    return await _dbHelper.update(
      DatabaseHelper.tableReminders,
      toSave.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  // ─── Complete & Handle Recurrence ─────────────────────────────────────────
  Future<void> completeReminder(int id, DateTime completedDate) async {
    final reminder = await getReminderById(id);
    if (reminder == null) return;

    // 1. Mark current reminder as completed
    final completedReminder = reminder.copyWith(
      isCompleted: true,
      completedDate: completedDate,
    );
    await updateReminder(completedReminder);

    // 2. If it is recurring, insert the next occurrence
    if (reminder.isRecurring &&
        reminder.recurrenceDays != null &&
        reminder.recurrenceDays! > 0) {
      final nextDate = reminder.reminderDate.add(Duration(days: reminder.recurrenceDays!));
      final nextReminder = Reminder(
        animalId: reminder.animalId,
        title: reminder.title,
        description: reminder.description,
        reminderDate: nextDate,
        reminderType: reminder.reminderType,
        isCompleted: false,
        isRecurring: true,
        recurrenceDays: reminder.recurrenceDays,
        notifyDaysBefore: reminder.notifyDaysBefore,
      );
      await insertReminder(nextReminder);
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────────
  Future<int> deleteReminder(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableReminders,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
