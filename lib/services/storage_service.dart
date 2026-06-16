import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static const _venuesBox    = 'venues';
  static const _eventsBox    = 'events';
  static const _checkInsBox  = 'checkIns';
  static const _bookmarksBox = 'bookmarks';

  Box<dynamic>? _venues;
  Box<dynamic>? _events;
  Box<dynamic>? _checkIns;
  Box<dynamic>? _bookmarks;
  SharedPreferences? _prefs;

  static final StorageService _instance = StorageService._internal();
  StorageService._internal();
  factory StorageService() => _instance;

  Future<void> initialize() async {
    await Hive.initFlutter();
    _venues    = await Hive.openBox(_venuesBox);
    _events    = await Hive.openBox(_eventsBox);
    _checkIns  = await Hive.openBox(_checkInsBox);
    _bookmarks = await Hive.openBox(_bookmarksBox);
    _prefs     = await SharedPreferences.getInstance();
  }

  Future<void> saveVenues(List<Venue> venues) async {
    final box = _venues;
    if (box == null) return;
    await box.clear();
    for (final v in venues) {
      await box.put(v.id, v.toJson());
    }
  }

  Future<List<Venue>> getVenues() async {
    final box = _venues;
    if (box == null) return [];
    return [
      for (var i = 0; i < box.length; i++)
        Venue.fromJson(Map<String, dynamic>.from(box.getAt(i) as Map)),
    ];
  }

  Future<Venue?> getVenue(String id) async {
    final raw = _venues?.get(id);
    if (raw == null) return null;
    return Venue.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> saveVenue(Venue venue) async {
    await _venues?.put(venue.id, venue.toJson());
  }

  Future<void> saveEvents(List<Event> events) async {
    final box = _events;
    if (box == null) return;
    await box.clear();
    for (final e in events) {
      await box.put(e.id, e.toJson());
    }
  }

  Future<List<Event>> getEvents() async {
    final box = _events;
    if (box == null) return [];
    return [
      for (var i = 0; i < box.length; i++)
        Event.fromJson(Map<String, dynamic>.from(box.getAt(i) as Map)),
    ];
  }

  Future<Event?> getEvent(String id) async {
    final raw = _events?.get(id);
    if (raw == null) return null;
    return Event.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> saveEvent(Event event) async {
    await _events?.put(event.id, event.toJson());
  }

  Future<void> saveCheckIn(CheckIn checkIn) async {
    await _checkIns?.put(checkIn.id, checkIn.toJson());
  }

  Future<List<CheckIn>> getCheckIns() async {
    final box = _checkIns;
    if (box == null) return [];
    return [
      for (var i = 0; i < box.length; i++)
        CheckIn.fromJson(Map<String, dynamic>.from(box.getAt(i) as Map)),
    ];
  }

  List<String> getBookmarks() {
    final raw = _bookmarks?.get('bookmarks');
    return raw != null ? List<String>.from(raw as List) : [];
  }

  Future<void> addBookmark(String entityId, String entityType) async {
    final list = getBookmarks();
    final key = '$entityType:$entityId';
    if (!list.contains(key)) {
      list.add(key);
      await _bookmarks?.put('bookmarks', list);
    }
  }

  Future<void> removeBookmark(String entityId, String entityType) async {
    final list = getBookmarks();
    list.remove('$entityType:$entityId');
    await _bookmarks?.put('bookmarks', list);
  }

  bool isBookmarked(String entityId, String entityType) {
    return getBookmarks().contains('$entityType:$entityId');
  }

  Future<void> setLastViewedVenue(String venueId) async =>
      _prefs?.setString('last_viewed_venue', venueId);

  String? getLastViewedVenue() => _prefs?.getString('last_viewed_venue');

  Future<void> setLastSync(DateTime dt) async =>
      _prefs?.setString('last_sync', dt.toIso8601String());

  DateTime? getLastSync() {
    final raw = _prefs?.getString('last_sync');
    return raw != null ? DateTime.parse(raw) : null;
  }

  Future<void> setThemeDark(bool isDark) async =>
      _prefs?.setBool('theme_dark', isDark);

  bool getThemeDark() => _prefs?.getBool('theme_dark') ?? true;

  // Clears cached content (venues/events) without touching auth tokens or bookmarks
  Future<void> clearCache() async {
    await _venues?.clear();
    await _events?.clear();
    await _checkIns?.clear();
  }

  Future<void> clearAll() async {
    await _venues?.clear();
    await _events?.clear();
    await _checkIns?.clear();
    await _bookmarks?.clear();
    await _prefs?.clear();
  }
}
