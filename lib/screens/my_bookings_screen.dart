import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/format.dart';
import '../widgets/widgets.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<Booking> _bookings = [];
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
      final result = await ApiService().fetchBookings();
      if (!mounted) return;
      setState(() { _bookings = result.data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Could not load your tickets.';
      });
    }
  }

  Future<void> _cancel(Booking b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Cancel booking?'),
        content: Text('Cancel ${b.quantity} ${b.quantity == 1 ? 'ticket' : 'tickets'} for ${b.eventTitle ?? 'this event'}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel booking', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().cancelBooking(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Booking cancelled'), behavior: SnackBarBehavior.floating));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException ? e.message : 'Could not cancel booking'),
        behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('My Tickets')),
      body: !auth.isAuthenticated
          ? EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              message: 'Sign in to view and manage your tickets.',
              actionLabel: 'Sign In',
              onAction: () => context.push('/auth', extra: {'signup': false}),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _error != null
                  ? VibeErrorWidget(message: _error!, onRetry: _load)
                  : _bookings.isEmpty
                      ? EmptyState(
                          icon: Icons.confirmation_number_outlined,
                          title: 'No tickets yet',
                          message: 'Browse events and grab tickets to see them here.',
                          actionLabel: 'Discover Events',
                          onAction: () => context.go('/discover'),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primaryColor,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _bookings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _BookingCard(
                              booking: _bookings[i],
                              onCancel: () => _cancel(_bookings[i]),
                            ),
                          ),
                        ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onCancel;
  const _BookingCard({required this.booking, required this.onCancel});

  @override
  Widget build(BuildContext context) {
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
                child: Text(booking.eventTitle ?? 'Event',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurfaceColor),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              _StatusChip(status: booking.status),
            ],
          ),
          const SizedBox(height: 6),
          if (booking.venueName != null)
            _line(Icons.location_on_outlined, booking.venueName!),
          if (booking.eventDate != null)
            _line(Icons.calendar_today_rounded, formatDate(booking.eventDate)),
          _line(Icons.confirmation_number_outlined,
              '${booking.ticketTypeName ?? 'Ticket'} × ${booking.quantity}'),
          _line(Icons.tag_rounded, booking.bookingCode),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                booking.isFree ? 'Free' : formatUgx(booking.totalUgx),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
              ),
              const Spacer(),
              if (booking.isCancellable)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.mutedColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, color: AppTheme.mutedColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final BookingStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      BookingStatus.issued => ('Issued', const Color(0xFF00E676)),
      BookingStatus.paid => ('Paid', const Color(0xFF00E676)),
      BookingStatus.pending => ('Pending', const Color(0xFFFFB300)),
      BookingStatus.cancelled => ('Cancelled', AppTheme.mutedColor),
      BookingStatus.refunded => ('Refunded', AppTheme.accentColor),
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
