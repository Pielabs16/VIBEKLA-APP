import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/data_provider.dart';
import '../config/theme.dart';
import '../widgets/widgets.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.onSurfaceColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('My Bookmarks',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurfaceColor)),
      ),
      body: Consumer2<BookmarksProvider, DataProvider>(
        builder: (context, bookmarks, data, _) {
          final venueIds = bookmarks.bookmarkedVenues.toList();
          final eventIds = bookmarks.bookmarkedEvents.toList();
          final venues = venueIds
              .map((id) => data.getVenueById(id))
              .whereType<Object>()
              .toList();
          final events = eventIds
              .map((id) => data.getEventById(id))
              .whereType<Object>()
              .toList();

          if (venues.isEmpty && events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border_rounded,
                      size: 56, color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(height: 16),
                  Text('No bookmarks yet',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Bookmark venues and events to find them here',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.mutedColor),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return ListView(
            children: [
              if (venues.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text('Venues (${venues.length})',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                ...venueIds.map((id) {
                  final v = data.getVenueById(id);
                  if (v == null) return const SizedBox.shrink();
                  return VenueCard(
                    venue: v,
                    onTap: () => context.push('/venue/${v.id}'),
                  );
                }),
              ],
              if (events.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text('Events (${events.length})',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                ...eventIds.map((id) {
                  final e = data.getEventById(id);
                  if (e == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: EventCard(
                      event: e,
                      venue: data.getVenueById(e.venueId),
                      onTap: () => context.push('/event/${e.id}'),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
