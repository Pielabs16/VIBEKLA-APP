import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/content_provider.dart';
import '../services/api_service.dart';

class VibeRatingScreen extends StatefulWidget {
  final String entityId;
  final String entityType; // 'venue' or 'event'
  final String entityName;

  const VibeRatingScreen({
    super.key,
    required this.entityId,
    required this.entityType,
    required this.entityName,
  });

  @override
  State<VibeRatingScreen> createState() => _VibeRatingScreenState();
}

class _VibeRatingScreenState extends State<VibeRatingScreen>
    with SingleTickerProviderStateMixin {
  double _rating = 0;
  final Set<String> _selectedTags = {};
  final _commentController = TextEditingController();
  bool _submitting = false;
  late AnimationController _starAnim;


  @override
  void initState() {
    super.initState();
    _starAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _starAnim.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a star rating first')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to submit a rating')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService().submitRating(
        entityId: widget.entityId,
        entityType: widget.entityType,
        rating: _rating,
        vibeTags: _selectedTags.toList(),
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vibe rated! Thanks for the update ✨'),
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.onSurfaceColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Rate the Vibe',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurfaceColor)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.entityName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurfaceColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'How was the vibe tonight?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return GestureDetector(
                  onTap: () {
                    setState(() => _rating = (i + 1).toDouble());
                    _starAnim.forward(from: 0);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 1, end: 1.3).animate(
                        CurvedAnimation(
                            parent: _starAnim, curve: Curves.elasticOut),
                      ),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 44,
                        color: filled
                            ? const Color(0xFFFFB300)
                            : AppTheme.mutedColor,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _rating == 0
                  ? 'Tap a star'
                  : _rating <= 1
                      ? 'Dead Inside 💀'
                      : _rating <= 2
                          ? 'Not Great 😕'
                          : _rating <= 3
                              ? 'It Was Okay 😐'
                              : _rating <= 4
                                  ? 'Good Vibes ✨'
                                  : 'Absolute Fire 🔥',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _rating == 0
                    ? AppTheme.mutedColor
                    : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Tag the vibe',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedColor,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            Consumer<ContentProvider>(
              builder: (context, content, _) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: content.vibeTags.map((tag) {
                  final display = tag.display;
                  final selected = _selectedTags.contains(display);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedTags.remove(display);
                      } else {
                        _selectedTags.add(display);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
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
                        display,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : AppTheme.onSurfaceColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Leave a comment (optional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedColor,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 280,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.onSurfaceColor),
              decoration: const InputDecoration(
                hintText: 'Tell the community what it was like…',
              ),
            ),
            const SizedBox(height: 28),

            GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: _submitting ? const Color(0xFF333333) : AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Submit Rating',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
