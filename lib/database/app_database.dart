import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class HistoryEntity {
  final int? id;
  final String barcode;
  final String productName;
  final String price;
  final int timestamp;

  HistoryEntity({
    this.id,
    required this.barcode,
    required this.productName,
    required this.price,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'productName': productName,
      'price': price,
      'timestamp': timestamp,
    };
  }

  factory HistoryEntity.fromMap(Map<String, dynamic> map) {
    return HistoryEntity(
      id: map['id'] as int?,
      barcode: map['barcode'] as String,
      productName: map['productName'] as String,
      price: map['price'] as String,
      timestamp: map['timestamp'] as int,
    );
  }
}

class FavoriteEntity {
  final String ean;
  final String productName;
  final String price;
  final String? imageUrl;
  final int timestamp;

  FavoriteEntity({
    required this.ean,
    required this.productName,
    required this.price,
    this.imageUrl,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'ean': ean,
      'productName': productName,
      'price': price,
      'imageUrl': imageUrl,
      'timestamp': timestamp,
    };
  }

  factory FavoriteEntity.fromMap(Map<String, dynamic> map) {
    return FavoriteEntity(
      ean: map['ean'] as String,
      productName: map['productName'] as String,
      price: map['price'] as String,
      imageUrl: map['imageUrl'] as String?,
      timestamp: map['timestamp'] as int,
    );
  }
}

class AppDatabase {
  static const String _dbName = 'history_database';
  static const int _dbVersion = 2;

  static Database? _instance;

  static Future<Database> get database async {
    _instance ??= await _init();
    return _instance!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode TEXT,
            productName TEXT,
            price TEXT,
            timestamp INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE favorites (
            ean TEXT PRIMARY KEY,
            productName TEXT,
            price TEXT,
            imageUrl TEXT,
            timestamp INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // fallbackToDestructiveMigration equivalent
        await db.execute('DROP TABLE IF EXISTS history');
        await db.execute('DROP TABLE IF EXISTS favorites');
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode TEXT,
            productName TEXT,
            price TEXT,
            timestamp INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE favorites (
            ean TEXT PRIMARY KEY,
            productName TEXT,
            price TEXT,
            imageUrl TEXT,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  // ---- History ----
  static Future<List<HistoryEntity>> getHistory() async {
    final db = await database;
    final rows = await db.query(
      'history',
      orderBy: 'timestamp DESC',
      limit: 20,
    );
    return rows.map(HistoryEntity.fromMap).toList();
  }

  static Future<void> insertHistory(HistoryEntity item) async {
    final db = await database;
    await db.insert('history', item.toMap());
  }

  static Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
  }

  // ---- Favorites ----
  static Future<List<FavoriteEntity>> getFavorites() async {
    final db = await database;
    final rows = await db.query('favorites', orderBy: 'timestamp DESC');
    return rows.map(FavoriteEntity.fromMap).toList();
  }

  static Future<void> insertFavorite(FavoriteEntity item) async {
    final db = await database;
    await db.insert(
      'favorites',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteFavorite(String ean) async {
    final db = await database;
    await db.delete('favorites', where: 'ean = ?', whereArgs: [ean]);
  }

  static Future<int> isFavorite(String ean) async {
    final db = await database;
    final res = await db.query(
      'favorites',
      where: 'ean = ?',
      whereArgs: [ean],
    );
    return res.length;
  }
}
