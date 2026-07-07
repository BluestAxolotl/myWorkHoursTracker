import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Manages the SQLCipher database encryption key using secure storage.
/// 
/// On first app launch, generates a unique 32-byte key, stores it securely,
/// and rekeyed any legacy database that was encrypted with the old static password.
class DatabaseKeyManager {
  DatabaseKeyManager._();

  static const String _secureStorageKey = 'database_encryption_key_v2';
  static const String _legacySharedPrefKey = 'database_encryption_key_v1';
  static const String _legacyDbPassword = 'myWorkHoursTracker_local_key_v1';
  static const String _migrationFlagKey = 'database_key_migrated_to_secure_storage';
  static const int _databaseVersion = 4;

  static final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Resolves the database encryption key for the given database path.
  /// 
  /// - If a secure key exists, returns it.
  /// - If a legacy key exists in SharedPreferences, migrates it to secure storage.
  /// - If an existing legacy database exists, generates a new key, rekeyed the database, and stores the new key securely.
  /// - Otherwise, generates a new key and stores it securely.
  static Future<String> getDatabasePassword(String dbPath) async {
    // Check if key already exists in secure storage
    final String? secureKey = await _secureStorage.read(
      key: _secureStorageKey,
    );
    if (secureKey != null) {
      return secureKey;
    }

    // Check if there's a legacy key in SharedPreferences that needs migration
    final String? migratedKey = await _migrateFromSharedPreferences();
    if (migratedKey != null) {
      return migratedKey;
    }

    final bool dbExists = await databaseExists(dbPath);
    if (dbExists) {
      return _legacyDbPassword;
    }

    // Fresh install: generate and store a new key.
    final String newKey = _generateKey();
    await _secureStorage.write(
      key: _secureStorageKey,
      value: newKey,
    );
    return newKey;
  }

  /// Clears any persisted encryption-key state so a fresh database can be created.
  static Future<void> clearStoredDatabasePassword() async {
    await _secureStorage.delete(key: _secureStorageKey);

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacySharedPrefKey);
      await prefs.remove(_migrationFlagKey);
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  /// Rekeys an existing database in place, trying legacy-encrypted first and
  /// then falling back to a plaintext database.
  static Future<Database?> repairExistingDatabase(String dbPath) async {
    try {
      return await _rekeyOpenedDatabase(
        dbPath,
        password: _legacyDbPassword,
      );
    } on DatabaseException {
      try {
        return await _rekeyOpenedDatabase(dbPath);
      } on DatabaseException {
        return null;
      }
    }
  }

  /// Migrates the encryption key from SharedPreferences to secure storage.
  /// Returns the migrated key, or null if no legacy key exists.
  static Future<String?> _migrateFromSharedPreferences() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // Check if migration has already been done
      final bool alreadyMigrated = prefs.getBool(_migrationFlagKey) ?? false;
      if (alreadyMigrated) {
        return null;
      }

      // Look for the legacy key
      final String? legacyKey = prefs.getString(_legacySharedPrefKey);
      if (legacyKey == null) {
        return null;
      }

      // Migrate to secure storage and mark migration complete
      await _secureStorage.write(
        key: _secureStorageKey,
        value: legacyKey,
      );
      await prefs.setBool(_migrationFlagKey, true);

      return legacyKey;
    } catch (_) {
      // If migration fails, return null and fall through to other paths
      return null;
    }
  }

  /// Opens an existing database and rekeys it with a freshly generated key.
  static Future<Database> _rekeyOpenedDatabase(
    String dbPath, {
    String? password,
  }) async {
    final Database legacyDb = await openDatabase(
      dbPath,
      password: password,
      version: _databaseVersion,
      onOpen: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );

    final String newKey = _generateKey();

    // Rekey the database to the new key.
    await legacyDb.execute(
      "PRAGMA rekey = '${_escapeSqlCipherPassword(newKey)}';",
    );

    // Store the new key securely.
    await _secureStorage.write(
      key: _secureStorageKey,
      value: newKey,
    );

    return legacyDb;
  }

  /// Generates a cryptographically secure 32-byte database key.
  static String _generateKey() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(
      32,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes);
  }

  /// Escapes single quotes in a SQLCipher password for use in PRAGMA statements.
  static String _escapeSqlCipherPassword(String password) {
    return password.replaceAll("'", "''");
  }
}
