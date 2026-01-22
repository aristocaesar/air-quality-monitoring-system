import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('user_data.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
    CREATE TABLE air_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pm1 REAL,
      pm25 REAL,
      pm10 REAL,
      mq135 INTEGER,
      temp REAL,
      humi REAL,
      status TEXT,
      created_at TEXT
    )
  ''');

    await db.insert('users', {'userId': '21012026', 'password': 'Monitor123'});
  }

  Future<bool> checkLogin(String userId, String password) async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'userId = ? AND password = ?',
      whereArgs: [userId, password],
    );

    return result.isNotEmpty;
  }

  Future<void> insertHistory(Map<String, dynamic> data) async {
    final db = await instance.database;
    await db.insert('air_history', data);
  }

  Future<List<Map<String, dynamic>>> getHistoryByDate(String date) async {
    final db = await instance.database;
    return await db.query(
      'air_history',
      where: 'created_at LIKE ?',
      whereArgs: ['$date%'],
      orderBy: 'created_at DESC',
    );
  }
}
