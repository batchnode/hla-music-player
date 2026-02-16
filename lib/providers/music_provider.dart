import 'package:flutter/material.dart';
import 'dart:math';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_player_handler.dart';
import '../models/song.dart';
import '../data/mock_songs.dart';
import '../services/database_helper.dart';
import 'settings_provider.dart';

enum RepeatMode { off, one, all, smart }

class MusicProvider with ChangeNotifier {
  late final AudioHandler _audioHandler;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final DatabaseHelper _db = DatabaseHelper.instance;
  SettingsProvider? _settingsProvider;

  List<Song> _allSongs = mockSongs;
  List<Song> _queue = mockSongs;
  List<Song> _originalQueue = mockSongs;
  int _currentIndex = -1;
  bool _isMiniPlayerVisible = false;
  bool _isFullPlayerExpanded = false;
  bool _hasPermission = false;
  String _currentCollection = "Library";

  bool _isShuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.all;

  // Sync State
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = "";
  List<String> _syncLogs = [];

  // Lyrics State
  String? _currentLyrics;
  String? _currentSyncedLyrics;
  bool _isLoadingLyrics = false;

  // Smart Repeat State
  int _smartRepeatCount = 0;
  static const int _maxSmartRepeats = 3;

  // Position Timer
  Timer? _positionUpdateTimer;

  // Sleep Timer
  Timer? _sleepTimer;
  int _sleepTimerSecondsRemaining = 0;

  // Navigation Triggers
  final StreamController<int> _navController =
      StreamController<int>.broadcast();
  Stream<int> get navStream => _navController.stream;

  final StreamController<int> _jumpController =
      StreamController<int>.broadcast();
  Stream<int> get jumpStream => _jumpController.stream;

  void goToEqualizer() => _navController.add(0);
  void goToLibrary() => _navController.add(1);
  void goToCollections() => _navController.add(2);
  void goToProfile() => _navController.add(3);

  void jumpToPage(int index) => _jumpController.add(index);

  static const List<String> tier2Sequence = ['Artists', 'Albums', 'Genres'];
  static const List<String> tier3Sequence = [
    'Most Played',
    'Favourites',
    'NoLabel',
    'Recent'
  ];

  // Dynamic Categories
  Map<String, List<Song>> _artists = {};
  Map<String, List<Song>> _genres = {};
  Map<String, List<Song>> _albums = {};
  final List<Song> _favourites = [];
  List<Song> _recents = [];
  List<Song> _noLabel = [];
  List<Map<String, int>> _libraryLayoutConfigs = [];
  List<Map<String, int>> _playlistsLayoutConfigs = [];
  List<Map<String, int>> _artistsLayoutConfigs = [];
  List<Map<String, int>> _albumsLayoutConfigs = [];
  List<Map<String, int>> _genresLayoutConfigs = [];
  final Map<String, List<Map<String, int>>> _cachedBentoLayouts = {};

  List<Map<String, int>> getBentoLayoutFor(String key, int itemCount, {int tier = 2}) {
    final cacheKey = '${key}_tier$tier';
    if (_cachedBentoLayouts.containsKey(cacheKey) &&
        _cachedBentoLayouts[cacheKey]!.length == itemCount) {
      return _cachedBentoLayouts[cacheKey]!;
    }
    
    List<Map<String, int>> layout;
    if (tier == 2) {
      layout = _generateTier2BentoLayout(itemCount, key.hashCode);
    } else {
      layout = _generateStableBentoLayout(itemCount, key.hashCode);
    }
    
    _cachedBentoLayouts[cacheKey] = layout;
    return layout;
  }

