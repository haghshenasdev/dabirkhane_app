import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  static Future<String> _dbPath() async {
    Directory dir;

    if (Platform.isAndroid) {
      dir = (await getExternalStorageDirectory())!;
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    return join(dir.path, 'dabirkhane.sqlite');
  }

  static Future<Database> initDb() async {
    String path = await _dbPath();

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE daftare_andicator (
          Shomare_Radif INTEGER PRIMARY KEY AUTOINCREMENT,
          goshashte TEXT,
          date TEXT,
          saheb_name TEXT,
          guy TEXT,
          from_pywa TEXT,
          sh_name_reside TEXT,
          t_name_reside TEXT,
          onvan TEXT,
          comment TEXT,
          shomare_badi TEXT,
          wordmost2 TEXT,
          t_name_ersali TEXT,
          adres_name TEXT
        )
        ''');
      },
    );
  }

  // CRUD
  static Future<int> insert(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('daftare_andicator', data);
  }

  static Future<int> update(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('daftare_andicator', data,
        where: 'Shomare_Radif = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await database;
    return db.query('daftare_andicator', orderBy: 'Shomare_Radif DESC');
  }

  static Future<void> closeDb() async {
  if (_db != null) {
    await _db!.close();
    _db = null;
  }
}

}
