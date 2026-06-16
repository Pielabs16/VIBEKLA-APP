import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/data_provider.dart';
import '../providers/content_provider.dart';
import '../models/models.dart';
import '../config/theme.dart';
import '../widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedGenre;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text.trim()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().fetchAll();
      context.read<ContentProvider>().fetchContent();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer<DataProvider>(
        builder: (context, data, _) {
          final isSearching = _searchQuery.isNotEmpty;
          final searchResults = isSearching
              ? data.venues
                  .where((v) => v.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                  .toList()
              : <Venue>[];

          if (data.hasVenueError) {
            return Column(
              children: [
                const _HomeHeader(),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.primaryColor,
                    backgroundColor: AppTheme.surfaceColor,
                    onRefresh: () => data.fetchAll(refresh: true),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - kToolbarHeight,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.mutedColor),
                                const SizedBox(height: 16),
                                Text(
                                  data.error ?? 'Could not load data.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                GestureDetector(
                                  onTap: () => data.fetchAll(refresh: true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(12)),
                                    child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              const _HomeHeader(),
              Expanded(child: RefreshIndicator(
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.surfaceColor,
            onRefresh: () => data.fetchAll(refresh: true),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _VenueSearchBar(controller: _searchController)),
                if (data.error != null && data.venues.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 14, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(data.error!, style: const TextStyle(fontSize: 12, color: Colors.orange))),
                          GestureDetector(
                            onTap: () => data.clearError(),
                            child: const Icon(Icons.close_rounded, size: 14, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isSearching)
                  SliverToBoxAdapter(child: _SearchResults(venues: searchResults, query: _searchQuery))
                else ...[
                  const SliverToBoxAdapter(child: _BannersSection()),
                  SliverToBoxAdapter(child: _FeaturedSection(data: data)),
                  SliverToBoxAdapter(
                    child: _CategoriesRow(
                      selectedGenre: _selectedGenre,
                      onSelected: (g) => setState(() => _selectedGenre = g),
                    ),
                  ),
                  SliverToBoxAdapter(child: _HotVenuesSection(data: data)),
                  SliverToBoxAdapter(
                    child: _UpcomingEventsSection(data: data, selectedGenre: _selectedGenre),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          )),
            ],
          );
        },
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.backgroundColor : AppTheme.lightBg;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppTheme.lightBorder.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'VibeKLA',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _showRegionSearch(context),
            child: Consumer<ContentProvider>(
              builder: (context, content, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceColor : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppTheme.lightBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 13, color: AppTheme.primaryColor),
                      const SizedBox(width: 5),
                      Text(
                        content.selectedRegion,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.onSurfaceColor : AppTheme.lightOnSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: isDark ? AppTheme.mutedColor : AppTheme.lightMuted,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRegionSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RegionSearchSheet(contentProvider: context.read<ContentProvider>()),
    );
  }
}

class _RegionSearchSheet extends StatefulWidget {
  final ContentProvider contentProvider;
  const _RegionSearchSheet({required this.contentProvider});

  @override
  State<_RegionSearchSheet> createState() => _RegionSearchSheetState();
}

class _RegionSearchSheetState extends State<_RegionSearchSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF130030) : Colors.white;
    final border = isDark ? AppTheme.borderColor : AppTheme.lightBorder;

    final all = widget.contentProvider.allRegions;
    final filtered = _query.isEmpty
        ? all
        : all.where((r) => r.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: border, width: 1)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Region',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find venues in your area',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.onSurfaceColor : AppTheme.lightOnSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search city or neighborhood…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.mutedColor),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () { _ctrl.clear(); setState(() => _query = ''); },
                              child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.mutedColor),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No results', style: Theme.of(context).textTheme.bodySmall),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final region = filtered[i];
                        final selected = widget.contentProvider.selectedRegion == region;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: selected ? AppTheme.primaryColor : AppTheme.mutedColor,
                          ),
                          title: Text(
                            region,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              color: selected
                                  ? AppTheme.primaryColor
                                  : (isDark ? AppTheme.onSurfaceColor : AppTheme.lightOnSurface),
                            ),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_rounded, size: 16, color: AppTheme.primaryColor)
                              : null,
                          onTap: () {
                            widget.contentProvider.setRegion(region);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedSection extends StatelessWidget {
  final DataProvider data;
  const _FeaturedSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: VibeSectionHeader(
            title: 'Tonight in Kampala',
            subtitle: 'Featured events',
            onSeeAll: () => context.go('/discover'),
          ),
        ),
        const SizedBox(height: 12),
        if (data.isLoading)
          const _FeaturedShimmer()
        else if (data.events.isEmpty)
          _EmptyFeatured()
        else
          SizedBox(
            height: 360,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: data.events.length.clamp(0, 8),
              itemBuilder: (context, index) {
                final event = data.events[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: FeaturedEventCard(
                    event: event,
                    venue: data.getVenueById(event.venueId),
                    onTap: () => context.push('/event/${event.id}'),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CategoriesRow extends StatelessWidget {
  final String? selectedGenre;
  final ValueChanged<String?> onSelected;
  const _CategoriesRow({required this.selectedGenre, required this.onSelected});

  static const _genreIcons = [
    Icons.music_note_rounded,
    Icons.piano_rounded,
    Icons.headphones_rounded,
    Icons.graphic_eq_rounded,
    Icons.album_rounded,
    Icons.queue_music_rounded,
    Icons.mic_rounded,
    Icons.speaker_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, content, _) {
        final genres = content.genres;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Genres', style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: genres.length + 1,
                itemBuilder: (context, i) {
                  final isAll = i == 0;
                  final label = isAll ? 'All' : genres[i - 1];
                  final icon = isAll ? Icons.apps_rounded : _genreIcons[(i - 1) % _genreIcons.length];
                  final sel = isAll ? selectedGenre == null : selectedGenre == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onSelected(isAll ? null : label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primaryColor : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: sel ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 13, color: sel ? Colors.white : const Color(0xFF999999)),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : const Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HotVenuesSection extends StatelessWidget {
  final DataProvider data;
  const _HotVenuesSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: VibeSectionHeader(
            title: 'Hot Venues',
            subtitle: 'Highest vibe score',
            onSeeAll: () => context.go('/discover'),
          ),
        ),
        const SizedBox(height: 12),
        if (data.isLoading)
          const _VenueShimmer()
        else if (data.venues.isEmpty)
          const SizedBox.shrink()
        else
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: data.venues.length.clamp(0, 8),
              itemBuilder: (context, index) {
                final venue = data.venues[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: VenueMiniCard(venue: venue, onTap: () => context.push('/venue/${venue.id}')),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _UpcomingEventsSection extends StatelessWidget {
  final DataProvider data;
  final String? selectedGenre;
  const _UpcomingEventsSection({required this.data, this.selectedGenre});

  @override
  Widget build(BuildContext context) {
    final events = selectedGenre == null
        ? data.events
        : data.events.where((e) => e.genre.toLowerCase() == selectedGenre!.toLowerCase()).toList();
    if (!data.isLoading && events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: VibeSectionHeader(
            title: selectedGenre != null ? '$selectedGenre Events' : 'Upcoming Events',
            subtitle: "Don't miss out",
            onSeeAll: () => context.go('/discover'),
          ),
        ),
        const SizedBox(height: 12),
        if (data.isLoading)
          const LoadingShimmer(count: 3)
        else
          ...events.take(5).map(
            (event) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: EventCard(event: event, venue: data.getVenueById(event.venueId), onTap: () => context.push('/event/${event.id}')),
            ),
          ),
      ],
    );
  }
}

class _BannersSection extends StatelessWidget {
  const _BannersSection();

  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, content, _) {
        final banners = content.banners;
        if (banners.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: banners.length,
              itemBuilder: (context, i) {
                final banner = banners[i];
                final bg = _parseColor(banner.bgColor);
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 260,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(banner.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (banner.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(banner.subtitle,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _VenueSearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _VenueSearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.onSurfaceColor, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search venues by name…',
            hintStyle: const TextStyle(color: AppTheme.mutedColor, fontSize: 15),
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.mutedColor, size: 20),
            suffixIcon: controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: () => controller.clear(),
                    child: const Icon(Icons.close_rounded, color: AppTheme.mutedColor, size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<Venue> venues;
  final String query;
  const _SearchResults({required this.venues, required this.query});

  @override
  Widget build(BuildContext context) {
    if (venues.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 40, color: AppTheme.mutedColor),
            const SizedBox(height: 12),
            Text('No venues found for "$query"',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(
            '${venues.length} venue${venues.length == 1 ? '' : 's'} found',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor),
          ),
        ),
        ...venues.map(
          (venue) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: VenueCard(venue: venue, onTap: () => context.push('/venue/${venue.id}')),
          ),
        ),
      ],
    );
  }
}

class _FeaturedShimmer extends StatelessWidget {
  const _FeaturedShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(right: 14),
          child: ShimmerBox(width: 280, height: 360, radius: 18),
        ),
      ),
    );
  }
}

class _VenueShimmer extends StatelessWidget {
  const _VenueShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 4,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(right: 12),
          child: ShimmerBox(width: 140, height: 160, radius: 18),
        ),
      ),
    );
  }
}

class _EmptyFeatured extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_available_rounded, size: 32, color: AppTheme.accentColor),
            const SizedBox(height: 8),
            Text('No events tonight', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
