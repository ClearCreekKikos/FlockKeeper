// lib/data/repositories/supplier_repository.dart

import '../database/database_helper.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─── Create ───────────────────────────────────────────────────────────────

  Future<int> insertSupplier(Supplier supplier) async {
    final now = DateTime.now();
    final supplierWithTimestamp = supplier.copyWith(
      createdAt: now,
      updatedAt: now,
    );
    return await _dbHelper.insert(
      DatabaseHelper.tableSuppliers,
      supplierWithTimestamp.toMap(),
    );
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  Future<List<Supplier>> getAllSuppliers() async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableSuppliers,
      orderBy: 'name ASC',
    );
    return maps.map((m) => Supplier.fromMap(m)).toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    final maps = await _dbHelper.query(
      DatabaseHelper.tableSuppliers,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Supplier.fromMap(maps.first);
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  Future<int> updateSupplier(Supplier supplier) async {
    if (supplier.id == null) {
      throw Exception('Cannot update a supplier without an ID');
    }
    final supplierWithTimestamp = supplier.copyWith(
      updatedAt: DateTime.now(),
    );
    return await _dbHelper.update(
      DatabaseHelper.tableSuppliers,
      supplierWithTimestamp.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<int> deleteSupplier(int id) async {
    return await _dbHelper.delete(
      DatabaseHelper.tableSuppliers,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
