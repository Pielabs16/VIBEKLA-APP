import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/content_provider.dart';
import '../services/api_service.dart';

/// Apply to list a venue. POST /api/apply → creates a pending venue_application;
/// on admin approval the applicant is promoted to venue_owner.
class VenueApplicationScreen extends StatefulWidget {
  const VenueApplicationScreen({super.key});

  @override
  State<VenueApplicationScreen> createState() => _VenueApplicationScreenState();
}

class _VenueApplicationScreenState extends State<VenueApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _instagram = TextEditingController();
  String? _category;
  String? _neighborhood;

  bool _submitting = false;
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _email.text = context.read<AuthProvider>().userEmail ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _instagram.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_category == null || _neighborhood == null) {
      setState(() => _error = 'Please choose a category and neighborhood.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService().submitApplication({
        'venueName': _name.text.trim(),
        'category': _category,
        'neighborhood': _neighborhood,
        'address': _address.text.trim(),
        'description': _description.text.trim(),
        'contactPhone': _phone.text.trim(),
        'contactEmail': _email.text.trim(),
        if (_instagram.text.trim().isNotEmpty) 'instagramHandle': _instagram.text.trim(),
      });
      if (!mounted) return;
      setState(() { _done = true; _submitting = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _submitting = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Could not submit application. Check your connection.'; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    final categories = content.venueCategories;
    final neighborhoods = content.neighborhoods.isNotEmpty
        ? content.neighborhoods
        : const ['Kampala'];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('List Your Venue')),
      body: _done ? _successView() : _formView(categories, neighborhoods),
    );
  }

  Widget _formView(List<String> categories, List<String> neighborhoods) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Tell us about your venue. Our team reviews applications within 2–3 business days, then you can manage your listing.',
              style: TextStyle(fontSize: 14, color: AppTheme.mutedColor, height: 1.5),
            ),
            const SizedBox(height: 20),
            _label('Venue name'),
            _field(_name, hint: 'e.g. Guvnor', validator: _required),
            _label('Category'),
            _dropdown(
              value: _category,
              items: categories,
              hint: 'Select category',
              onChanged: (v) => setState(() => _category = v),
            ),
            _label('Neighborhood'),
            _dropdown(
              value: _neighborhood,
              items: neighborhoods,
              hint: 'Select neighborhood',
              onChanged: (v) => setState(() => _neighborhood = v),
            ),
            _label('Address'),
            _field(_address, hint: 'Street / area', validator: _required),
            _label('Description'),
            _field(_description, hint: 'What makes your venue special?', maxLines: 3, validator: _required),
            _label('Contact phone'),
            _field(_phone, hint: '+256 7XX XXX XXX', keyboard: TextInputType.phone, validator: _required),
            _label('Contact email'),
            _field(_email, hint: 'you@example.com', keyboard: TextInputType.emailAddress, validator: _emailValidator),
            _label('Instagram (optional)'),
            _field(_instagram, hint: '@yourvenue'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              _errorBanner(_error!),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Submit Application', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A4A2E)),
              child: const Icon(Icons.check_rounded, size: 44, color: Color(0xFF68D391)),
            ),
            const SizedBox(height: 22),
            Text('Application Submitted', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            const Text(
              'Thanks! Our team will review your venue within 2–3 business days. You\'ll be notified once it\'s approved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.mutedColor, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Field helpers ────────────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceColor)),
      );

  Widget _field(TextEditingController c,
      {String? hint, int maxLines = 1, TextInputType? keyboard, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(color: AppTheme.onSurfaceColor, fontSize: 14),
      decoration: InputDecoration(hintText: hint),
    );
  }

  Widget _dropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: AppTheme.surfaceColor,
      hint: Text(hint, style: const TextStyle(color: AppTheme.mutedColor, fontSize: 14)),
      style: const TextStyle(color: AppTheme.onSurfaceColor, fontSize: 14),
      decoration: const InputDecoration(),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
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

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email';
  }
}
