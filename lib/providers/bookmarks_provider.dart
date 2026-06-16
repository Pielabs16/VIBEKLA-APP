import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class BookmarksProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  final Set<String> _bookmarkedVenues = {};
  final Set<String> _bookmarkedEvents = {};

  Set<String> get bookmarkedVenues => _bookmarkedVenues;
  Set<String> get bookmarkedEvents => _bookmarkedEvents;
  bool get hasBookmarks => _bookmarkedVenues.isNotEmpty || _bookmarkedEvents.isNotEmpty;
  int get totalBookmarks => _bookmarkedVenues.length + _bookmarkedEvents.length;

  BookmarksProvider() {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = _storageService.getBookmarks();
    _bookmarkedVenues.clear();
    _bookmarkedEvents.clear();
    for (final bookmark in bookmarks) {
      final parts = bookmark.split(':');
      if (parts.length == 2) {
        if (parts[0] == 'venue') {
          _bookmarkedVenues.add(parts[1]);
        } else if (parts[0] == 'event') {
          _bookmarkedEvents.add(parts[1]);
        }
      }
    }
    notifyListeners();
  }

  bool isVenueBookmarked(String venueId) => _bookmarkedVenues.contains(venueId);
  bool isEventBookmarked(String eventId) => _bookmarkedEvents.contains(eventId);

  Future<void> toggleVenueBookmark(String venueId) async {
    if (_bookmarkedVenues.contains(venueId)) {
      _bookmarkedVenues.remove(venueId);
      await _storageService.removeBookmark(venueId, 'venue');
    } else {
      _bookmarkedVenues.add(venueId);
      await _storageService.addBookmark(venueId, 'venue');
    }
    notifyListeners();
  }

  Future<void> toggleEventBookmark(String eventId) async {
    if (_bookmarkedEvents.contains(eventId)) {
      _bookmarkedEvents.remove(eventId);
      await _storageService.removeBookmark(eventId, 'event');
    } else {
      _bookmarkedEvents.add(eventId);
      await _storageService.addBookmark(eventId, 'event');
    }
    notifyListeners();
  }

  Future<void> clearAllBookmarks() async {
    _bookmarkedVenues.clear();
    _bookmarkedEvents.clear();
    notifyListeners();
  }
}
