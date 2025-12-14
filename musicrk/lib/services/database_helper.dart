import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('musicrk.db');
    return _database!;
  }

  // Stream to notify about album changes
  final _albumsStreamController = StreamController<void>.broadcast();
  Stream<void> get albumsStream => _albumsStreamController.stream;

  // Stream to notify about notification changes
  final _notificationsStreamController = StreamController<void>.broadcast();
  Stream<void> get notificationsStream => _notificationsStreamController.stream;

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT NOT NULL';
      const textNullable = 'TEXT';
      const intType = 'INTEGER NOT NULL';
      
      await db.execute('''
CREATE TABLE favorites (
  id $idType,
  song_id $intType,
  title $textType,
  artist $textNullable,
  album $textNullable,
  data $textType,
  duration $intType
)
''');
    }
    
    if (oldVersion < 3) {
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT NOT NULL';
      const textNullable = 'TEXT';
      const intType = 'INTEGER NOT NULL';
      
      // Playlists table
      await db.execute('''
CREATE TABLE playlists (
  id $idType,
  name $textType,
  description $textNullable,
  image_path $textNullable,
  created_at $textType
)
''');
      
      // Playlist songs table
      await db.execute('''
CREATE TABLE playlist_songs (
  id $idType,
  playlist_id $intType,
  song_id $intType,
  title $textType,
  artist $textNullable,
  album $textNullable,
  data $textType,
  duration $intType,
  position $intType,
  added_at $textType,
  FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE
)
''');
    }
    
    if (oldVersion < 4) {
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT NOT NULL';
      const intType = 'INTEGER NOT NULL';
      const boolType = 'INTEGER NOT NULL DEFAULT 0';
      
      // Notifications table
      await db.execute('''\
CREATE TABLE notifications (
  id $idType,
  tipo $textType,
  titulo $textType,
  descripcion $textType,
  cantidad $intType,
  fecha $textType,
  leida $boolType
)
''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';

    // Albums table
    // type: 'custom' or 'folder'
    await db.execute('''
CREATE TABLE albums (
  id $idType,
  name $textType,
  artist $textNullable,
  year $textNullable,
  genre $textNullable,
  description $textNullable,
  image_path $textNullable,
  type $textType, 
  folder_path $textNullable
)
''');

    // Songs in albums table (linking songs to albums)
    await db.execute('''
CREATE TABLE album_songs (
  id $idType,
  album_id $intType,
  song_path $textType,
  FOREIGN KEY (album_id) REFERENCES albums (id) ON DELETE CASCADE
)
''');

    // Favorites table
    await db.execute('''
CREATE TABLE favorites (
  id $idType,
  song_id $intType,
  title $textType,
  artist $textNullable,
  album $textNullable,
  data $textType,
  duration $intType
)
''');

    // Playlists table
    await db.execute('''
CREATE TABLE playlists (
  id $idType,
  name $textType,
  description $textNullable,
  image_path $textNullable,
  created_at $textType
)
''');

    // Playlist songs table
    await db.execute('''
CREATE TABLE playlist_songs (
  id $idType,
  playlist_id $intType,
  song_id $intType,
  title $textType,
  artist $textNullable,
  album $textNullable,
  data $textType,
  duration $intType,
  position $intType,
  added_at $textType,
  FOREIGN KEY (playlist_id) REFERENCES playlists (id) ON DELETE CASCADE
)
''');

    // Notifications table
    const boolType = 'INTEGER NOT NULL DEFAULT 0';
    await db.execute('''\
CREATE TABLE notifications (
  id $idType,
  tipo $textType,
  titulo $textType,
  descripcion $textType,
  cantidad $intType,
  fecha $textType,
  leida $boolType
)
''');
  }

  Future<int> createAlbum(Map<String, dynamic> album) async {
    final db = await database;
    final id = await db.insert('albums', album);
    _albumsStreamController.add(null);
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllAlbums() async {
    final db = await database;
    return await db.query('albums', orderBy: 'id DESC');
  }

  Future<int> deleteAlbum(int id) async {
    final db = await database;
    final count = await db.delete('albums', where: 'id = ?', whereArgs: [id]);
    _albumsStreamController.add(null);
    return count;
  }

  Future<int> updateAlbum(int id, Map<String, dynamic> album) async {
    final db = await database;
    final count = await db.update('albums', album, where: 'id = ?', whereArgs: [id]);
    _albumsStreamController.add(null);
    return count;
  }

  Future<void> addSongToAlbum(int albumId, String songPath) async {
    final db = await database;
    await db.insert('album_songs', {
      'album_id': albumId,
      'song_path': songPath,
    });
  }

  Future<List<String>> getAlbumSongs(int albumId) async {
    final db = await database;
    final result = await db.query(
      'album_songs',
      columns: ['song_path'],
      where: 'album_id = ?',
      whereArgs: [albumId],
    );
    return result.map((e) => e['song_path'] as String).toList();
  }

  Future<void> removeSongFromAlbum(int albumId, String songPath) async {
    final db = await database;
    await db.delete(
      'album_songs',
      where: 'album_id = ? AND song_path = ?',
      whereArgs: [albumId, songPath],
    );
  }

  Future<bool> isSongInAlbum(int albumId, String songPath) async {
    final db = await database;
    final result = await db.query(
      'album_songs',
      where: 'album_id = ? AND song_path = ?',
      whereArgs: [albumId, songPath],
    );
    return result.isNotEmpty;
  }

  Future<void> addFavorite(Map<String, dynamic> song) async {
    final db = await database;
    await db.insert('favorites', song, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavorite(int songId) async {
    final db = await database;
    await db.delete('favorites', where: 'song_id = ?', whereArgs: [songId]);
  }

  Future<bool> isFavorite(int songId) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;
    return await db.query('favorites', orderBy: 'id DESC');
  }

  // ========== PLAYLIST METHODS ==========
  
  /// Create a new playlist
  Future<int> createPlaylist(Map<String, dynamic> playlist) async {
    final db = await database;
    playlist['created_at'] = DateTime.now().toIso8601String();
    return await db.insert('playlists', playlist);
  }

  /// Get all playlists
  Future<List<Map<String, dynamic>>> getAllPlaylists() async {
    final db = await database;
    return await db.query('playlists', orderBy: 'created_at DESC');
  }

  /// Get playlist by ID
  Future<Map<String, dynamic>?> getPlaylist(int id) async {
    final db = await database;
    final result = await db.query('playlists', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  /// Update playlist
  Future<int> updatePlaylist(int id, Map<String, dynamic> playlist) async {
    final db = await database;
    return await db.update('playlists', playlist, where: 'id = ?', whereArgs: [id]);
  }

  /// Delete playlist
  Future<int> deletePlaylist(int id) async {
    final db = await database;
    return await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  /// Duplicate playlist
  Future<int> duplicatePlaylist(int id) async {
    final db = await database;
    final playlist = await getPlaylist(id);
    if (playlist == null) return -1;
    
    // Create new playlist
    final newPlaylist = Map<String, dynamic>.from(playlist);
    newPlaylist.remove('id');
    newPlaylist['name'] = '${playlist['name']} (Copia)';
    newPlaylist['created_at'] = DateTime.now().toIso8601String();
    final newId = await db.insert('playlists', newPlaylist);
    
    // Copy songs using batch
    final songs = await getPlaylistSongs(id);
    final batch = db.batch();
    
    for (var song in songs) {
      final newSong = Map<String, dynamic>.from(song);
      newSong.remove('id');
      newSong['playlist_id'] = newId;
      newSong['added_at'] = DateTime.now().toIso8601String();
      batch.insert('playlist_songs', newSong);
    }
    
    await batch.commit(noResult: true);
    return newId;
  }

  /// Add song to playlist
  Future<void> addSongToPlaylist(int playlistId, Map<String, dynamic> song) async {
    final db = await database;
    final songs = await getPlaylistSongs(playlistId);
    song['playlist_id'] = playlistId;
    song['position'] = songs.length;
    song['added_at'] = DateTime.now().toIso8601String();
    await db.insert('playlist_songs', song);
  }

  /// Remove song from playlist
  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final db = await database;
    await db.delete(
      'playlist_songs',
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );
    
    // Reorder positions using batch
    final songs = await getPlaylistSongs(playlistId);
    final batch = db.batch();
    
    for (int i = 0; i < songs.length; i++) {
      batch.update(
        'playlist_songs',
        {'position': i},
        where: 'id = ?',
        whereArgs: [songs[i]['id']],
      );
    }
    
    await batch.commit(noResult: true);
  }

  /// Get all songs in a playlist
  Future<List<Map<String, dynamic>>> getPlaylistSongs(int playlistId) async {
    final db = await database;
    return await db.query(
      'playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );
  }

  /// Update song positions (for reordering)
  Future<void> updateSongPositions(int playlistId, List<Map<String, dynamic>> songs) async {
    final db = await database;
    final batch = db.batch();
    
    for (int i = 0; i < songs.length; i++) {
      batch.update(
        'playlist_songs',
        {'position': i},
        where: 'id = ?',
        whereArgs: [songs[i]['id']],
      );
    }
    
    await batch.commit(noResult: true);
  }

  /// Shuffle playlist songs
  Future<void> shufflePlaylist(int playlistId) async {
    final songs = await getPlaylistSongs(playlistId);
    songs.shuffle();
    await updateSongPositions(playlistId, songs);
  }

  // ========== NOTIFICATION METHODS ==========
  
  /// Add a new notification
  Future<int> addNotification(Map<String, dynamic> notification) async {
    final db = await database;
    notification['fecha'] = DateTime.now().toIso8601String();
    notification['leida'] = 0; // false
    final id = await db.insert('notifications', notification);
    _notificationsStreamController.add(null);
    return id;
  }

  /// Get all notifications ordered by date (newest first)
  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    final db = await database;
    return await db.query('notifications', orderBy: 'fecha DESC');
  }

  /// Get count of unread notifications
  Future<int> getUnreadNotificationsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE leida = 0'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(int id) async {
    final db = await database;
    await db.update(
      'notifications',
      {'leida': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notificationsStreamController.add(null);
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    final db = await database;
    await db.update('notifications', {'leida': 1});
    _notificationsStreamController.add(null);
  }

  /// Delete notification
  Future<void> deleteNotification(int id) async {
    final db = await database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
    _notificationsStreamController.add(null);
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