  List<Map<String, int>> _generateStableBentoLayout(int itemCount, int seed) {
    final random = Random(seed);
    const int columnCount = 4;
    List<Map<String, int>> configs = [];
    List<List<bool>> grid = [];
    bool isOccupied(int x, int y) => y < grid.length && grid[y][x];

    for (int i = 0; i < itemCount; i++) {
      int tx = 0, ty = 0;
      bool found = false;
      int y = 0;
      while (!found) {
        if (y >= grid.length) {
          grid.add(List.filled(columnCount, false));
        }
        for (int x = 0; x < columnCount; x++) {
          if (!grid[y][x]) {
            tx = x;
            ty = y;
            found = true;
            break;
          }
        }
        if (!found) {
          y++;
        }
      }
      double r = random.nextDouble();
      int maxWidth = columnCount - tx;
      int w = 1;
      int h = 1;
      if (r < 0.15 && maxWidth >= 4) {
        w = 4;
      } else if (r < 0.35 && maxWidth >= 3) {
        w = 3;
      } else if (r < 0.65 && maxWidth >= 2) {
        w = 2;
      } else {
        w = 1;
      }
      h = random.nextInt(3) + 1;
      int actualW = 1;
      for (int cw = 1; cw <= maxWidth; cw++) {
        if (isOccupied(tx + cw - 1, ty)) {
          break;
        }
        actualW = cw;
        if (actualW >= w) {
          break;
        }
      }
      w = actualW;
      int actualH = 1;
      for (int ch = 1; ch <= 3; ch++) {
        bool blocked = false;
        for (int cw = 0; cw < w; cw++) {
          if (isOccupied(tx + cw, ty + ch - 1)) {
            blocked = true;
            break;
          }
        }
        if (blocked) {
          break;
        }
        actualH = ch;
        if (actualH >= h) {
          break;
        }
      }
      h = actualH;
      configs.add({'cross': w, 'main': h});
      while (grid.length < ty + h) {
        grid.add(List.filled(columnCount, false));
      }
      for (int r = ty; r < ty + h; r++) {
        for (int c = tx; c < tx + w; c++) {
          grid[r][c] = true;
        }
      }
    }
    return configs;
  }

    List<Map<String, int>> _generateTier2BentoLayout(int itemCount, int seed) {

      final random = Random(seed);

      const int columnCount = 4;

      List<Map<String, int>> configs =

          List.filled(itemCount, {'cross': 2, 'main': 2});

      List<List<bool>> grid = [];

  

      bool isOccupied(int x, int y) {

        if (y >= grid.length) {

          return false;

        }

        return grid[y][x];

      }

    for (int i = 0; i < itemCount; i++) {
      int tx = 0, ty = 0;
      bool found = false;
      int y = 0;
      while (!found) {
        if (y >= grid.length) grid.add(List.filled(columnCount, false));
        for (int x = 0; x < columnCount; x++) {
          if (!grid[y][x]) {
            tx = x;
            ty = y;
            found = true;
            break;
          }
        }
        if (!found) y++;
      }

      int maxWidth = columnCount - tx;
      int w = 2;
      int h = 2;
      
      double r = random.nextDouble();
      if (r < 0.1 && maxWidth >= 4) {
        w = 4; h = 4; // 4x4 Large
      } else if (r < 0.3 && maxWidth >= 2) {
        w = 2; h = 4; // 2x4 Vertical Large
      } else if (maxWidth >= 2) {
        w = 2; h = 2; // 2x2 Standard
      } else {
        // Force 2x2 by searching for next available spot that fits it, 
        // but for simplicity in this packing, we'll fallback to 1x1 if we MUST, 
        // though the goal is no gaps. 
        // Actually, since we only use widths 2 and 4, and columnCount is 4, 
        // a 2-width item will ALWAYS fit if an x=0 or x=2 spot is open.
        w = 2; h = 2; 
      }

            // Final collision check & adjustment
            for (int row = ty; row < ty + h; row++) {
              for (int col = tx; col < tx + w; col++) {
                if (isOccupied(col, row)) {
                  // Collision! Fallback to standard 2x2 if possible, or 1x1 if at edge
                  w = 2;
                  h = 2;
                  if (tx + w > columnCount) w = columnCount - tx;
                  break;
                }
              }
            }
      
            configs[i] = {'cross': w, 'main': h};      
      // Mark grid
      while (grid.length < ty + h) {
        grid.add(List.filled(columnCount, false));
      }
      for (int row = ty; row < ty + h; row++) {
        for (int col = tx; col < tx + w; col++) {
          grid[row][col] = true;
        }
      }
    }
    return configs;
  }

  // Getters
  List<Song> get songs => _allSongs;
  List<Song> get queue => _queue;
  int get currentIndex => _currentIndex;
  List<Map<String, int>> get libraryLayoutConfigs => _libraryLayoutConfigs;
  List<Map<String, int>> get playlistsLayoutConfigs => _playlistsLayoutConfigs;
  List<Map<String, int>> get artistsLayoutConfigs => _artistsLayoutConfigs;
  List<Map<String, int>> get albumsLayoutConfigs => _albumsLayoutConfigs;
  List<Map<String, int>> get genresLayoutConfigs => _genresLayoutConfigs;
  bool get isSyncing => _isSyncing;
  double get syncProgress => _syncProgress;
  String get syncStatus => _syncStatus;
  List<String> get syncLogs => _syncLogs;

  Song? get currentSong => _currentIndex != -1 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;
  bool get isPlaying => _audioHandler.playbackState.value.playing;
  Duration get currentPosition {
    return _audioHandler.playbackState.value.position;
  }

