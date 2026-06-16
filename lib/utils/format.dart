import 'package:intl/intl.dart';

/// Shared display formatters. All money is Uganda Shillings (UGX); all datetimes
/// arrive as MySQL strings (`YYYY-MM-DD HH:MM:SS`) in Africa/Kampala time.

final NumberFormat _ugx = NumberFormat('#,##0', 'en_US');

String formatUgx(int amount) => 'UGX ${_ugx.format(amount)}';

/// Compact money for badges: 150000 → "UGX 150K", 1,200,000 → "UGX 1.2M".
String formatUgxShort(int amount) {
  if (amount >= 1000000) {
    final m = amount / 1000000;
    return 'UGX ${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)}M';
  }
  if (amount >= 1000) return 'UGX ${(amount / 1000).toStringAsFixed(0)}K';
  return 'UGX $amount';
}

/// Parse a MySQL or ISO datetime string; returns null on failure.
DateTime? parseDateTime(String? s) {
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

/// "Sat, 12 Jul 2026" from a YYYY-MM-DD (or datetime) string.
String formatDate(String? s) {
  final dt = parseDateTime(s);
  if (dt == null) return s ?? '';
  return DateFormat('EEE, d MMM yyyy').format(dt);
}

/// "Sat, 12 Jul · 8:30 PM" from a full datetime string.
String formatDateTimeShort(String? s) {
  final dt = parseDateTime(s);
  if (dt == null) return s ?? '';
  return DateFormat('EEE, d MMM · h:mm a').format(dt);
}

/// "8:30 PM" from an HH:MM:SS string.
String formatTime(String? t) {
  if (t == null || t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length < 2) return t;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final dt = DateTime(2000, 1, 1, h, m);
  return DateFormat('h:mm a').format(dt);
}

/// "3m ago" / "2h ago" / "5d ago" relative to now.
String timeAgo(String? s) {
  final dt = parseDateTime(s);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDate(s);
}
