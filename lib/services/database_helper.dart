import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('hla_music.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE songs ADD COLUMN externalArtPath TEXT');
      await db.execute('ALTER TABLE songs ADD COLUMN albumName TEXT');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs (
        id INTEGER PRIMARY KEY,
        plainLyrics TEXT,
        syncedLyrics TEXT,
        playCount INTEGER DEFAULT 0,
        lastPlayed TEXT,
        externalArtPath TEXT,
        albumName TEXT
      )
    ''');
  }

  Future<void> updateAlbumArt(String albumName, String localPath) async {
    final db = await instance.database;
    await db.update(
      'songs',
      {'externalArtPath': localPath},
      where: 'albumName = ?',
      whereArgs: [albumName],
    );
  }

  Future<String?> getArtForAlbum(String albumName) async {
    final db = await instance.database;
    final maps = await db.query(
      'songs',
      columns: ['externalArtPath'],
      where: 'albumName = ? AND externalArtPath IS NOT NULL',
      whereArgs: [albumName],
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first['externalArtPath'] as String?;
    return null;
  }

  Future<void> syncSongMetadata(int id, String? albumName) async {
    final db = await instance.database;
    // Use INSERT OR IGNORE to create the row if it doesn't exist,
    // then UPDATE to ensure albumName is set.
    await db.insert('songs', {
      'id': id,
      'albumName': albumName,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.update(
      'songs',
      {'albumName': albumName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLyrics(int id, String? plain, String? synced) async {
    final db = await instance.database;
    await db.update(
      'songs',
      {'plainLyrics': plain, 'syncedLyrics': synced},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getSongData(int id) async {
    final db = await instance.database;
    final maps = await db.query('songs', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> incrementPlayCount(int id) async {
    final db = await instance.database;
    final data = await getSongData(id);
    int currentCount = data != null ? (data['playCount'] as int) : 0;

    await db.update(
      'songs',
      {
        'playCount': currentCount + 1,
        'lastPlayed': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getTopPlayedSongs(int limit) async {
    final db = await instance.database;
    return await db.query('songs', orderBy: 'playCount DESC', limit: limit);
  }
}