  Duration get currentDuration {
    return _audioHandler.mediaItem.value?.duration ?? Duration.zero;
  }

  bool get isMiniPlayerVisible => _isMiniPlayerVisible;
  bool get isFullPlayerExpanded => _isFullPlayerExpanded;
  bool get hasPermission => _hasPermission;
  String get currentCollection => _currentCollection;
  bool get isShuffleEnabled => _isShuffleEnabled;
  RepeatMode get repeatMode => _repeatMode;
  int get sleepTimerSecondsRemaining => _sleepTimerSecondsRemaining;
  String? get currentLyrics => _currentLyrics;
  String? get currentSyncedLyrics => _currentSyncedLyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;

  Map<String, List<Song>> get artistMap => _artists;
  Map<String, List<Song>> get genreMap => _genres;
  Map<String, List<Song>> get albumMap => _albums;
  List<Song> get favourites => _favourites;
  List<Song> get recents => _recents;
  List<Song> get noLabel => _noLabel;

  List<String> get artistKeys => _artists.keys.toList()..sort();
  List<String> get genreKeys => _genres.keys.toList()..sort();
  List<String> get albumKeys => _albums.keys.toList()..sort();

  MusicProvider(this._audioHandler) {
    _init();
  }

  void updateSettings(SettingsProvider settings) {
    _settingsProvider = settings;
    _applyAudioEngineSettings();
  }

  void _applyAudioEngineSettings() {
    if (_settingsProvider == null) return;

    final handler = _audioHandler as AudioPlayerHandler;
    handler.setEqualizerEnabled(_settingsProvider!.isEqEnabled);
    for (int i = 0; i < _settingsProvider!.eqBands.length; i++) {
      // Map 0.0-1.0 to gain (e.g. -15.0 to 15.0 dB)
      final gain = (_settingsProvider!.eqBands[i] - 0.5) * 30.0;
      handler.setEqualizerBand(i, gain);
    }

    // Functional demonstration: Audio Quality affects volume slightly
    double qualityVolume = 1.0;
    switch (_settingsProvider!.audioQuality) {
      case 'Low (96kbps)':
        qualityVolume = 0.7;
        break;
      case 'Normal (160kbps)':
        qualityVolume = 0.85;
        break;
      case 'High (320kbps)':
        qualityVolume = 1.0;
        break;
      case 'Extreme (Lossless)':
        qualityVolume = 1.0;
        break;
    }
    handler.setVolume(qualityVolume);
    handler.setStopOnDisconnect(_settingsProvider!.stopOnDisconnect);
  }

  void setFullPlayerExpanded(bool expanded) {
    if (expanded) {
      regenerateLibraryLayout();
    }
    _isFullPlayerExpanded = expanded;
    notifyListeners();
  }

  void _init() async {
    _audioHandler.playbackState.listen((playbackState) {
      if (playbackState.processingState == AudioProcessingState.completed) {
        _handleSongCompletion();
      }
      if (playbackState.playing) {
        _startPositionTimer();
      } else {
        _stopPositionTimer();
      }
      notifyListeners();
    });

    _audioHandler.mediaItem.listen((mediaItem) => notifyListeners());

    final handler = _audioHandler as AudioPlayerHandler;
    handler.skipToNextStream.listen((_) => playNext());
    handler.skipToPreviousStream.listen((_) => playPrevious());

    scheduleMicrotask(() {
      checkAndRequestPermissions();
    });
  }

