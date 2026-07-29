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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cotisations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            membre_id INTEGER NOT NULL,
            montant REAL NOT NULL,
            date_cotisation TEXT NOT NULL,
            statut_sync TEXT DEFAULT 'PENDING' -- PENDING ou SYNCED
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,       -- ex: 'AJOUT_COTISATION'
            endpoint TEXT NOT NULL,     -- ex: '/cotisations'
            method TEXT NOT NULL,       -- ex: 'POST'
            payload TEXT NOT NULL,      -- JSON des données
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

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

  static Future<List<Map<String, dynamic>>> getCotisationsMembre(int membreId) async {
    final db = await database;
    return await db.query(
      'cotisations',
      where: 'membre_id = ?',
      whereArgs: [membreId],
      orderBy: 'date_cotisation DESC',
    );
  }

  static Future<void> addToSyncQueue({
    required String action,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'action': action,
      'endpoint': endpoint,
      'method': method,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}