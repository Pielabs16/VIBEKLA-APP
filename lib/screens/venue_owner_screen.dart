import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'add_event_screen.dart';
import 'payment_screen.dart';

class VenueOwnerScreen extends StatefulWidget {
  const VenueOwnerScreen({super.key});

  @override
  State<VenueOwnerScreen> createState() => _VenueOwnerScreenState();
}

class _VenueOwnerScreenState extends State<VenueOwnerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Venue? _venue;
  List<Event> _events = [];
  Map<String, dynamic>? _analytics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiService();
      final owned = await api.fetchMyVenues();

      if (owned.isNotEmpty) {
        final v = owned.first;
        final eventsResult = await api.fetchEvents(venueId: v.id);
        final analytics = await api
            .fetchVenueAnalytics(v.id)
            .catchError((_) => <String, dynamic>{});
        if (mounted) {
          setState(() {
            _venue    = v;
            _events   = eventsResult.data;
            _analytics = analytics;
            _loading  = false;
          });
        }
      } else {
        if (mounted) setState(() { _loading = false; _venue = null; });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _venue == null
                  ? _NoVenueView(onApply: () => context.push('/applications/new'))
                  : _VenueDashboard(
                      venue: _venue!,
                      events: _events,
                      analytics: _analytics ?? {},
                      tabs: _tabs,
                      onAddEvent: () async {
                        final added = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => AddEventScreen(
                              venueId: _venue!.id,
                              venueName: _venue!.name,
                            ),
                          ),
                        );
                        if (added == true) _load();
                      },
                      onUpgrade: () async {
                        final upgraded = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(
                              venueId: _venue!.id,
                              venueName: _venue!.name,
                            ),
                          ),
                        );
                        if (upgraded == true) _load();
                      },
                    ),
    );
  }
}

class _VenueDashboard extends StatelessWidget {
  final Venue venue;
  final List<Event> events;
  final Map<String, dynamic> analytics;
  final TabController tabs;
  final VoidCallback onAddEvent;
  final VoidCallback onUpgrade;

