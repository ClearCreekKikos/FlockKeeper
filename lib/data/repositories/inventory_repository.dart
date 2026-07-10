// lib/data/repositories/inventory_repository.dart

import '../database/database_helper.dart';
import '../models/inventory_item_model.dart';
import '../models/inventory_usage_model.dart';

class InventoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Create ───────────────────────────────────────────────────────────────

  Future<int> insertItem(InventoryItem item) async {
    final now = DateTime.now();
    final itemWithTimestamp = item.copyWith(
      createdAt: now,
      updatedAt: now,
    );
    return await _dbHelper.insert(
      DatabaseHelper.tableInventoryItems,
      itemWithTimestamp.toMap(),
    );
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getAllItems({bool includeInactive = false}) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableInventoryItems,
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'category ASC, name ASC',
    );
    return maps.map((m) => InventoryItem.fromMap(m)).toList();
  }

  Future<InventoryItem?> getItemById(int id) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableInventoryItems,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return InventoryItem.fromMap(maps.first);
  }

  Future<List<InventoryItem>> getItemsByCategory(String category, {bool includeInactive = false}) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableInventoryItems,
      where: includeInactive ? 'category = ?' : 'category = ? AND is_active = 1',
      whereArgs: [category],
      orderBy: 'name ASC',
    );
    return maps.map((m) => InventoryItem.fromMap(m)).toList();
  }

  /// Returns items where current_quantity <= minimum_quantity and
  /// minimum_quantity > 0, and is_active = 1.
  Future<List<InventoryItem>> getLowStockItems() async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableInventoryItems,
      where: 'current_quantity <= minimum_quantity AND minimum_quantity > 0 AND is_active = 1',
      orderBy: 'current_quantity ASC, name ASC',
    );
    return maps.map((m) => InventoryItem.fromMap(m)).toList();
  }

  /// Returns items whose expiration_date is within [withinDays] from now and is_active = 1.
  Future<List<InventoryItem>> getExpiringItems(int withinDays) async {
    final cutoff = DateTime.now().add(Duration(days: withinDays));
    final maps = await _dbHelper.query(
      DatabaseHelper.tableInventoryItems,
      where: "expiration_date IS NOT NULL AND expiration_date != '' AND expiration_date <= ? AND is_active = 1",
      whereArgs: [cutoff.toIso8601String()],
      orderBy: 'expiration_date ASC',
    );
    return maps.map((m) => InventoryItem.fromMap(m)).toList();
  }

  /// Lookup an item by its barcode / QR code string.
  Future<InventoryItem?> getItemByBarcode(String code) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableInventoryItems,
      where: 'barcode = ? AND is_active = 1',
      whereArgs: [code],
    );
    if (maps.isEmpty) return null;
    return InventoryItem.fromMap(maps.first);
  }

  /// Search items by name (partial, case-insensitive).
  Future<List<InventoryItem>> searchItems(String query, {bool includeInactive = false}) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableInventoryItems,
      where: includeInactive ? 'name LIKE ?' : 'name LIKE ? AND is_active = 1',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((m) => InventoryItem.fromMap(m)).toList();
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  Future<int> updateItem(InventoryItem item) async {
    if (item.id == null) {
      throw Exception('Cannot update an inventory item without an ID');
    }
    final itemWithTimestamp = item.copyWith(updatedAt: DateTime.now());
    return await _dbHelper.update(
      DatabaseHelper.tableInventoryItems,
      itemWithTimestamp.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Adjust quantity by [delta] (positive = add stock, negative = use stock).
  Future<void> adjustQuantity(int itemId, double delta, {String? notes}) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
      'UPDATE ${DatabaseHelper.tableInventoryItems} '
      'SET current_quantity = MAX(0, current_quantity + ?), '
      '    updated_at = ? '
      'WHERE id = ?',
      [delta, DateTime.now().toUtc().toIso8601String(), itemId],
    );
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<int> deleteItem(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableInventoryItems,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── Usage Logging ────────────────────────────────────────────────────────

  /// Log a usage event and decrement stock in a single transaction.
  Future<void> logUsage(InventoryUsage usage) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();

      // Insert usage record
      final usageMap = usage.toMap();
      usageMap.remove('id');
      usageMap['created_at'] = now;
      await txn.insert(DatabaseHelper.tableInventoryUsage, usageMap);

      // Decrement stock (clamp to 0)
      await txn.rawUpdate(
        'UPDATE ${DatabaseHelper.tableInventoryItems} '
        'SET current_quantity = MAX(0, current_quantity - ?), '
        '    updated_at = ? '
        'WHERE id = ?',
        [usage.quantityUsed, now, usage.inventoryItemId],
      );
    });
  }

  /// Get usage history for a specific item, newest first.
  Future<List<InventoryUsage>> getUsageHistory(int itemId) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableInventoryUsage,
      where: 'inventory_item_id = ?',
      whereArgs: [itemId],
      orderBy: 'usage_date DESC, id DESC',
    );
    return maps.map((m) => InventoryUsage.fromMap(m)).toList();
  }

  /// Get all usage records, newest first.
  Future<List<InventoryUsage>> getAllUsageHistory() async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableInventoryUsage,
      orderBy: 'usage_date DESC, id DESC',
    );
    return maps.map((m) => InventoryUsage.fromMap(m)).toList();
  }
}
