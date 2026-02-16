import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String _keyCrossfade = 'crossfade_value';
  static const String _keyEqEnabled = 'eq_enabled';
  static const String _keyEqBands = 'eq_bands';
  static const String _keyBassBoost = 'bass_boost';
  static const String _keyVirtualizer = 'virtualizer';
  static const String _keyIsMonochrome = 'is_monochrome';
  static const String _keyShowAlbumArt = 'show_album_art';
  static const String _keyGaplessPlayback = 'gapless_playback';
  static const String _keyStopOnDisconnect = 'stop_on_disconnect';
  static const String _keyAudioQuality = 'audio_quality';
  static const String _keyExcludedFolders = 'excluded_folders';
  static const String _keyRestrictedFolders = 'restricted_folders';
  static const String _keyIsRestrictedMode = 'is_restricted_mode';

  double _crossfadeValue = 5.0;
  bool _isEqEnabled = true;
  List<double> _eqBands = [0.5, 0.5, 0.5, 0.5, 0.5];
  double _bassBoost = 0.5;
  double _virtualizer = 0.5;
  bool _isMonochrome = false;
  bool _showAlbumArt = true;
  bool _gaplessPlayback = true;
  bool _stopOnDisconnect = true;
  String _audioQuality = 'High (320kbps)';
  List<String> _excludedFolders = [];
  List<String> _restrictedFolders = [];
  bool _isRestrictedMode = false;

  double get crossfadeValue => _crossfadeValue;
  bool get isEqEnabled => _isEqEnabled;
  List<double> get eqBands => _eqBands;
  double get bassBoost => _bassBoost;
  double get virtualizer => _virtualizer;
  bool get isMonochrome => _isMonochrome;
  bool get showAlbumArt => _showAlbumArt;
  bool get gaplessPlayback => _gaplessPlayback;
  bool get stopOnDisconnect => _stopOnDisconnect;
  String get audioQuality => _audioQuality;
  List<String> get excludedFolders => _excludedFolders;
  List<String> get restrictedFolders => _restrictedFolders;
  bool get isRestrictedMode => _isRestrictedMode;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _crossfadeValue = prefs.getDouble(_keyCrossfade) ?? 5.0;
    _isEqEnabled = prefs.getBool(_keyEqEnabled) ?? true;

    List<String>? bands = prefs.getStringList(_keyEqBands);
    if (bands != null) {
      _eqBands = bands.map((e) => double.parse(e)).toList();
    }

    _bassBoost = prefs.getDouble(_keyBassBoost) ?? 0.5;
    _virtualizer = prefs.getDouble(_keyVirtualizer) ?? 0.5;
    _isMonochrome = prefs.getBool(_keyIsMonochrome) ?? false;
    _showAlbumArt = prefs.getBool(_keyShowAlbumArt) ?? true;
    _gaplessPlayback = prefs.getBool(_keyGaplessPlayback) ?? true;
    _stopOnDisconnect = prefs.getBool(_keyStopOnDisconnect) ?? true;
    _audioQuality = prefs.getString(_keyAudioQuality) ?? 'High (320kbps)';
    _excludedFolders = prefs.getStringList(_keyExcludedFolders) ?? [];
    _restrictedFolders = prefs.getStringList(_keyRestrictedFolders) ?? [];
    _isRestrictedMode = prefs.getBool(_keyIsRestrictedMode) ?? false;

    notifyListeners();
  }

  Future<void> setExcludedFolders(List<String> folders) async {
    _excludedFolders = folders;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyExcludedFolders, folders);
    notifyListeners();
  }

  Future<void> setRestrictedFolders(List<String> folders) async {
    _restrictedFolders = folders;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyRestrictedFolders, folders);
    notifyListeners();
  }

  Future<void> setRestrictedMode(bool value) async {
    _isRestrictedMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsRestrictedMode, value);
    notifyListeners();
  }

  Future<void> setCrossfade(double value) async {
    _crossfadeValue = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCrossfade, value);
    notifyListeners();
  }

  Future<void> setEqEnabled(bool value) async {
    _isEqEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEqEnabled, value);
    notifyListeners();
  }

  Future<void> setEqBand(int index, double value) async {
    _eqBands[index] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyEqBands,
      _eqBands.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  Future<void> setBassBoost(double value) async {
    _bassBoost = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBassBoost, value);
    notifyListeners();
  }

  Future<void> setVirtualizer(double value) async {
    _virtualizer = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVirtualizer, value);
    notifyListeners();
  }

  Future<void> setMonochrome(bool value) async {
    _isMonochrome = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsMonochrome, value);
    notifyListeners();
  }

  Future<void> setShowAlbumArt(bool value) async {
    _showAlbumArt = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowAlbumArt, value);
    notifyListeners();
  }

  Future<void> setGaplessPlayback(bool value) async {
    _gaplessPlayback = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGaplessPlayback, value);
    notifyListeners();
  }

  Future<void> setStopOnDisconnect(bool value) async {
    _stopOnDisconnect = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyStopOnDisconnect, value);
    notifyListeners();
  }

  Future<void> setAudioQuality(String value) async {
    _audioQuality = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAudioQuality, value);
    notifyListeners();
  }
}
