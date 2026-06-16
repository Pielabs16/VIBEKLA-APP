import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/format.dart';

/// Opens the ticket booking sheet for [event]. Returns true if a booking was created.
/// Requires the event to carry ticketTypes (fetched from GET /api/events/{id}).
Future<bool?> showTicketBookingSheet(BuildContext context, Event event) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _TicketBookingSheet(event: event),
  );
}

class _TicketBookingSheet extends StatefulWidget {
  final Event event;
  const _TicketBookingSheet({required this.event});

  @override
  State<_TicketBookingSheet> createState() => _TicketBookingSheetState();
}

class _TicketBookingSheetState extends State<_TicketBookingSheet> {
  TicketType? _selected;
  int _qty = 1;
  bool _submitting = false;
  String? _error;
  Booking? _booking;

  @override
  void initState() {
    super.initState();
    final available = widget.event.ticketTypes.where((t) => t.available > 0).toList();
    _selected = available.isNotEmpty
        ? available.first
        : (widget.event.ticketTypes.isNotEmpty ? widget.event.ticketTypes.first : null);
  }

  int get _maxQty {
    final avail = _selected?.available ?? 1;
    return avail.clamp(1, 20);
  }

  int get _total => (_selected?.priceUgx ?? 0) * _qty;

  Future<void> _confirm() async {
    final sel = _selected;
    if (sel == null) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.of(context).pop(false);
      context.push('/auth', extra: {'signup': false});
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final booking = await ApiService().createBooking(
        eventId: widget.event.id,
        ticketTypeId: sel.id,
        quantity: _qty,
      );
      if (!mounted) return;
      setState(() { _booking = booking; _submitting = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _submitting = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Could not complete booking. Check your connection.'; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: _booking != null ? _success(_booking!) : _form(),
        ),
      ),
    );
  }

  Widget _grabber() => Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _form() {
    final types = widget.event.ticketTypes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: _grabber()),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Get Tickets', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(widget.event.title,
                  style: const TextStyle(fontSize: 13, color: AppTheme.mutedColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...types.map((t) => _ticketTile(t)),
                const SizedBox(height: 16),
                _qtyStepper(),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _errorBanner(_error!),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        _bottomBar(),
      ],
    );
  }

  Widget _ticketTile(TicketType t) {
    final selected = _selected?.id == t.id;
    final soldOut = t.available <= 0;
    return GestureDetector(
      onTap: soldOut
          ? null
          : () => setState(() {
                _selected = t;
                if (_qty > _maxQty) _qty = _maxQty;
              }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 20,
              color: soldOut
                  ? AppTheme.mutedColor
                  : selected
                      ? AppTheme.primaryColor
                      : AppTheme.mutedColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: soldOut ? AppTheme.mutedColor : AppTheme.onSurfaceColor,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    soldOut
                        ? 'Sold out'
                        : t.quantityTotal == null
                            ? 'Available'
                            : '${t.available} left',
                    style: TextStyle(
                      fontSize: 12,
                      color: soldOut ? Colors.redAccent : AppTheme.mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              t.isFree ? 'Free' : formatUgx(t.priceUgx),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyStepper() {
    final disabled = _selected == null || _selected!.available <= 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Quantity',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceColor)),
        Row(
          children: [
            _stepBtn(Icons.remove_rounded, (_qty > 1 && !disabled) ? () => setState(() => _qty--) : null),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text('$_qty',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.onSurfaceColor)),
            ),
            _stepBtn(Icons.add_rounded, (_qty < _maxQty && !disabled) ? () => setState(() => _qty++) : null),
          ],
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.primaryColor.withValues(alpha: 0.15) : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(icon, size: 18, color: enabled ? AppTheme.primaryColor : AppTheme.mutedColor),
      ),
    );
  }

  Widget _errorBanner(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 12.5, color: Colors.redAccent))),
          ],
        ),
      );

  Widget _bottomBar() {
    final sel = _selected;
    final canBook = sel != null && sel.available > 0 && !_submitting;
    final label = sel == null
        ? 'Unavailable'
        : sel.isFree
            ? 'Reserve ${_qty == 1 ? 'ticket' : '$_qty tickets'}'
            : 'Pay ${formatUgx(_total)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: GestureDetector(
        onTap: canBook ? _confirm : null,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: canBook ? AppTheme.primaryColor : const Color(0xFF2a2a2a),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: _submitting
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: canBook ? Colors.white : AppTheme.mutedColor,
                    )),
          ),
        ),
      ),
    );
  }

  Widget _success(Booking b) {
    final paidPending = b.status == BookingStatus.pending && b.totalUgx > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: _grabber()),
          const SizedBox(height: 14),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (paidPending ? AppTheme.accentColor : const Color(0xFF1A4A2E)),
            ),
            child: Icon(
              paidPending ? Icons.hourglass_top_rounded : Icons.check_rounded,
              size: 40,
              color: paidPending ? Colors.white : const Color(0xFF68D391),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            paidPending ? 'Booking Reserved' : 'Ticket Confirmed!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            paidPending
                ? 'Booking ${b.bookingCode} is reserved. Complete payment of ${formatUgx(b.totalUgx)} to issue your ticket — track it under My Tickets.'
                : 'Booking ${b.bookingCode} for ${b.quantity} ${b.quantity == 1 ? 'ticket' : 'tickets'} is confirmed. Find it under My Tickets.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                context.push('/bookings');
              },
              child: const Text('View My Tickets'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
