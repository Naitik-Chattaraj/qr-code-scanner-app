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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Participants table matching live Supabase event_participants
    await db.execute('''
      CREATE TABLE event_participants (
        participant_id TEXT PRIMARY KEY,
        event_id TEXT,
        name TEXT,
        email TEXT,
        mobile_number TEXT,
        organization TEXT,
        is_registered INTEGER,
        registered_at TEXT,
        scanned_at TEXT,
        scanned_by TEXT,
        dinner_status INTEGER,
        dinner_scanned_at TEXT
      )
    ''');

    // Meal redemptions table matching live Supabase meal_redemptions
    // Uses composite PRIMARY KEY (participant_id, meal_session) to strictly prevent duplicates
    await db.execute('''
      CREATE TABLE meal_redemptions (
        id TEXT,
        participant_id TEXT NOT NULL,
        meal_session TEXT NOT NULL,
        scanned_at TEXT,
        scanned_by TEXT,
        PRIMARY KEY (participant_id, meal_session)
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

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS event_participants');
      await db.execute('DROP TABLE IF EXISTS meal_redemptions');
      await db.execute('DROP TABLE IF EXISTS sync_queue');
      await _createDB(db, newVersion);
      return;
    }

    if (oldVersion < 3) {
      // Deduplicate and migrate meal_redemptions table to have (participant_id, meal_session) as primary key
      await db.execute('''
        CREATE TABLE IF NOT EXISTS meal_redemptions_v3 (
          id TEXT,
          participant_id TEXT NOT NULL,
          meal_session TEXT NOT NULL,
          scanned_at TEXT,
          scanned_by TEXT,
          PRIMARY KEY (participant_id, meal_session)
        )
      ''');
      try {
        await db.execute('''
          INSERT OR REPLACE INTO meal_redemptions_v3 (id, participant_id, meal_session, scanned_at, scanned_by)
          SELECT id, participant_id, meal_session, scanned_at, scanned_by 
          FROM meal_redemptions
          GROUP BY participant_id, meal_session
        ''');
        await db.execute('DROP TABLE meal_redemptions');
      } catch (_) {}
      await db.execute('ALTER TABLE meal_redemptions_v3 RENAME TO meal_redemptions');
    }
  }

  // --- Participants ---
  Future<void> clearParticipants() async {
    final db = await instance.database;
    await db.delete('event_participants');
  }

  Future<void> insertParticipants(List<Participant> participants) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var p in participants) {
      batch.insert(
        'event_participants',
        p.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Participant?> getParticipant(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'event_participants',
      where: 'participant_id = ? OR event_id = ?',
      whereArgs: [id, id],
    );

    if (maps.isNotEmpty) {
      return Participant.fromJson(maps.first);
    }
    return null;
  }

  Future<void> updateParticipant(Participant participant) async {
    final db = await instance.database;
    await db.insert(
      'event_participants',
      participant.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Participant>> searchParticipants(String query) async {
    final db = await instance.database;
    final maps = await db.query(
      'event_participants',
      where: 'name LIKE ? OR email LIKE ? OR participant_id LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      limit: 20,
    );
    return maps.map((map) => Participant.fromJson(map)).toList();
  }

  // --- Meal Redemptions ---
  Future<void> clearMealRedemptions() async {
    final db = await instance.database;
    await db.delete('meal_redemptions');
  }

  Future<List<Map<String, dynamic>>> getAllMealRedemptions() async {
    final db = await instance.database;
    return await db.query('meal_redemptions');
  }

  Future<void> replaceMealRedemptions(List<Map<String, dynamic>> redemptions) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('meal_redemptions');
      final batch = txn.batch();
      for (var r in redemptions) {
        batch.insert(
          'meal_redemptions',
          {
            'id': r['id']?.toString() ?? '',
            'participant_id': r['participant_id']?.toString() ?? '',
            'meal_session': r['meal_session']?.toString() ?? '',
            'scanned_at': r['scanned_at']?.toString() ?? '',
            'scanned_by': r['scanned_by']?.toString() ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertMealRedemptions(List<Map<String, dynamic>> redemptions) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var r in redemptions) {
      batch.insert(
        'meal_redemptions',
        {
          'id': r['id']?.toString() ?? '',
          'participant_id': r['participant_id']?.toString() ?? '',
          'meal_session': r['meal_session']?.toString() ?? '',
          'scanned_at': r['scanned_at']?.toString() ?? '',
          'scanned_by': r['scanned_by']?.toString() ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<bool> hasRedeemedMeal(String participantId, String sessionName) async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM meal_redemptions WHERE participant_id = ? AND meal_session = ?',
      [participantId, sessionName],
    ));
    return (count ?? 0) > 0;
  }

  Future<void> addMealRedemption(
    String id,
    String participantId,
    String sessionName,
    String scannedBy, {
    String? scannedAt,
  }) async {
    final db = await instance.database;
    await db.insert(
      'meal_redemptions',
      {
        'id': id,
        'participant_id': participantId,
        'meal_session': sessionName,
        'scanned_at': scannedAt ?? DateTime.now().toUtc().toIso8601String(),
        'scanned_by': scannedBy,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Stats ---
  Future<int> getTotalParticipants() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM event_participants'),
        ) ??
        0;
  }

  Future<int> getCheckedInCount() async {
    final db = await instance.database;
    // An attendee is checked in when is_registered = 1, scanned_at is not null, or registered_at is not null
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM event_participants WHERE is_registered = 1 OR scanned_at IS NOT NULL OR registered_at IS NOT NULL',
          ),
        ) ??
        0;
  }

  Future<int> getMealsServedCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM meal_redemptions'),
        ) ??
        0;
  }

  Future<List<Map<String, dynamic>>> getMealSessionBreakdown() async {
    final db = await instance.database;
    final results = await db.rawQuery('''
      SELECT meal_session, COUNT(*) as count 
      FROM meal_redemptions 
      GROUP BY meal_session
    ''');
    return results;
  }

  Future<List<Participant>> getAllParticipants() async {
    final db = await instance.database;
    final maps = await db.query('event_participants');
    return maps.map((map) => Participant.fromJson(map)).toList();
  }

  Future<List<String>> getParticipantRedemptions(String participantId) async {
    final db = await instance.database;
    final results = await db.query(
      'meal_redemptions',
      columns: ['meal_session'],
      where: 'participant_id = ?',
      whereArgs: [participantId],
    );
    return results.map((row) => row['meal_session'] as String).toList();
  }

  // --- Sync Queue ---
  Future<void> addToQueue(String action, Map<String, dynamic> payload) async {
    final db = await instance.database;
    await db.insert('sync_queue', {
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
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
