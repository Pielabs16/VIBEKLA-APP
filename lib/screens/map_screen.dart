import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../providers/content_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  WebViewController? _webCtrl;
  Venue? _selectedVenue;
  bool _mapReady = false;
  bool _locating = false;
  Timer? _liveTimer;
  String? _loadedKey;

  static const _lat = 0.3476;
  static const _lng = 32.5825;

  @override
  void initState() {
    super.initState();
    // Refresh venue data every 60 s for live mapping
    _liveTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) context.read<DataProvider>().fetchAll(refresh: true);
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _initWebView(String apiKey) {
    if (_loadedKey == apiKey) return;
    _loadedKey = apiKey;
    _mapReady = false;

    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0f0823))
      ..addJavaScriptChannel(
        'MapReady',
        onMessageReceived: (_) {
          if (!mounted) return;
          setState(() => _mapReady = true);
          _pushMarkers();
        },
      )
      ..addJavaScriptChannel(
        'VenueChannel',
        onMessageReceived: (msg) {
          if (!mounted) return;
          try {
            final id = (jsonDecode(msg.message) as Map)['id']?.toString();
            if (id == null) return;
            final venue = context
                .read<DataProvider>()
                .venues
                .firstWhere((v) => v.id == id);
            setState(() => _selectedVenue = venue);
          } catch (_) {}
        },
      )
      ..loadHtmlString(_buildHtml(apiKey));

    setState(() => _webCtrl = ctrl);
  }

  void _pushMarkers() {
    final ctrl = _webCtrl;
    if (ctrl == null || !_mapReady || !mounted) return;
    final payload = context
        .read<DataProvider>()
        .venues
        .where((v) => v.latitude != 0 || v.longitude != 0)
        .map((v) => {
              'id': v.id,
              'name': v.name,
              'lat': v.latitude,
              'lng': v.longitude,
              'tier': v.subscriptionTier.name,
            })
        .toList();
    ctrl.runJavaScript('addVenueMarkers(${jsonEncode(payload)})');
  }

  Future<void> _locateUser() async {
    setState(() => _locating = true);
    await _webCtrl?.runJavaScript('centerMap($_lat, $_lng, 13.5)');
    if (mounted) setState(() => _locating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0823),
      body: Consumer2<DataProvider, ContentProvider>(
        builder: (ctx, data, content, _) {
          if (!content.hasLoaded) {
            return const _MapPlaceholder(message: 'Loading configuration…');
          }

          final apiKey = content.googleMapsApiKey;

          if (apiKey.isEmpty) {
            return const _MapPlaceholder(
              icon: Icons.map_outlined,
              message: 'Google Maps not configured.\nAdd your API key in\nAdmin → App Settings.',
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initWebView(apiKey);
            if (_mapReady) _pushMarkers();
          });

          final mapped = data.venues
              .where((v) => v.latitude != 0 || v.longitude != 0)
              .toList()
            ..sort((a, b) => b.vibeScore.compareTo(a.vibeScore));
          final topVibe = mapped.isNotEmpty ? mapped.first : null;

          return Stack(
            children: [
              // ── Map WebView ──────────────────────────────────────────────────
              if (_webCtrl != null)
                WebViewWidget(controller: _webCtrl!)
              else
                const _MapPlaceholder(message: 'Initializing map…'),

              // ── Top gradient scrim ───────────────────────────────────────────
              Positioned(
                top: 0, left: 0, right: 0,
                height: MediaQuery.of(ctx).padding.top + 90,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xE6080014), Colors.transparent],
                    ),
                  ),
                ),
              ),

              // ── Header pill ──────────────────────────────────────────────────
              Positioned(
                top: MediaQuery.of(ctx).padding.top + 12,
                left: 16,
                right: 68,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xF8110026),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x80000000), blurRadius: 20, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Kampala',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            Text(
                              '${mapped.length} venues on map',
                              style: const TextStyle(fontSize: 10, color: AppTheme.mutedColor),
                            ),
                          ],
                        ),
                      ),
                      if (data.isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryColor),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Location button ──────────────────────────────────────────────
              Positioned(
                top: MediaQuery.of(ctx).padding.top + 12,
                right: 16,
                child: GestureDetector(
                  onTap: _locateUser,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xF8110026),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x80000000), blurRadius: 20, offset: Offset(0, 4)),
                      ],
                    ),
                    child: _locating
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryColor),
                          )
                        : const Icon(Icons.my_location_rounded, size: 19, color: AppTheme.primaryColor),
                  ),
                ),
              ),

              // ── Top vibe badge ───────────────────────────────────────────────
              if (topVibe != null && _selectedVenue == null)
                Positioned(
                  top: MediaQuery.of(ctx).padding.top + 72,
                  left: 16,
                  child: _TopVibeBadge(venue: topVibe),
                ),

              // ── Venue popup ──────────────────────────────────────────────────
              if (_selectedVenue != null)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: _VenuePopup(
                    venue: _selectedVenue!,
                    onTap: () => context.push('/venue/${_selectedVenue!.id}'),
                    onClose: () => setState(() => _selectedVenue = null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _buildHtml(String apiKey) => '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #0f0823; }
    #map { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    var map, markers = [];

    function initMap() {
      map = new google.maps.Map(document.getElementById('map'), {
        center: { lat: 0.3476, lng: 32.5825 },
        zoom: 13.5,
        disableDefaultUI: true,
        gestureHandling: 'greedy',
        styles: [
          {"elementType":"geometry","stylers":[{"color":"#0f0823"}]},
          {"elementType":"labels.text.fill","stylers":[{"color":"#8b5cf6"}]},
          {"elementType":"labels.text.stroke","stylers":[{"color":"#0f0823"}]},
          {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1e1040"}]},
          {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#2a1a5e"}]},
          {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2d1b69"}]},
          {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0a0518"}]},
          {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#160d36"}]},
          {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#0d1f12"}]},
          {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#150b30"}]},
          {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#3b1d8a"}]}
        ]
      });
      MapReady.postMessage('ready');
    }

    function addVenueMarkers(venues) {
      markers.forEach(function(m) { m.setMap(null); });
      markers = [];
      // venues is already a JS object (Flutter passes it as an object literal)
      var list = Array.isArray(venues) ? venues : JSON.parse(venues);
      list.forEach(function(v) {
        if (!v.lat || !v.lng) return;
        var color = v.tier === 'premium' ? '#8b5cf6' : v.tier === 'pro' ? '#3b82f6' : '#ec4899';
        var m = new google.maps.Marker({
          position: { lat: v.lat, lng: v.lng },
          map: map,
          title: v.name,
          icon: {
            path: google.maps.SymbolPath.CIRCLE,
            scale: 9,
            fillColor: color,
            fillOpacity: 0.95,
            strokeColor: '#ffffff',
            strokeWeight: 2
          }
        });
        m.addListener('click', function() {
          VenueChannel.postMessage(JSON.stringify({ id: v.id }));
        });
        markers.push(m);
      });
    }

    function centerMap(lat, lng, zoom) {
      map.panTo({ lat: lat, lng: lng });
      if (zoom) map.setZoom(zoom);
    }
  </script>
  <script src="https://maps.googleapis.com/maps/api/js?key=$apiKey&callback=initMap" async defer></script>
</body>
</html>
''';
}

// ─── Placeholder (loading / no key) ──────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  final String message;
  final IconData icon;
  const _MapPlaceholder({
    required this.message,
    this.icon = Icons.hourglass_empty_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF080014),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.mutedColor, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top vibe badge ───────────────────────────────────────────────────────────

class _TopVibeBadge extends StatelessWidget {
  final Venue venue;
  const _TopVibeBadge({required this.venue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              venue.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${venue.vibeScore.toStringAsFixed(1)} ★',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Venue popup card ─────────────────────────────────────────────────────────

class _VenuePopup extends StatelessWidget {
  final Venue venue;
  final VoidCallback onTap;
  final VoidCallback onClose;
  const _VenuePopup({required this.venue, required this.onTap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF110026),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 58,
                height: 58,
                color: AppTheme.cardColor(venue.imageType),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (venue.imageUrl != null && venue.imageUrl!.isNotEmpty)
                      Image.network(
                        venue.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    if (venue.imageUrl == null || venue.imageUrl!.isEmpty)
                      const Center(
                        child: Icon(Icons.nightlife_rounded, color: Colors.white38, size: 24),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (venue.isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified_rounded, size: 13, color: AppTheme.primaryColor),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${venue.category} · ${venue.neighborhood}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.mutedColor),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 12, color: AppTheme.primaryColor),
                      const SizedBox(width: 3),
                      Text(
                        'Vibe ${venue.vibeScore.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceColor),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        venue.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 13, color: AppTheme.mutedColor),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 13, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
