import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'job_profile.dart';
import 'work_session.dart';

class JobProfileDatabase {
  JobProfileDatabase._();

  static final JobProfileDatabase instance = JobProfileDatabase._();

  static const String _databaseName = 'work_hours_tracker.db';
  static const String _jobProfilesTable = 'job_profiles';
  static const String _workSessionsTable = 'work_sessions';
  static const String _tempWorkSessionsTable = 'temp_work_sessions';
  static const String _dbPassword = 'myWorkHoursTracker_local_key_v1';
  static const int _databaseVersion = 3;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final String dbDirectory = await getDatabasesPath();
    final String path = p.join(dbDirectory, _databaseName);
    _database = await openDatabase(
      path,
      password: _dbPassword,
      version: _databaseVersion,
      onCreate: (Database db, int version) async {
        await _createSchema(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        await _upgradeSchema(db, oldVersion, newVersion);
      },
      onOpen: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $_jobProfilesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pay_rate TEXT NOT NULL,
        pay_period TEXT NOT NULL,
        pay_day_of_week TEXT,
        pay_day_of_month INTEGER,
        overtime_paid INTEGER NOT NULL,
        overtime_mode TEXT,
        overtime_threshold_hours INTEGER,
        overtime_multiplier TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE $_workSessionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_profile_id INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        clock_in_time TEXT,
        clock_out_time TEXT,
        break_count INTEGER NOT NULL DEFAULT 0,
        break1_start_time TEXT,
        break1_end_time TEXT,
        break2_start_time TEXT,
        break2_end_time TEXT,
        break3_start_time TEXT,
        break3_end_time TEXT,
        break4_start_time TEXT,
        break4_end_time TEXT,
        break5_start_time TEXT,
        break5_end_time TEXT,
        has_lunch INTEGER NOT NULL DEFAULT 0,
        lunch_start_time TEXT,
        lunch_end_time TEXT,
        note TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(job_profile_id) REFERENCES $_jobProfilesTable(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tempWorkSessionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_profile_id INTEGER NOT NULL UNIQUE,
        session_date TEXT NOT NULL,
        clock_in_time TEXT,
        clock_out_time TEXT,
        break_count INTEGER NOT NULL DEFAULT 0,
        break1_start_time TEXT,
        break1_end_time TEXT,
        break2_start_time TEXT,
        break2_end_time TEXT,
        break3_start_time TEXT,
        break3_end_time TEXT,
        break4_start_time TEXT,
        break4_end_time TEXT,
        break5_start_time TEXT,
        break5_end_time TEXT,
        has_lunch INTEGER NOT NULL DEFAULT 0,
        lunch_start_time TEXT,
        lunch_end_time TEXT,
        note TEXT,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(job_profile_id) REFERENCES $_jobProfilesTable(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS $_tempWorkSessionsTable');
      await db.execute('DROP TABLE IF EXISTS $_workSessionsTable');

      await db.execute('''
        CREATE TABLE $_workSessionsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          job_profile_id INTEGER NOT NULL,
          session_date TEXT NOT NULL,
          clock_in_time TEXT,
          clock_out_time TEXT,
          break_count INTEGER NOT NULL DEFAULT 0,
          break1_start_time TEXT,
          break1_end_time TEXT,
          break2_start_time TEXT,
          break2_end_time TEXT,
          break3_start_time TEXT,
          break3_end_time TEXT,
          break4_start_time TEXT,
          break4_end_time TEXT,
          break5_start_time TEXT,
          break5_end_time TEXT,
          has_lunch INTEGER NOT NULL DEFAULT 0,
          lunch_start_time TEXT,
          lunch_end_time TEXT,
          note TEXT,
          created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(job_profile_id) REFERENCES $_jobProfilesTable(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE $_tempWorkSessionsTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          job_profile_id INTEGER NOT NULL UNIQUE,
          session_date TEXT NOT NULL,
          clock_in_time TEXT,
          clock_out_time TEXT,
          break_count INTEGER NOT NULL DEFAULT 0,
          break1_start_time TEXT,
          break1_end_time TEXT,
          break2_start_time TEXT,
          break2_end_time TEXT,
          break3_start_time TEXT,
          break3_end_time TEXT,
          break4_start_time TEXT,
          break4_end_time TEXT,
          break5_start_time TEXT,
          break5_end_time TEXT,
          has_lunch INTEGER NOT NULL DEFAULT 0,
          lunch_start_time TEXT,
          lunch_end_time TEXT,
          note TEXT,
          updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(job_profile_id) REFERENCES $_jobProfilesTable(id) ON DELETE CASCADE
        )
      ''');
    }

    if (newVersion > _databaseVersion) {
      return;
    }
  }

  Future<List<JobProfile>> getAllJobProfiles() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _jobProfilesTable,
      orderBy: 'id ASC',
    );
    return rows.map(JobProfile.fromMap).toList();
  }

  Future<int> createJobProfile(JobProfile profile) async {
    final Database db = await database;
    return db.insert(_jobProfilesTable, profile.toMap());
  }

  Future<int> deleteJobProfile(int id) async {
    final Database db = await database;
    return db.transaction<int>((Transaction txn) async {
      await txn.delete(
        _tempWorkSessionsTable,
        where: 'job_profile_id = ?',
        whereArgs: <Object>[id],
      );
      await txn.delete(
        _workSessionsTable,
        where: 'job_profile_id = ?',
        whereArgs: <Object>[id],
      );
      return txn.delete(
        _jobProfilesTable,
        where: 'id = ?',
        whereArgs: <Object>[id],
      );
    });
  }

  Future<bool> hasOpenWorkSessionDraft(int jobProfileId) async {
    final Database db = await database;
    final int? count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $_tempWorkSessionsTable WHERE job_profile_id = ?',
        <Object>[jobProfileId],
      ),
    );
    return (count ?? 0) > 0;
  }

  Future<WorkSession?> getOpenWorkSessionDraft(int jobProfileId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _tempWorkSessionsTable,
      where: 'job_profile_id = ?',
      whereArgs: <Object>[jobProfileId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WorkSession.fromMap(rows.first);
  }

  Future<WorkSession?> getMostRecentFinalizedWorkSession(int jobProfileId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _workSessionsTable,
      where: 'job_profile_id = ?',
      whereArgs: <Object>[jobProfileId],
      orderBy: 'session_date DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WorkSession.fromMap(rows.first);
  }

  Future<List<WorkSession>> getFinalizedWorkSessionsForProfile(int jobProfileId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      _workSessionsTable,
      where: 'job_profile_id = ?',
      whereArgs: <Object>[jobProfileId],
      orderBy: 'session_date DESC, id DESC',
    );
    return rows.map(WorkSession.fromMap).toList();
  }

  Future<void> saveOpenWorkSessionDraft(WorkSession session) async {
    final Database db = await database;
    final Map<String, Object?> values = session.toMap()
      ..remove('id')
      ..['updated_at'] = DateTime.now().toIso8601String();

    await db.insert(
      _tempWorkSessionsTable,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteOpenWorkSessionDraft(int jobProfileId) async {
    final Database db = await database;
    await db.delete(
      _tempWorkSessionsTable,
      where: 'job_profile_id = ?',
      whereArgs: <Object>[jobProfileId],
    );
  }

  Future<void> insertFinalizedWorkSession(WorkSession session) async {
    final Database db = await database;
    final Map<String, Object?> values = session.toMap()..remove('id');
    await db.insert(_workSessionsTable, values);
  }
}
