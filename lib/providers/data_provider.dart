import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class DataProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Venue> _venues = [];
  List<Event> _events = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  int _venuesPage = 1;
  bool _venuesHasMore = true;
  int _eventsPage = 1;
  bool _eventsHasMore = true;

  List<Venue> get venues => _venues;
  List<Event> get events => _events;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasVenueError => _error != null && _venues.isEmpty;
  bool get venuesHasMore => _venuesHasMore;
  bool get eventsHasMore => _eventsHasMore;

  Future<void> fetchAll({bool refresh = false}) async {
    if (refresh) {
      _venuesPage = 1;
      _eventsPage = 1;
      _venuesHasMore = true;
      _eventsHasMore = true;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.fetchVenues(page: 1),
        _api.fetchEvents(page: 1),
      ]);
      final vr = results[0] as PaginatedResult<Venue>;
      final er = results[1] as PaginatedResult<Event>;
      _venues = vr.data;
      _events = er.data;
      _venuesHasMore = vr.hasNext;
      _eventsHasMore = er.hasNext;
      _venuesPage = 1;
      _eventsPage = 1;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchVenues({bool refresh = false}) async {
    if (refresh) { _venuesPage = 1; _venuesHasMore = true; }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.fetchVenues(page: 1);
      _venues = result.data;
      _venuesHasMore = result.hasNext;
      _venuesPage = 1;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchEvents({bool refresh = false}) async {
    if (refresh) { _eventsPage = 1; _eventsHasMore = true; }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.fetchEvents(page: 1);
      _events = result.data;
      _eventsHasMore = result.hasNext;
      _eventsPage = 1;
    } catch (e) {
      _error = _friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreVenues() async {
    if (_isLoadingMore || !_venuesHasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final result = await _api.fetchVenues(page: _venuesPage + 1);
      _venues = [..._venues, ...result.data];
      _venuesHasMore = result.hasNext;
      _venuesPage++;
    } catch (_) {
      // silently fail on load-more
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreEvents() async {
    if (_isLoadingMore || !_eventsHasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final result = await _api.fetchEvents(page: _eventsPage + 1);
      _events = [..._events, ...result.data];
      _eventsHasMore = result.hasNext;
      _eventsPage++;
    } catch (_) {
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<List<Venue>> searchVenues(String query,
      {String? category, String? region, String? sort,
       double? lat, double? lng, double? radiusKm}) async {
    try {
      final result = await _api.fetchVenues(
        search: query.isNotEmpty ? query : null,
        category: category,
        region: region,
        sort: sort,
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
      );
      return result.data;
    } catch (_) {
      var list = _venues;
      if (query.isNotEmpty) {
        list = list
            .where((v) => v.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      if (category != null && category != 'All') {
        list = list
            .where((v) => v.category.toLowerCase() == category.toLowerCase())
            .toList();
      }
      if (region != null && region != 'All') {
        list = list
            .where((v) => v.region.toLowerCase() == region.toLowerCase())
            .toList();
      }
      return list;
    }
  }

  Future<List<Event>> searchEvents(String query, {String? genre}) async {
    try {
      final result = await _api.fetchEvents(
        search: query.isNotEmpty ? query : null,
        genre: genre,
      );
      return result.data;
    } catch (_) {
      var list = _events;
      if (query.isNotEmpty) {
        list = list
            .where((e) => e.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      if (genre != null && genre != 'All') {
        list = list
            .where((e) => e.genre.toLowerCase() == genre.toLowerCase())
            .toList();
      }
      return list;
    }
  }

  Venue? getVenueById(String id) {
    try { return _venues.firstWhere((v) => v.id == id); } catch (_) { return null; }
  }

  Event? getEventById(String id) {
    try { return _events.firstWhere((e) => e.id == id); } catch (_) { return null; }
  }

  List<Event> getEventsForVenue(String venueId) =>
      _events.where((e) => e.venueId == venueId).toList();

  List<Venue> get featuredVenues =>
      _venues.where((v) => v.subscriptionTier == SubscriptionTier.premium).toList();

  List<Event> get featuredEvents =>
      _events.where((e) => e.featured).toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socket') || msg.contains('connection') || msg.contains('network')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (msg.contains('timeout')) return 'Request timed out. Try again.';
    if (msg.contains('401') || msg.contains('unauthorized')) return 'Session expired. Please sign in again.';
    return 'Could not load data. Pull down to refresh.';
  }
}
