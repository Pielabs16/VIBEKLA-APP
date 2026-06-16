import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ContentProvider extends ChangeNotifier {
  List<String> _genres = [];
  List<String> _venueCategories = [];
  List<String> _neighborhoods = [];
  List<VibeTag> _vibeTags = [];
  List<AppBanner> _banners = [];
  List<Map<String, dynamic>> _helpContacts = [];
  List<Map<String, dynamic>> _licenses = [];
  Map<String, dynamic> _appSettings = {};
  bool _loaded = false;

  String _selectedRegion = 'Kampala, UG';

  static const _fallbackGenres = [
    'Afrobeats', 'Amapiano', 'Hip Hop', 'R&B', 'Electronic', 'Live Band',
  ];
  static const _fallbackCategories = [
    'Club', 'Bar', 'Lounge', 'Rooftop', 'Restaurant',
  ];
  static const _fallbackVibeTags = [
    VibeTag(name: 'Fire',        emoji: '🔥'),
    VibeTag(name: 'Chill',       emoji: '😌'),
    VibeTag(name: 'Packed',      emoji: '👥'),
    VibeTag(name: 'Great Music', emoji: '🎵'),
    VibeTag(name: 'Good Vibes',  emoji: '✨'),
    VibeTag(name: 'Pricey',      emoji: '💸'),
    VibeTag(name: 'Affordable',  emoji: '💰'),
    VibeTag(name: 'Must Visit',  emoji: '⭐'),
    VibeTag(name: 'Hidden Gem',  emoji: '💎'),
    VibeTag(name: 'DJ Slapped',  emoji: '🎧'),
    VibeTag(name: 'Live Band',   emoji: '🎸'),
    VibeTag(name: 'Rooftop',     emoji: '🌙'),
    VibeTag(name: 'Overrated',   emoji: '😕'),
    VibeTag(name: 'Dead Inside', emoji: '💀'),
  ];

  List<String> get genres          => _genres.isNotEmpty          ? _genres          : _fallbackGenres;
  List<String> get venueCategories => _venueCategories.isNotEmpty ? _venueCategories : _fallbackCategories;
  List<VibeTag> get vibeTags       => _vibeTags.isNotEmpty        ? _vibeTags        : _fallbackVibeTags;
  List<String> get neighborhoods   => _neighborhoods;
  List<AppBanner> get banners      => _banners;
  List<Map<String, dynamic>> get helpContacts => _helpContacts;
  List<Map<String, dynamic>> get licenses     => _licenses;
  Map<String, dynamic> get appSettings        => _appSettings;
  String get googleMapsApiKey => _appSettings['google_maps_api_key'] as String? ?? '';
  bool get hasLoaded => _loaded;

  String get selectedRegion => _selectedRegion;

  List<String> get allRegions {
    final result = <String>['Kampala, UG'];
    for (final nb in _neighborhoods) {
      if (!result.contains(nb)) result.add(nb);
    }
    return result;
  }

  void setRegion(String region) {
    if (_selectedRegion == region) return;
    _selectedRegion = region;
    notifyListeners();
  }

  Future<void> fetchContent() async {
    try {
      final result = await ApiService().fetchContent();

      _genres = List<String>.from(result['genres'] as List? ?? []);

      final catRaw = result['venueCategories'] as List? ?? [];
      _venueCategories = catRaw.map((c) {
        if (c is String) return c;
        return (c as Map<String, dynamic>)['name'] as String;
      }).toList();

      final nbRaw = result['neighborhoods'] as List? ?? [];
      _neighborhoods = nbRaw
          .map((n) => (n as Map<String, dynamic>)['name'] as String)
          .toList();

      final vtRaw = result['vibeTags'] as List? ?? [];
      _vibeTags = vtRaw.map((t) => VibeTag.fromJson(t as Map<String, dynamic>)).toList();

      final bannerRaw = result['banners'] as List? ?? [];
      _banners = bannerRaw.map((b) => AppBanner.fromJson(b as Map<String, dynamic>)).toList();

      final helpRaw = result['helpContacts'] as List? ?? [];
      _helpContacts = helpRaw.map((h) => Map<String, dynamic>.from(h as Map)).toList();

      final licRaw = result['licenses'] as List? ?? [];
      _licenses = licRaw.map((l) => Map<String, dynamic>.from(l as Map)).toList();

      final settings = result['appSettings'] as Map<String, dynamic>? ?? {};
      _appSettings = settings;

      _loaded = true;
      notifyListeners();
    } catch (_) {
      _loaded = true;
      notifyListeners();
    }
  }
}