  const _VenueDashboard({
    required this.venue,
    required this.events,
    required this.analytics,
    required this.tabs,
    required this.onAddEvent,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (ctx, _) => [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppTheme.surfaceColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.onSurfaceColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('My Venue',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceColor)),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor(venue.imageType),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: -20,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 60,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            venue.subscriptionTier.name.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          venue.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              venue.neighborhood,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.star_rounded,
                                size: 13, color: Color(0xFFFFB300)),
                            const SizedBox(width: 3),
                            Text(
                              venue.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: AppTheme.surfaceColor,
              child: TabBar(
                controller: tabs,
                indicatorColor: AppTheme.primaryColor,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.mutedColor,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Events'),
                  Tab(text: 'Analytics'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium_rounded, size: 14),
                        SizedBox(width: 4),
                        Text('Subscription', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: tabs,
        children: [
          _OverviewTab(
              venue: venue, onAddEvent: onAddEvent, onUpgrade: onUpgrade),
          _EventsTab(events: events, onAddEvent: onAddEvent),
          _AnalyticsTab(analytics: analytics, venue: venue),
          _SubscriptionTab(venue: venue),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Venue venue;
  final VoidCallback onAddEvent;
  final VoidCallback onUpgrade;

  const _OverviewTab({
    required this.venue,
    required this.onAddEvent,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = venue.subscriptionTier == SubscriptionTier.premium;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StatBox(
                  iconData: Icons.star_rounded,
                  label: 'Rating',
                  value: venue.rating.toStringAsFixed(1)),
              const SizedBox(width: 12),
              _StatBox(
                  iconData: Icons.people_rounded,
                  label: 'Check-ins',
                  value: venue.ratingCount.toString()),
              const SizedBox(width: 12),
              _StatBox(
                  iconData: Icons.celebration_rounded,
                  label: 'Events',
                  value: venue.subscriptionTier == SubscriptionTier.premium
                      ? '∞'
                      : venue.subscriptionTier == SubscriptionTier.pro
                          ? '10'
                          : '2'),
            ],
          ),
          const SizedBox(height: 20),

          _ActionCard(
            iconData: Icons.celebration_rounded,
            title: 'Add New Event',
            subtitle: 'Create and promote your events',
            color: AppTheme.primaryColor,
            onTap: onAddEvent,
          ),
          const SizedBox(height: 12),
          if (!isPremium) ...[
            _ActionCard(
              iconData: Icons.workspace_premium_rounded,
              title: 'Upgrade to Premium',
              subtitle:
                  'Unlimited events, top ranking & analytics',
              color: AppTheme.accentColor,
              onTap: onUpgrade,
            ),
            const SizedBox(height: 12),
          ],

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Venue Info',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurfaceColor)),
                const SizedBox(height: 12),
                _InfoRow(
                    icon: Icons.category_outlined,
                    label: 'Category',
                    value: venue.category),
                _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: venue.address),
                _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: venue.contactPhone ?? 'Not set'),
                _InfoRow(
                    icon: Icons.alternate_email,
                    label: 'Instagram',
                    value: venue.instagramHandle ?? 'Not set'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventsTab extends StatelessWidget {
  final List<Event> events;
  final VoidCallback onAddEvent;

  const _EventsTab({required this.events, required this.onAddEvent});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration_rounded,
                size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            const Text('No events yet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurfaceColor)),
            const SizedBox(height: 6),
            const Text('Create your first event',
                style: TextStyle(
                    fontSize: 14, color: AppTheme.mutedColor)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAddEvent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('+ Add Event',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: events.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onAddEvent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('+ Add Event',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          );
        }
        final ev = events[i - 1];
        return _EventRow(event: ev);
      },
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> analytics;
  final Venue venue;

  const _AnalyticsTab(
      {required this.analytics, required this.venue});

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _StatBox(
                  iconData: Icons.location_on_rounded,
                  label: 'Total Check-ins',
                  value: (a['totalCheckins'] ?? '—').toString()),
              const SizedBox(width: 12),
              _StatBox(
                  iconData: Icons.bar_chart_rounded,
                  label: 'Avg Rating',
                  value: venue.rating.toStringAsFixed(1)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatBox(
                  iconData: Icons.visibility_rounded,
                  label: 'Profile Views',
                  value: (a['profileViews'] ?? '—').toString()),
              const SizedBox(width: 12),
              _StatBox(
                  iconData: Icons.celebration_rounded,
                  label: 'Active Events',
                  value: (a['activeEvents'] ?? '—').toString()),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vibe Tags',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurfaceColor)),
                const SizedBox(height: 12),
                if (a['topVibeTags'] != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (a['topVibeTags'] as List<dynamic>)
                        .take(8)
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                tag['tag'] as String? ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ))
                        .toList(),
                  )
                else
                  const Text('No vibe tag data yet',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.mutedColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionTab extends StatefulWidget {
  final Venue venue;
  const _SubscriptionTab({required this.venue});

  @override
  State<_SubscriptionTab> createState() => _SubscriptionTabState();
}

class _SubscriptionTabState extends State<_SubscriptionTab> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiService().subscriptionStatus(widget.venue.id);
      if (mounted) setState(() { _status = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'premium': return const Color(0xFFFFD700);
      case 'pro':     return Colors.blue.shade400;
      default:        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 40, color: Colors.amber),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.mutedColor)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _load,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Retry',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isActive = _status?['isActive'] == true;
    final tier = (_status?['plan'] as String? ??
        _status?['tier'] as String? ?? 'free').toLowerCase();
    final endDate = _status?['endDate'] as String?;
    final tierColor = _tierColor(tier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plan tier card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: tierColor.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.workspace_premium_rounded,
                    size: 40, color: tierColor),
                const SizedBox(height: 10),
                Text(
                  tier.toUpperCase(),
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: tierColor,
                      letterSpacing: 1.5),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive ? 'Active Plan' : 'No Active Plan',
                  style: TextStyle(
                      fontSize: 13,
                      color: isActive
                          ? const Color(0xFF00E676)
                          : AppTheme.mutedColor),
                ),
                if (isActive && endDate != null && endDate.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ExpiryBadge(endDate: endDate),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!isActive)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 32, color: AppTheme.mutedColor),
                  SizedBox(height: 10),
                  Text('No active plan',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurfaceColor)),
                  SizedBox(height: 6),
                  Text(
                    'Upgrade to unlock more events, analytics\nand top venue ranking.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.mutedColor),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),

          const SizedBox(height: 16),

          GestureDetector(
            onTap: () => context.push('/payment'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFb026ff), Color(0xFFff2d92)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Upgrade Plan',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  final String endDate;
  const _ExpiryBadge({required this.endDate});

  @override
  Widget build(BuildContext context) {
    DateTime? expiry;
    try {
      expiry = DateTime.parse(endDate);
    } catch (_) {}

    Color color = AppTheme.onSurfaceColor;
    String label = 'Expires: $endDate';

    if (expiry != null) {
      final now = DateTime.now();
      final diff = expiry.difference(now).inDays;
      if (expiry.isBefore(now)) {
        color = Colors.red;
        label = 'Expired: $endDate';
      } else if (diff <= 7) {
        color = Colors.amber;
        label = 'Expires soon: $endDate';
      } else {
        label = 'Expires: $endDate';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData iconData;
  final String label;
  final String value;

  const _StatBox(
      {required this.iconData, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            Icon(iconData, size: 20, color: AppTheme.primaryColor),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.mutedColor,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData iconData;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.iconData,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(iconData, size: 28, color: Colors.white),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppTheme.mutedColor),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.mutedColor,
                  fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.onSurfaceColor,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final Event event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.cardColor(event.imageType),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
                child: Icon(Icons.music_note_rounded,
                    size: 22, color: Colors.white70)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurfaceColor)),
                const SizedBox(height: 3),
                Text(event.genre,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.mutedColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: event.isApproved
                  ? const Color(0xFF00E676).withValues(alpha: 0.12)
                  : const Color(0xFFFFB300).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              event.isApproved ? 'Live' : 'Review',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: event.isApproved
                    ? const Color(0xFF00E676)
                    : const Color(0xFFFFB300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 40, color: Colors.amber),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.mutedColor)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoVenueView extends StatelessWidget {
  final VoidCallback onApply;

  const _NoVenueView({required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business_rounded,
                size: 52, color: AppTheme.mutedColor),
            const SizedBox(height: 16),
            const Text(
              'No Venue Found',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurfaceColor),
            ),
            const SizedBox(height: 8),
            const Text(
              "You haven't registered a venue yet. Apply to list your club, bar, or lounge.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.mutedColor),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onApply,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Apply to List Your Venue',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
