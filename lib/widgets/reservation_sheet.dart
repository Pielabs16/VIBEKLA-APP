import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// Opens the table reservation sheet for [venue]. Returns true if a reservation
/// was created. Pass [event] to tie the reservation to a specific event.
Future<bool?> showReservationSheet(BuildContext context, Venue venue, {Event? event}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ReservationSheet(venue: venue, event: event),
  );
}

class _ReservationSheet extends StatefulWidget {
  final Venue venue;
  final Event? event;
  const _ReservationSheet({required this.venue, this.event});

  @override
  State<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<_ReservationSheet> {
  DateTime _when = DateTime.now().add(const Duration(hours: 2));
  int _partySize = 2;
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  Reservation? _created;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _when.isBefore(now) ? now : _when,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!),
    );
    if (date == null) return;
    setState(() => _when = DateTime(date.year, date.month, date.day, _when.hour, _when.minute));
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;
    setState(() => _when = DateTime(_when.year, _when.month, _when.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.of(context).pop(false);
      context.push('/auth', extra: {'signup': false});
      return;
    }
    if (_when.isBefore(DateTime.now())) {
      setState(() => _error = 'Pick a future date and time.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final reservation = await ApiService().createReservation(
        venueId: widget.venue.id,
        reservedFor: DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(_when),
        partySize: _partySize,
        eventId: widget.event?.id,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() { _created = reservation; _submitting = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _submitting = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Could not create reservation. Check your connection.'; _submitting = false; });
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
        child: SafeArea(top: false, child: _created != null ? _success(_created!) : _form()),
      ),
    );
  }

  Widget _grabber() => Container(
        width: 36, height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
      );

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: _grabber()),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reserve a Table', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(widget.event != null ? '${widget.venue.name} · ${widget.event!.title}' : widget.venue.name,
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
                Row(
                  children: [
                    Expanded(child: _pickerTile(Icons.calendar_today_rounded, 'Date',
                        DateFormat('EEE, d MMM').format(_when), _pickDate)),
                    const SizedBox(width: 12),
                    Expanded(child: _pickerTile(Icons.schedule_rounded, 'Time',
                        DateFormat('h:mm a').format(_when), _pickTime)),
                  ],
                ),
                const SizedBox(height: 16),
                _partySizeRow(),
                const SizedBox(height: 16),
                const Text('Notes (optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceColor)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  maxLength: 200,
                  style: const TextStyle(color: AppTheme.onSurfaceColor, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Birthday, seating preference, etc.',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Container(
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
                        Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: Colors.redAccent))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.borderColor))),
          child: GestureDetector(
            onTap: _submitting ? null : _submit,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: _submitting ? const Color(0xFF2a2a2a) : AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Request Reservation',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pickerTile(IconData icon, String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.mutedColor)),
                  Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partySizeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Party size',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceColor)),
        Row(
          children: [
            _stepBtn(Icons.remove_rounded, _partySize > 1 ? () => setState(() => _partySize--) : null),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text('$_partySize',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.onSurfaceColor)),
            ),
            _stepBtn(Icons.add_rounded, _partySize < 100 ? () => setState(() => _partySize++) : null),
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
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.primaryColor.withValues(alpha: 0.15) : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(icon, size: 18, color: enabled ? AppTheme.primaryColor : AppTheme.mutedColor),
      ),
    );
  }

  Widget _success(Reservation r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: _grabber()),
          const SizedBox(height: 14),
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A4A2E)),
            child: const Icon(Icons.event_available_rounded, size: 38, color: Color(0xFF68D391)),
          ),
          const SizedBox(height: 18),
          Text('Reservation Requested', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Your table at ${widget.venue.name} (${r.reservationCode}) is requested. The venue will confirm shortly — track it under My Reservations.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                context.push('/reservations');
              },
              child: const Text('View My Reservations'),
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
