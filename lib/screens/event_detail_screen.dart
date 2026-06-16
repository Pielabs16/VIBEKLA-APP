import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/data_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';
import '../widgets/ticket_booking_sheet.dart';
import '../config/theme.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Event? _event; // full event with ticketTypes
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Seed instantly from the cached list, then fetch the full detail (ticketTypes).
    _event = context.read<DataProvider>().getEventById(widget.eventId);
    _loading = _event == null;
    _fetchFull();
  }

  Future<void> _fetchFull() async {
    try {
      final full = await ApiService().fetchEvent(widget.eventId);
      if (!mounted) return;
      setState(() { _event = full; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Only surface an error if we have nothing cached to show.
        if (_event == null) _error = e is ApiException ? e.message : 'Could not load event.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_event == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(title: const Text('Event Details')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : VibeErrorWidget(message: _error ?? 'Event not found', onRetry: _fetchFull),
      );
    }
    final venue = context.watch<DataProvider>().getVenueById(_event!.venueId);
    return _EventContent(event: _event!, venue: venue);
  }
}

class _EventContent extends StatelessWidget {
  final Event event;
  final Venue? venue;
  const _EventContent({required this.event, this.venue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _EventHeroAppBar(event: event),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (event.featured)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'FEATURED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  Text(event.title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    event.genre,
                    style: const TextStyle(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _InfoTile(
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: event.date,
                      ),
                      const SizedBox(width: 10),
                      _InfoTile(
                        icon: Icons.access_time_rounded,
                        label: 'Time',
                        value: '${event.startTime} – ${event.endTime}',
                      ),
                    ],
                  ),
                  if (venue != null) ...[
                    const SizedBox(height: 10),
                    _VenueTile(venue: venue!),
                  ],
                  if (event.artists.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Line-Up',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: event.artists
                          .map((a) => _ArtistChip(name: a))
                          .toList(),
                    ),
                  ],
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('About',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(event.description,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 28),
                  _buildTicketCta(context),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCta(BuildContext context) {
    if (event.hasInternalTicketing) {
      final cheapest = event.ticketTypes
          .map((t) => t.priceUgx)
          .reduce((a, b) => a < b ? a : b);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientButton(
            label: cheapest == 0 ? 'Get Tickets' : 'Get Tickets · from UGX $cheapest',
            icon: Icons.confirmation_num_outlined,
            onPressed: () => showTicketBookingSheet(context, event),
          ),
        ],
      );
    }
    if (event.hasExternalTickets) {
      return GradientButton(
        label: 'Get Tickets',
        icon: Icons.open_in_new_rounded,
        onPressed: () => launchUrl(
          Uri.parse(event.ticketUrl!),
          mode: LaunchMode.externalApplication,
        ),
      );
    }
    final cover = event.cover.trim();
    final hasCover = cover.isNotEmpty && cover != '0';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_activity_outlined, size: 20, color: AppTheme.accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasCover ? 'Entry at the door · UGX $cover' : 'Free entry · No ticket needed',
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventHeroAppBar extends StatelessWidget {
  final Event event;
  const _EventHeroAppBar({required this.event});

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
            final saved = bookmarks.isEventBookmarked(event.id);
            return GestureDetector(
              onTap: () => bookmarks.toggleEventBookmark(event.id),
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  saved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
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
            Container(color: AppTheme.cardColor(event.imageType)),
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              Image.network(
                event.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            else
              Center(
                child: Icon(
                  Icons.music_note_rounded,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
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

class _VenueTile extends StatelessWidget {
  final Venue venue;
  const _VenueTile({required this.venue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.cardColor(venue.imageType),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.nightlife_rounded,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(venue.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceColor,
                    )),
                Text(venue.neighborhood,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 12, color: AppTheme.mutedColor),
        ],
      ),
    );
  }
}

class _ArtistChip extends StatelessWidget {
  final String name;
  const _ArtistChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_rounded, size: 13, color: AppTheme.accentColor),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.onSurfaceColor,
            ),
          ),
        ],
      ),
    );
  }
}
