import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../providers/content_provider.dart';
import '../widgets/widgets.dart';
import '../config/theme.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedFilter = 'All';

  // Server-side search results (null means use DataProvider cache)
  List<dynamic>? _searchResults;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() { _selectedFilter = 'All'; _searchResults = null; });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataProvider>().fetchAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final data = context.read<DataProvider>();
    final isEvents = _tabController.index == 0;
    final filter = _selectedFilter == 'All' ? null : _selectedFilter;
    final q = _query;

    if (q.isEmpty && filter == null) {
      setState(() { _searchResults = null; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      if (isEvents) {
        final results = await data.searchEvents(q, genre: filter);
        if (mounted) setState(() { _searchResults = results; _searching = false; });
      } else {
        final results = await data.searchVenues(q, category: filter);
        if (mounted) setState(() { _searchResults = results; _searching = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _DiscoverHeader(
              tabController: _tabController,
              searchController: _searchController,
              onSearch: (q) {
                setState(() { _query = q; _searchResults = null; });
                if (q.isNotEmpty || _selectedFilter != 'All') _runSearch();
              },
            ),
            Consumer<ContentProvider>(
              builder: (context, content, _) {
                final filters = _tabController.index == 0
                    ? ['All', ...content.genres]
                    : ['All', ...content.venueCategories];
                return _FilterRow(
                  filters: filters,
                  selected: _selectedFilter,
                  onSelect: (f) {
                    setState(() { _selectedFilter = f; _searchResults = null; });
                    _runSearch();
                  },
                );
              },
            ),
            Expanded(
              child: Consumer<DataProvider>(
                builder: (context, data, _) {
                  if (data.isLoading || _searching) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: 5,
                      itemBuilder: (_, __) => const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: ShimmerBox(width: double.infinity, height: 80, radius: 18),
                      ),
                    );
                  }
                  if (data.error != null && _searchResults == null) {
                    return VibeErrorWidget(message: data.error!, onRetry: () => data.fetchAll());
                  }
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _EventsList(
                        data: data,
                        serverResults: _searchResults?.whereType<dynamic>().toList(),
                        query: _query,
                        filter: _selectedFilter,
                      ),
                      _VenuesList(
                        data: data,
                        serverResults: _searchResults?.whereType<dynamic>().toList(),
                        query: _query,
                        filter: _selectedFilter,
                      ),
                    ],
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

class _DiscoverHeader extends StatelessWidget {
  final TabController tabController;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  const _DiscoverHeader({
    required this.tabController,
    required this.searchController,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Discover', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text('Find events & venues in Kampala', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: onSearch,
            style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceColor),
            decoration: InputDecoration(
              hintText: 'Search events, venues…',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.mutedColor, size: 20),
              suffixIcon: searchController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () { searchController.clear(); onSearch(''); },
                      child: const Icon(Icons.close_rounded, color: AppTheme.mutedColor, size: 18),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: tabController,
              labelPadding: EdgeInsets.zero,
              indicator: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.mutedColor,
              tabs: const [Tab(text: 'Events'), Tab(text: 'Venues')],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterRow({required this.filters, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: filters.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: VibeFilterChip(
            label: filters[i],
            selected: selected == filters[i],
            onSelected: () => onSelect(filters[i]),
          ),
        ),
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  final DataProvider data;
  final List<dynamic>? serverResults; // non-null = server already filtered
  final String query;
  final String filter;
  const _EventsList(
      {required this.data,
      this.serverResults,
      required this.query,
      required this.filter});

  @override
  Widget build(BuildContext context) {
    List<Event> events;
    if (serverResults != null) {
      events = serverResults!.whereType<Event>().toList();
    } else {
      events = data.events;
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        events = events
            .where((e) =>
                e.title.toLowerCase().contains(q) ||
                e.genre.toLowerCase().contains(q) ||
                e.artists.any((a) => a.toLowerCase().contains(q)))
            .toList();
      }
      if (filter != 'All') {
        events = events
            .where((e) => e.genre.toLowerCase() == filter.toLowerCase())
            .toList();
      }
    }
    if (events.isEmpty) {
      return _EmptyState(
        icon: Icons.event_busy_rounded,
        message: query.isNotEmpty ? 'No events match "$query"' : 'No events found',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: EventCard(
            event: event,
            venue: data.getVenueById(event.venueId),
            onTap: () => context.push('/event/${event.id}'),
          ),
        );
      },
    );
  }
}

class _VenuesList extends StatelessWidget {
  final DataProvider data;
  final List<dynamic>? serverResults;
  final String query;
  final String filter;
  const _VenuesList(
      {required this.data,
      this.serverResults,
      required this.query,
      required this.filter});

  @override
  Widget build(BuildContext context) {
    List<Venue> venues;
    if (serverResults != null) {
      venues = serverResults!.whereType<Venue>().toList();
    } else {
      venues = data.venues;
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        venues = venues
            .where((v) =>
                v.name.toLowerCase().contains(q) ||
                v.category.toLowerCase().contains(q) ||
                v.neighborhood.toLowerCase().contains(q))
            .toList();
      }
      if (filter != 'All') {
        venues = venues
            .where((v) => v.category.toLowerCase() == filter.toLowerCase())
            .toList();
      }
    }
    if (venues.isEmpty) {
      return _EmptyState(
        icon: Icons.storefront_rounded,
        message: query.isNotEmpty ? 'No venues match "$query"' : 'No venues found',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      itemCount: venues.length,
      itemBuilder: (context, index) => VenueCard(
        venue: venues[index],
        onTap: () => context.push('/venue/${venues[index].id}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: AppTheme.surfaceColor, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: AppTheme.mutedColor),
          ),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
