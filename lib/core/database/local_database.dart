import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/participant.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('scanner_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Participants table (mirror of Supabase)
    await db.execute('''
      CREATE TABLE event_participants (
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        mobile TEXT,
        organization TEXT,
        event_id TEXT,
        reg_status TEXT,
        is_checked_in INTEGER,
        checked_in_at TEXT,
        checked_in_by TEXT,
        total_meals_taken INTEGER DEFAULT 0
      )
    ''');

    // Meal redemptions table
    await db.execute('''
      CREATE TABLE meal_redemptions (
        id TEXT PRIMARY KEY,
        participant_id TEXT,
        session_name TEXT,
        redeemed_at TEXT,
        scanned_by TEXT
      )
    ''');

    // Sync queue for offline actions
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // --- Participants ---
  Future<void> clearParticipants() async {
    final db = await instance.database;
    await db.delete('event_participants');
  }

  Future<void> insertParticipants(List<Participant> participants) async {
    final db = await instance.database;
    Batch batch = db.batch();
    for (var p in participants) {
      batch.insert('event_participants', p.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Participant?> getParticipant(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'event_participants',
      where: 'id = ? OR event_id = ?',
      whereArgs: [id, id],
    );

    if (maps.isNotEmpty) {
      return Participant.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<void> updateParticipant(Participant participant) async {
    final db = await instance.database;
    await db.update(
      'event_participants',
      participant.toJson(),
      where: 'id = ?',
      whereArgs: [participant.id],
    );
  }

  Future<List<Participant>> searchParticipants(String query) async {
    final db = await instance.database;
    final maps = await db.query(
      'event_participants',
      where: 'name LIKE ? OR email LIKE ? OR event_id LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      limit: 10,
    );
    return maps.map((map) => Participant.fromJson(map)).toList();
  }

  // --- Meal Redemptions ---
  Future<void> clearMealRedemptions() async {
    final db = await instance.database;
    await db.delete('meal_redemptions');
  }

  Future<void> insertMealRedemptions(List<Map<String, dynamic>> redemptions) async {
    final db = await instance.database;
    Batch batch = db.batch();
    for (var r in redemptions) {
      batch.insert('meal_redemptions', r, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<bool> hasRedeemedMeal(String participantId, String sessionName) async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM meal_redemptions WHERE participant_id = ? AND session_name = ?',
      [participantId, sessionName]
    ));
    return (count ?? 0) > 0;
  }

  Future<void> addMealRedemption(String id, String participantId, String sessionName, String scannedBy) async {
    final db = await instance.database;
    await db.insert('meal_redemptions', {
      'id': id,
      'participant_id': participantId,
      'session_name': sessionName,
      'redeemed_at': DateTime.now().toIso8601String(),
      'scanned_by': scannedBy,
    });
  }

  // --- Stats ---
  Future<int> getTotalParticipants() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM event_participants')) ?? 0;
  }

  Future<int> getCheckedInCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM event_participants WHERE is_checked_in = 1')) ?? 0;
  }

  Future<int> getMealsServedCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM meal_redemptions')) ?? 0;
  }

  // --- Sync Queue ---
  Future<void> addToQueue(String action, Map<String, dynamic> payload) async {
    final db = await instance.database;
    await db.insert('sync_queue', {
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final db = await instance.database;
    return await db.query('sync_queue', orderBy: 'id ASC');
  }

  Future<void> removeFromQueue(int id) async {
    final db = await instance.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}
