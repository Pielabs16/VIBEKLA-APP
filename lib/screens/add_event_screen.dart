import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class AddEventScreen extends StatefulWidget {
  final String venueId;
  final String venueName;

  const AddEventScreen({
    super.key,
    required this.venueId,
    required this.venueName,
  });

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _artistsController = TextEditingController();
  final _ticketUrlController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _capacityController = TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;
  String _genre = 'Afrobeats';
  bool _isFree = true;
  bool _submitting = false;

  static const _genres = [
    'Afrobeats', 'House', 'R&B', 'Reggae', 'Amapiano',
    'Hip-Hop', 'Dancehall', 'Jazz', 'EDM', 'Latin',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _artistsController.dispose();
    _ticketUrlController.dispose();
    _entryFeeController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? now : (_startTime ?? now),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primaryColor,
            surface: AppTheme.surfaceColor,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 22, minute: 0),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primaryColor,
            surface: AppTheme.surfaceColor,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final result = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = result;
      } else {
        _endTime = result;
      }
    });
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and start time are required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final fee = _isFree
          ? 0
          : int.tryParse(_entryFeeController.text.replaceAll(',', '')) ?? 0;

      await ApiService().createEvent({
        'venueId': widget.venueId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'genre': _genre,
        'startTime': _startTime!.toIso8601String(),
        if (_endTime != null) 'endTime': _endTime!.toIso8601String(),
        'artists': _artistsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'entryFee': fee,
        if (_ticketUrlController.text.trim().isNotEmpty)
          'ticketUrl': _ticketUrlController.text.trim(),
        if (_capacityController.text.trim().isNotEmpty)
          'capacity': int.tryParse(_capacityController.text.trim()),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event submitted for review! 🎉'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, d MMM · h:mm a');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AppTheme.onSurfaceColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Add Event',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurfaceColor)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryColor),
                  )
                : const Text('Post',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Venue badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('🏟️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    widget.venueName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const _Label('Event Title *'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                  fontSize: 15, color: AppTheme.onSurfaceColor),
              decoration:
                  const InputDecoration(hintText: 'e.g. Saturday Night Fever'),
            ),
            const SizedBox(height: 18),

            const _Label('Description'),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              maxLength: 400,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.onSurfaceColor),
              decoration: const InputDecoration(
                  hintText: 'Tell people what to expect…'),
            ),
            const SizedBox(height: 6),

            const _Label('Genre'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _genres.map((g) {
                final sel = _genre == g;
                return GestureDetector(
                  onTap: () => setState(() => _genre = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primaryColor : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      g,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? Colors.white
                            : AppTheme.onSurfaceColor
                                .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            const _Label('Artists / DJs (comma-separated)'),
            const SizedBox(height: 8),
            TextField(
              controller: _artistsController,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.onSurfaceColor),
              decoration: const InputDecoration(
                  hintText: 'DJ Spinall, Burna Boy…'),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _DateTimeButton(
                    label: 'Start Time *',
                    value:
                        _startTime != null ? fmt.format(_startTime!) : null,
                    onTap: () => _pickDateTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTimeButton(
                    label: 'End Time',
                    value: _endTime != null ? fmt.format(_endTime!) : null,
                    onTap: () => _pickDateTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            const _Label('Entry Fee'),
            const SizedBox(height: 10),
            Row(
              children: [
                _Chip(
                    label: 'Free',
                    selected: _isFree,
                    onTap: () => setState(() => _isFree = true)),
                const SizedBox(width: 10),
                _Chip(
                    label: 'Paid',
                    selected: !_isFree,
                    onTap: () => setState(() => _isFree = false)),
              ],
            ),
            if (!_isFree) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _entryFeeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.onSurfaceColor),
                decoration: const InputDecoration(
                  hintText: 'Amount in UGX',
                  prefixText: 'UGX ',
                  prefixStyle: TextStyle(
                      color: AppTheme.mutedColor, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ticketUrlController,
                keyboardType: TextInputType.url,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.onSurfaceColor),
                decoration: const InputDecoration(
                    hintText: 'Ticket link (optional)'),
              ),
            ],
            const SizedBox(height: 18),

            const _Label('Capacity (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.onSurfaceColor),
              decoration:
                  const InputDecoration(hintText: 'Max attendees'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.mutedColor,
          letterSpacing: 0.5,
        ),
      );
}

class _DateTimeButton extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateTimeButton(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.mutedColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(
              value ?? 'Tap to set',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: value != null
                    ? AppTheme.primaryColor
                    : AppTheme.mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color:
                selected ? Colors.white : AppTheme.onSurfaceColor.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
