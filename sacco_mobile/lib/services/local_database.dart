import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sacco_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table pour la mise en cache des réponses GET
        await db.execute('''
          CREATE TABLE app_cache (
            key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        // Table pour la file d'attente de synchronisation
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            endpoint TEXT NOT NULL,
            method TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        // Table pour les cotisations enregistrées en local
        await db.execute('''
          CREATE TABLE cotisations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            membre_id INTEGER NOT NULL,
            montant REAL NOT NULL,
            date_cotisation TEXT NOT NULL,
            statut_sync TEXT DEFAULT 'PENDING'
          )
        ''');
      },
    );
  }

  // --- Gestion du Cache (GET) ---
  static Future<void> cacheData(String key, dynamic data) async {
    final db = await database;
    await db.insert(
      'app_cache',
      {
        'key': key,
        'data': jsonEncode(data),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<dynamic> getCachedData(String key) async {
    final db = await database;
    final maps = await db.query('app_cache', where: 'key = ?', whereArgs: [key]);
    if (maps.isNotEmpty) {
      return jsonDecode(maps.first['data'] as String);
    }
    return null;
  }

  // --- Gestion de la File d'attente (Sync Queue) ---
  // Notez l'ordre précis des arguments pour correspondre à api_service.dart
  static Future<void> addToSyncQueue(String endpoint, String method, Map<String, dynamic> payload, {String action = 'API_SYNC'}) async {
    final db = await database;
    await db.insert('sync_queue', {
      'action': action,
      'endpoint': endpoint,
      'method': method,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingSyncQueue() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'id ASC');
  }

  static Future<void> deleteFromSyncQueue(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // --- Cotisations Locales ---
  static Future<int> insertCotisationLocal({
    required int membreId,
    required double montant,
    required String date,
  }) async {
    final db = await database;
    return await db.insert('cotisations', {
      'membre_id': membreId,
      'montant': montant,
      'date_cotisation': date,
      'statut_sync': 'PENDING',
    });
  }
}