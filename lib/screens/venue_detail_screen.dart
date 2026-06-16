import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';
import '../config/theme.dart';
import '../widgets/reservation_sheet.dart';
import 'event_detail_screen.dart';
import 'vibe_rating_screen.dart';

class VenueDetailScreen extends StatelessWidget {
  final String venueId;
  const VenueDetailScreen({super.key, required this.venueId});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, _) {
        final venue = data.getVenueById(venueId);
        if (venue == null) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(title: const Text('Venue Details')),
            body: const Center(child: Text('Venue not found')),
          );
        }
        return _VenueContent(venue: venue, data: data);
      },
    );
  }
}

class _VenueContent extends StatefulWidget {
  final Venue venue;
  final DataProvider data;
  const _VenueContent({required this.venue, required this.data});

  @override
  State<_VenueContent> createState() => _VenueContentState();
}

class _VenueContentState extends State<_VenueContent> {
  bool _checkingIn = false;

  Future<void> _doCheckIn() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    try {
      final auth = context.read<AuthProvider>();
      final userName = auth.user?.firstName ?? auth.user?.email ?? 'Guest';
      await ApiService().createCheckIn(widget.venue.id, userName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Checked in at ${widget.venue.name}!'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Check-in failed. Try again.'),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final upcomingEvents = widget.data.getEventsForVenue(venue.id);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _VenueHeroAppBar(venue: venue),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(venue.name,
                                style: Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 4),
                            Text(
                              venue.category,
                              style: const TextStyle(
                                color: AppTheme.accentColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PriceBadge(level: venue.priceLevel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RatingBar(rating: venue.bayesRating, count: venue.ratingCount),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _InfoTile(
                        icon: Icons.location_on_rounded,
                        label: 'Location',
                        value: venue.neighborhood,
                      ),
                      const SizedBox(width: 10),
                      _InfoTile(
                        icon: Icons.access_time_rounded,
                        label: 'Hours',
                        value: venue.hours,
                      ),
                    ],
                  ),
                  if (venue.djTonight.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _DJTonightBanner(djName: venue.djTonight),
                  ],
                  if (venue.vibe.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Vibe', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: venue.vibe
                          .map((v) => VibeFilterChip(
                                label: v,
                                selected: false,
                                onSelected: () {},
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('About', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(venue.description,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.home_rounded,
                          size: 14, color: AppTheme.mutedColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(venue.address,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                  if (upcomingEvents.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text('Events Here',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ...upcomingEvents.take(3).map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: EventCard(
                              event: e,
                              venue: venue,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EventDetailScreen(eventId: e.id),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: _checkingIn ? 'Checking in…' : 'Check In',
                          icon: _checkingIn
                              ? Icons.hourglass_top_rounded
                              : Icons.check_circle_outline_rounded,
                          onPressed: _checkingIn ? () {} : _doCheckIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GradientButton(
                          label: 'Rate Vibe',
                          icon: Icons.star_outline_rounded,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => VibeRatingScreen(
                                entityId: venue.id,
                                entityType: 'venue',
                                entityName: venue.name,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: 'Reserve a Table',
                    icon: Icons.event_seat_outlined,
                    onPressed: () => showReservationSheet(context, venue),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueHeroAppBar extends StatelessWidget {
  final Venue venue;
  const _VenueHeroAppBar({required this.venue});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppTheme.backgroundColor,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      actions: [
        Consumer<BookmarksProvider>(
          builder: (context, bookmarks, _) {
            final saved = bookmarks.isVenueBookmarked(venue.id);
            return GestureDetector(
              onTap: () => bookmarks.toggleVenueBookmark(venue.id),
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: saved ? AppTheme.primaryColor : Colors.white,
                  size: 20,
                ),
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppTheme.cardColor(venue.imageType)),
            if (venue.imageUrl != null && venue.imageUrl!.isNotEmpty)
              Image.network(
                venue.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            else
              Center(
                child: Icon(
                  Icons.nightlife_rounded,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            // Dark scrim so title text stays readable
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.mutedColor)),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DJTonightBanner extends StatelessWidget {
  final String djName;
  const _DJTonightBanner({required this.djName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.headphones_rounded,
              size: 18, color: AppTheme.accentColor),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DJ Tonight',
                  style:
                      TextStyle(fontSize: 10, color: AppTheme.mutedColor)),
              Text(
                djName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  final int level;
  const _PriceBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          4,
          (i) => Text(
            'UGX',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: i < level
                  ? AppTheme.primaryColor
                  : const Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }
}
