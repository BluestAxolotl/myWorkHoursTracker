import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'job_profile.dart';

class JobProfileDatabase {
  JobProfileDatabase._();

  static final JobProfileDatabase instance = JobProfileDatabase._();

  static const String _databaseName = 'work_hours_tracker.db';
  static const String _jobProfilesTable = 'job_profiles';
  static const String _workSessionsTable = 'work_sessions';
  static const String _dbPassword = 'myWorkHoursTracker_local_key_v1';
  static const int _databaseVersion = 2;

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
        breaks_paid INTEGER NOT NULL,
        unpaid_break_count INTEGER,
        lunch_paid INTEGER NOT NULL,
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
        start_time TEXT,
        end_time TEXT,
        break_minutes INTEGER,
        notes TEXT,
        FOREIGN KEY(job_profile_id) REFERENCES $_jobProfilesTable(id) ON DELETE CASCADE
      )
    ''');
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
}