  void _startPositionTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (isPlaying) {
        _checkCrossfade();
        notifyListeners();
      } else {
        _stopPositionTimer();
      }
    });
  }

  bool _isCrossfading = false;

  void _checkCrossfade() async {
    if (_settingsProvider == null || _isCrossfading) return;
    final crossfadeSecs = _settingsProvider!.crossfadeValue;
    if (crossfadeSecs <= 0) return;

    final pos = currentPosition;
    final dur = currentDuration;

    if (dur > Duration.zero &&
        pos >= dur - Duration(milliseconds: (crossfadeSecs * 1000).toInt())) {
      _isCrossfading = true;
      // Start crossfade: Fade out current, then play next
      final handler = _audioHandler as AudioPlayerHandler;

      // Simple fade out simulation
      for (int i = 10; i >= 0; i--) {
        await handler.setVolume(i / 10.0);
        await Future.delayed(
          Duration(milliseconds: (crossfadeSecs * 100).toInt()),
        );
      }

      playNext();
      await handler.setVolume(1.0);
      _isCrossfading = false;
    }
  }

  void _stopPositionTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  void _categorizeSongs() async {
    Map<String, List<Song>> tempArtists = {};
    Map<String, List<Song>> tempGenres = {};
    Map<String, List<Song>> tempAlbums = {};
    List<Song> tempNoLabel = [];

    for (var song in _allSongs) {
      bool isNoLabel = false;
      String artist = song.artist;
      if (artist.isEmpty || artist.toLowerCase().contains("unknown")) {
        isNoLabel = true;
      } else {
        String normalized = _normalize(artist);
        String? existingKey = tempArtists.keys.firstWhere(
          (k) => _normalize(k) == normalized,
          orElse: () => "",
        );
        if (existingKey.isEmpty) {
          tempArtists[artist] = [song];
        } else {
          tempArtists[existingKey]!.add(song);
        }
      }

      String album = song.album ?? "";
      if (album.isEmpty || album.toLowerCase().contains("unknown")) {
        isNoLabel = true;
      } else {
        tempAlbums.putIfAbsent(album, () => []).add(song);
      }

      String genre = song.genre ?? "";
      if (genre.isNotEmpty && !genre.toLowerCase().contains("unknown")) {
        tempGenres.putIfAbsent(genre, () => []).add(song);
      }

      if (isNoLabel) tempNoLabel.add(song);
    }

    _artists = tempArtists;
    _genres = tempGenres;
    _albums = tempAlbums;
    _noLabel = tempNoLabel;
    _generateLibraryLayout();
    _generatePlaylistsLayout();
    _generateAllCategoryLayouts();

    final topData = await _db.getTopPlayedSongs(20);
    _recents = [];
    for (var item in topData) {
      try {
        final song = _allSongs.firstWhere((s) => s.id == item['id']);
        _recents.add(song);
      } catch (_) {}
    }
    notifyListeners();
  }

  void _log(String message) {
    final timestamp = DateTime.now()
        .toString()
        .split('.')
        .first
        .split(' ')
        .last;
    _syncLogs.insert(0, "[$timestamp] $message");
    if (_syncLogs.length > 100) _syncLogs.removeLast();
    notifyListeners();
  }

  String _scrubMetadata(String input) {
    String cleaned = input.replaceAll(RegExp(r'^.*? - '), '');
    cleaned = cleaned.replaceAll(RegExp(r'\(\d{4}\)'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\(.*?\)'), '');
    return cleaned.trim();
  }

  double _calculateSimilarity(String s1, String s2) {
    s1 = s1.toLowerCase().trim();
    s2 = s2.toLowerCase().trim();
    if (s1 == s2) return 1.0;
    if (s1.contains(s2) || s2.contains(s1)) return 0.8;
    var w1 = s1.split(RegExp(r'\s+')).toSet();
    var w2 = s2.split(RegExp(r'\s+')).toSet();
    if (w1.isEmpty || w2.isEmpty) return 0.0;
    return w1.intersection(w2).length / max(w1.length, w2.length);
  }

  // --- MusicBrainz & Album Art Sync ---

  Future<void> syncMissingArtwork() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _syncProgress = 0.0;
    _syncStatus = "Scanning Library...";
    _syncLogs = [];
    _log("Starting Smart Sync Session...");
    notifyListeners();

    final Map<String, String> headers = {
      'User-Agent':
          'HLA-Music-Player/1.0.0 (hla.kali.music; contact@batchnode.com)',
      'Accept': 'application/json',
    };

    try {
      List<String> albumsToSync = [];
      Map<String, String> albumArtists = {};

      for (var albumName in _albums.keys) {
        final songsInAlbum = _albums[albumName]!;
        final artist = songsInAlbum[0].artist;
        if (artist.toLowerCase().contains("unknown") ||
            albumName.toLowerCase().contains("download")) {
          continue;
        }

        String? cachedPath = await _db.getArtForAlbum(albumName);
        if (cachedPath == null || !await File(cachedPath).exists()) {
          albumsToSync.add(albumName);
          albumArtists[albumName] = artist;
        }
      }

      _log(
        "Scan Complete: ${albumsToSync.length} qualified albums need covers.",
      );
      if (albumsToSync.isEmpty) {
        _syncStatus = "Nothing to sync!";
        _isSyncing = false;
        notifyListeners();
        return;
      }

      final docDir = await getApplicationDocumentsDirectory();
      final artDir = Directory('${docDir.path}/artwork');
      if (!await artDir.exists()) await artDir.create(recursive: true);

      int successCount = 0;

      for (int i = 0; i < albumsToSync.length; i++) {
        final rawAlbum = albumsToSync[i];
        final artist = albumArtists[rawAlbum]!;
        final album = _scrubMetadata(rawAlbum);

        _syncProgress = i / albumsToSync.length;
        _syncStatus = "Matching: $album";
        _log("--- Syncing: $album by $artist ---");
        notifyListeners();

        try {
          List<dynamic> releases = [];

          // A. Search MusicBrainz with Retries
          int mbAttempts = 0;
          while (mbAttempts < 3 && releases.isEmpty) {
            try {
              final mbUri = Uri.https('musicbrainz.org', '/ws/2/release', {
                'query': 'release:"$album" AND artist:"$artist"',
                'fmt': 'json',
                'limit': '10',
              });

              var response = await http
                  .get(mbUri, headers: headers)
                  .timeout(const Duration(seconds: 15));
              if (response.statusCode == 200) {
                releases = jsonDecode(response.body)['releases'] ?? [];
              } else {
                _log(
                  "MB Search attempt ${mbAttempts + 1} status: ${response.statusCode}",
                );
              }
            } catch (e) {
              _log("MB Search attempt ${mbAttempts + 1} error: $e");
            }
            mbAttempts++;
            if (releases.isEmpty && mbAttempts < 3) {
              await Future.delayed(const Duration(seconds: 1));
            }
          }

          if (releases.isNotEmpty) {
            releases.sort((a, b) {
              double simA =
                  _calculateSimilarity(album, a['title'] ?? "") +
                  _calculateSimilarity(
                    artist,
                    a['artist-credit']?[0]['name'] ?? "",
                  );
              double simB =
                  _calculateSimilarity(album, b['title'] ?? "") +
                  _calculateSimilarity(
                    artist,
                    b['artist-credit']?[0]['name'] ?? "",
                  );
              return simB.compareTo(simA);
            });

            _log(
              "Found ${releases.length} candidates. Best match: '${releases[0]['title']}'",
            );

            bool artFound = false;
            for (var release in releases.take(3)) {
              if (artFound) break;
              final mbid = release['id'];
              _log("Checking Archive for ID: $mbid");

              try {
                final caaResponse = await http
                    .get(
                      Uri.https('coverartarchive.org', '/release/$mbid'),
                      headers: headers,
                    )
                    .timeout(const Duration(seconds: 10));
                if (caaResponse.statusCode == 200) {
                  final images =
                      jsonDecode(caaResponse.body)['images'] as List?;
                  if (images != null && images.isNotEmpty) {
                    final imageUrl = images.firstWhere(
                      (img) => img['front'] == true,
                      orElse: () => images[0],
                    )['image'];
                    if (imageUrl != null) {
                      _log("URL Found! Starting download...");
                      int dlAttempts = 0;
                      while (dlAttempts < 3 && !artFound) {
                        try {
                          final imgRes = await http
                              .get(Uri.parse(imageUrl), headers: headers)
                              .timeout(const Duration(seconds: 20));
                          if (imgRes.statusCode == 200 &&
                              imgRes.bodyBytes.isNotEmpty) {
                            final fileName =
                                "${rawAlbum.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg";
                            final localFile = File('${artDir.path}/$fileName');
                            await localFile.writeAsBytes(imgRes.bodyBytes);
                            await _db.updateAlbumArt(rawAlbum, localFile.path);
                            _log("Success! Saved to local storage.");
                            artFound = true;
                            successCount++;
                          }
                        } catch (e) {
                          _log("Download Retry ${dlAttempts + 1} error: $e");
                        }
                        dlAttempts++;
                        if (!artFound && dlAttempts < 3) {
                          await Future.delayed(const Duration(seconds: 1));
                        }
                      }
                    }
                  }
                }
              } catch (e) {
                _log("Archive Check Error: $e");
              }
              if (!artFound) {
                await Future.delayed(const Duration(milliseconds: 200));
              }
            }
          }
        } catch (e) {
          _log("Metadata Logic Error: $e");
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      _syncStatus = "Sync Complete!";
      _log("SUMMARY: Successfully synced $successCount covers.");
    } catch (e) {
      _log("CRITICAL ERROR: $e");
    } finally {
      _isSyncing = false;
      _syncProgress = 1.0;
      notifyListeners();
      _categorizeSongs();
    }
  }

  // --- Grid Generation ---

  void _generatePlaylistsLayout() {
    _playlistsLayoutConfigs = [
      {'cross': 2, 'main': 2},
      {'cross': 2, 'main': 2},
      {'cross': 2, 'main': 2},
      {'cross': 4, 'main': 2},
      {'cross': 2, 'main': 2},
      {'cross': 2, 'main': 1},
      {'cross': 2, 'main': 1},
    ];
  }

  void _generateAllCategoryLayouts() {
    _artistsLayoutConfigs = _packTetrisGrid(_artists.length, 101);
    _albumsLayoutConfigs = _packTetrisGrid(_albums.length, 102);
    _genresLayoutConfigs = _packTetrisGrid(_genres.length, 103);
  }

  List<Map<String, int>> _packTetrisGrid(int itemCount, int seed) {
    final random = Random(seed);
    const int columnCount = 4;
    List<Map<String, int>> configs = [];
    List<List<bool>> grid = [];
    bool isOccupied(int x, int y) => y < grid.length && grid[y][x];

    for (int i = 0; i < itemCount; i++) {
      int tx = 0, ty = 0;
      bool found = false;
      int y = 0;
      while (!found) {
        if (y >= grid.length) grid.add(List.filled(columnCount, false));
        for (int x = 0; x < columnCount; x++) {
          if (!grid[y][x]) {
            tx = x;
            ty = y;
            found = true;
            break;
          }
        }
        if (!found) y++;
      }
      int maxWidth = columnCount - tx;
      int w = 2;
      int h = 2;
      double r = random.nextDouble();
      if (r < 0.2 && maxWidth >= 4) {
        w = 4;
        h = 4;
      } else if (r < 0.5 && maxWidth >= 4) {
        w = 4;
        h = 2;
      } else if (r < 0.7 && maxWidth >= 2) {
        w = 2;
        h = 4;
      } else if (maxWidth >= 2) {
        w = 2;
        h = 2;
      } else {
        w = 1;
        h = 1;
      }

      int aw = 1;
      for (int cw = 1; cw <= maxWidth; cw++) {
        if (isOccupied(tx + cw - 1, ty)) break;
        aw = cw;
        if (aw >= w) break;
      }
      w = aw;
      int ah = 1;
      for (int ch = 1; ch <= 4; ch++) {
        bool blocked = false;
        for (int cw = 0; cw < w; cw++) {
          if (isOccupied(tx + cw, ty + ch - 1)) {
            blocked = true;
            break;
          }
        }
        if (blocked) break;
        ah = ch;
        if (ah >= h) break;
      }
      h = ah;
      configs.add({'cross': w, 'main': h});
      while (grid.length < ty + h) {
        grid.add(List.filled(columnCount, false));
      }
      for (int r = ty; r < ty + h; r++) {
        for (int c = tx; c < tx + w; c++) {
          grid[r][c] = true;
        }
      }
    }
    return configs;
  }

  void regenerateLibraryLayout() {
    _generateLibraryLayout();
    notifyListeners();
  }

  void _generateLibraryLayout() {
    final random = Random();
    final int columnCount = 4;
    List<Map<String, int>> configs = [];
    List<List<bool>> grid = [];
    bool isOccupied(int x, int y) => y < grid.length && grid[y][x];
    for (int i = 0; i < _allSongs.length; i++) {
      int tx = 0, ty = 0;
      bool found = false;
      int y = 0;
      while (!found) {
        if (y >= grid.length) grid.add(List.filled(columnCount, false));
        for (int x = 0; x < columnCount; x++) {
          if (!grid[y][x]) {
            tx = x;
            ty = y;
            found = true;
            break;
          }
        }
        if (!found) y++;
      }
      double r = random.nextDouble();
      int maxWidth = columnCount - tx;
      int w = 1;
      int h = 1;
      if (r < 0.15 && maxWidth >= 4) {
        w = 4;
      } else if (r < 0.35 && maxWidth >= 3) {
        w = 3;
      }
      else if (r < 0.65 && maxWidth >= 2) {
        w = 2;
      }
      else {
        w = 1;
      }
      h = random.nextInt(3) + 1;
      int actualW = 1;
      for (int cw = 1; cw <= maxWidth; cw++) {
        if (isOccupied(tx + cw - 1, ty)) break;
        actualW = cw;
        if (actualW >= w) break;
      }
      w = actualW;
      int actualH = 1;
      for (int ch = 1; ch <= 3; ch++) {
        bool blocked = false;
        for (int cw = 0; cw < w; cw++) {
          if (isOccupied(tx + cw, ty + ch - 1)) {
            blocked = true;
            break;
          }
        }
        if (blocked) break;
        actualH = ch;
        if (actualH >= h) break;
      }
      h = actualH;
      configs.add({'cross': w, 'main': h});
      while (grid.length < ty + h) {
        grid.add(List.filled(columnCount, false));
      }
      for (int r = ty; r < ty + h; r++) {
        for (int c = tx; c < tx + w; c++) {
          grid[r][c] = true;
        }
      }
    }
    _libraryLayoutConfigs = configs;
  }

  void _handleSongCompletion() async {
    if (_repeatMode == RepeatMode.one) {
      _audioHandler.seek(Duration.zero);
      _audioHandler.play();
    } else if (_repeatMode == RepeatMode.smart) {
      if (currentSong != null) {
        final data = await _db.getSongData(currentSong!.id);
        if ((data?['playCount'] ?? 0) >= 5 &&
            _smartRepeatCount < _maxSmartRepeats) {
          _smartRepeatCount++;
          _audioHandler.seek(Duration.zero);
          _audioHandler.play();
        } else {
          _smartRepeatCount = 0;
          playNext();
        }
      } else {
        playNext();
      }
    } else if (_repeatMode == RepeatMode.all) {
      playNext();
    }
    else {
      if (_currentIndex < _queue.length - 1) {
        playNext();
      } else {
        _audioHandler.stop();
        _audioHandler.seek(Duration.zero);
      }
    }
    notifyListeners();
  }

  Future<void> fetchLyrics(Song song, {bool forceFetch = false}) async {
    if (!forceFetch) {
      final localData = await _db.getSongData(song.id);
      if (localData != null && localData['plainLyrics'] != null) {
        _currentLyrics = localData['plainLyrics'];
        _currentSyncedLyrics = localData['syncedLyrics'];
        notifyListeners();
        return;
      }
    }
    _isLoadingLyrics = true;
    _currentLyrics = null;
    _currentSyncedLyrics = null;
    notifyListeners();
    try {
      final queryParams = {
        'artist_name': song.artist,
        'track_name': song.title,
      };
      if (song.album != null && song.album != "<unknown>") {
        queryParams['album_name'] = song.album!;
      }
      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentLyrics = data['plainLyrics'];
        _currentSyncedLyrics = data['syncedLyrics'];
        await _db.updateLyrics(song.id, _currentLyrics, _currentSyncedLyrics);
      } else {
        _currentLyrics = response.statusCode == 404
            ? "Lyrics not found."
            : "Error ${response.statusCode}";
      }
    } catch (e) {
      _currentLyrics = "Connection Error.";
    } finally {
      _isLoadingLyrics = false;
      notifyListeners();
    }
  }

  void _startBackgroundLyricsSync() async {
    for (var song in _allSongs) {
      final localData = await _db.getSongData(song.id);
      if (localData == null || localData['plainLyrics'] == null) {
        try {
          final queryParams = {
            'artist_name': song.artist,
            'track_name': song.title,
          };
          if (song.album != null && song.album != "<unknown>") {
            queryParams['album_name'] = song.album!;
          }
          final response = await http.get(
            Uri.https('lrclib.net', '/api/get', queryParams),
          );
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            await _db.updateLyrics(
              song.id,
              data['plainLyrics'],
              data['syncedLyrics'],
            );
          }
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    if (_isShuffleEnabled) {
      _originalQueue = List.from(_queue);
      Song? current = currentSong;
      _queue.shuffle();
      if (current != null) {
        _queue.remove(current);
        _queue.insert(0, current);
        _currentIndex = 0;
      }
    } else {
      Song? current = currentSong;
      _queue = List.from(_originalQueue);
      if (current != null) _currentIndex = _queue.indexOf(current);
    }
    notifyListeners();
  }

  void toggleRepeat() {
    if (_repeatMode == RepeatMode.off) {
      _repeatMode = RepeatMode.all;
    } else if (_repeatMode == RepeatMode.all) {
      _repeatMode = RepeatMode.one;
    } else if (_repeatMode == RepeatMode.one) {
      _repeatMode = RepeatMode.smart;
    } else {
      _repeatMode = RepeatMode.off;
    }
    notifyListeners();
  }

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes == 0) {
      _sleepTimerSecondsRemaining = 0;
    } else {
      _sleepTimerSecondsRemaining = minutes * 60;
      _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_sleepTimerSecondsRemaining > 0) {
          _sleepTimerSecondsRemaining--;
          notifyListeners();
        } else {
          _audioHandler.pause();
          _sleepTimer?.cancel();
          _sleepTimerSecondsRemaining = 0;
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  void setCurrentCollection(String name, {List<Song>? newQueue}) {
    _currentCollection = name;
    if (newQueue != null) {
      _queue = List.from(newQueue);
      _originalQueue = List.from(newQueue);
    } else {
      _queue = List.from(_allSongs);
      _originalQueue = List.from(_allSongs);
    }
    if (_isShuffleEnabled) _queue.shuffle();
    notifyListeners();
  }

  Future<void> checkAndRequestPermissions() async {
    if (await Permission.audio.isGranted ||
        await Permission.storage.isGranted) {
      _hasPermission = true;
    } else {
      Map<Permission, PermissionStatus> s = await [
        Permission.storage,
        Permission.audio,
      ].request();
      _hasPermission =
          s[Permission.audio] == PermissionStatus.granted ||
          s[Permission.storage] == PermissionStatus.granted;
    }
    if (_hasPermission) {
      await scanLocalSongs();
      _categorizeSongs();
    }
    notifyListeners();
  }

  Future<void> scanLocalSongs() async {
    try {
      List<SongModel> queriedSongs = await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      if (queriedSongs.isNotEmpty) {
        final random = Random();
        String cleanTitle(String title) => title
            .replaceAll(RegExp(r'[-_]'), ' ')
            .split(' ')
            .map(
              (w) => w.isEmpty
                  ? ""
                  : w[0].toUpperCase() + w.substring(1).toLowerCase(),
            )
            .join(' ');
        List<Song> tempSongs = [];
        for (var s in queriedSongs) {
          if (_settingsProvider != null) {
            final path = s.data;
            bool isExcluded = false;
            for (var folder in _settingsProvider!.excludedFolders) {
              if (path.startsWith(folder)) {
                isExcluded = true;
                break;
              }
            }
            if (isExcluded) continue;

            if (_settingsProvider!.isRestrictedMode) {
              bool isAllowed = false;
              for (var folder in _settingsProvider!.restrictedFolders) {
                if (path.startsWith(folder)) {
                  isAllowed = true;
                  break;
                }
              }
              if (!isAllowed) continue;
            }
          }

          // Ensure metadata is synced in DB so we can find it by album later
          await _db.syncSongMetadata(s.id, s.album);

          final dbData = await _db.getSongData(s.id);
          tempSongs.add(
            Song(
              id: s.id,
              title: cleanTitle(s.title),
              artist: s.artist ?? "Unknown Artist",
              genre: s.genre,
              album: s.album,
              uri: s.uri,
              duration: s.duration,
              externalArtPath: dbData?['externalArtPath'] as String?,
              color: [
                Colors.deepPurpleAccent,
                Colors.blueAccent,
                Colors.greenAccent,
                Colors.orangeAccent,
                Colors.pinkAccent,
              ][random.nextInt(5)],
            ),
          );
        }
        _allSongs = tempSongs;
        if (_currentCollection == "Library") _queue = List.from(_allSongs);
        _startBackgroundLyricsSync();
      }
    } catch (e) {
      debugPrint("Scan Error: $e");
    }
    notifyListeners();
  }

  void playSong(int index, {List<Song>? fromQueue}) async {
    if (fromQueue != null) _queue = fromQueue;
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _isMiniPlayerVisible = true;
    _smartRepeatCount = 0;
    notifyListeners();
    await _db.incrementPlayCount(_queue[_currentIndex].id);
    fetchLyrics(_queue[_currentIndex]);
    try {
      final s = _queue[_currentIndex];
      final item = MediaItem(
        id: s.id.toString(),
        album: s.album,
        title: s.title,
        artist: s.artist,
        duration: s.duration != null ? Duration(milliseconds: s.duration!) : null,
        artUri: s.externalArtPath != null ? Uri.file(s.externalArtPath!) : null,
      );
      final handler = _audioHandler as AudioPlayerHandler;
      await handler.updateAudioSource(
        item,
        s.uri,
      );
      await handler.setVolume(1.0);
      _audioHandler.play();
    } catch (e) {
      debugPrint("Play Error: $e");
    }
    notifyListeners();
  }

  void togglePlay() {
    if (_audioHandler.playbackState.value.playing) {
      _audioHandler.pause();
    } else {
      _audioHandler.play();
    }
    notifyListeners();
  }

  void playNext() {
    if (_queue.isNotEmpty) playSong((_currentIndex + 1) % _queue.length);
  }

  void playPrevious() {
    if (_queue.isNotEmpty) {
      playSong((_currentIndex - 1 + _queue.length) % _queue.length);
    }
  }

  void hideMiniPlayer() {
    _isMiniPlayerVisible = false;
    _audioHandler.stop();
    notifyListeners();
  }

  void seek(Duration p) {
    _audioHandler.seek(p);
  }

  @override
  void dispose() {
    _audioHandler.stop();
    _sleepTimer?.cancel();
    _navController.close();
    super.dispose();
  }
}
