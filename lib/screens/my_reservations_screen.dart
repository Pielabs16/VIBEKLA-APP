import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/format.dart';
import '../widgets/widgets.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  List<Reservation> _reservations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!context.read<AuthProvider>().isAuthenticated) {
      setState(() { _loading = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ApiService().fetchReservations();
      if (!mounted) return;
      setState(() { _reservations = result.data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load your reservations.';
      });
    }
  }

  Future<void> _cancel(Reservation r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Cancel reservation?'),
        content: Text('Cancel your table for ${r.partySize} at ${r.venueName ?? 'this venue'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel reservation', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().updateReservation(r.id, {'status': 'cancelled'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reservation cancelled'), behavior: SnackBarBehavior.floating));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.message : 'Could not cancel reservation'),
        behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('My Reservations')),
      body: !auth.isAuthenticated
          ? EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              message: 'Sign in to view and manage your table reservations.',
              actionLabel: 'Sign In',
              onAction: () => context.push('/auth', extra: {'signup': false}),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _error != null
                  ? VibeErrorWidget(message: _error!, onRetry: _load)
                  : _reservations.isEmpty
                      ? EmptyState(
                          icon: Icons.event_seat_outlined,
                          title: 'No reservations',
                          message: 'Reserve a table at your favourite venue to see it here.',
                          actionLabel: 'Explore Venues',
                          onAction: () => context.go('/discover'),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primaryColor,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _reservations.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _ReservationCard(
                              reservation: _reservations[i],
                              onCancel: () => _cancel(_reservations[i]),
                            ),
                          ),
                        ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback onCancel;
  const _ReservationCard({required this.reservation, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.venueName ?? 'Venue',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurfaceColor),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              _ReservationStatusChip(status: r.status),
            ],
          ),
          const SizedBox(height: 6),
          _line(Icons.schedule_rounded, formatDateTimeShort(r.reservedFor)),
          _line(Icons.group_rounded, '${r.partySize} ${r.partySize == 1 ? 'guest' : 'guests'}'),
          if (r.eventTitle != null) _line(Icons.celebration_outlined, r.eventTitle!),
          _line(Icons.tag_rounded, r.reservationCode),
          if (r.depositUgx > 0) _line(Icons.payments_outlined, 'Deposit ${formatUgx(r.depositUgx)}'),
          if ((r.notes ?? '').isNotEmpty) _line(Icons.notes_rounded, r.notes!),
          if (r.isCancellable) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 14, color: AppTheme.mutedColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, color: AppTheme.mutedColor)),
            ),
          ],
        ),
      );
}

class _ReservationStatusChip extends StatelessWidget {
  final ReservationStatus status;
  const _ReservationStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ReservationStatus.confirmed => ('Confirmed', const Color(0xFF00E676)),
      ReservationStatus.seated => ('Seated', const Color(0xFF00E676)),
      ReservationStatus.requested => ('Requested', const Color(0xFFFFB300)),
      ReservationStatus.cancelled => ('Cancelled', AppTheme.mutedColor),
      ReservationStatus.noShow => ('No-show', Colors.redAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
