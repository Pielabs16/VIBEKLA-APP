import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/content_provider.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) =>
            auth.isAuthenticated ? _ProfileContent(auth: auth) : const _SignedOut(),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text('Profile', style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppTheme.surfaceColor : AppTheme.lightSurface2,
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.lightBorder,
                        width: 2,
                      ),
                    ),
                    child: const Icon(Icons.person_outline_rounded, size: 44, color: AppTheme.mutedColor),
                  ),
                  const SizedBox(height: 20),
                  Text('Not signed in', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to bookmark venues, check in\nand track events near you.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () => context.push('/auth', extra: {'signup': false}),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('Sign In',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push('/auth', extra: {'signup': true}),
                      child: const Text('Create Account'),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final AuthProvider auth;
  const _ProfileContent({required this.auth});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _ProfileHeader(auth: auth)),
        SliverToBoxAdapter(
          child: Consumer<BookmarksProvider>(
            builder: (context, bookmarks, _) => _StatsRow(auth: auth, bookmarks: bookmarks),
          ),
        ),
        SliverToBoxAdapter(child: _ProfileMenu(auth: auth)),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AuthProvider auth;
  const _ProfileHeader({required this.auth});

  @override
  Widget build(BuildContext context) {
    final displayName = auth.user?.displayName ?? auth.userEmail ?? 'User';
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final roleLabel = auth.isAdmin
        ? 'Admin'
        : auth.isVenueOwner
            ? 'Venue Owner'
            : 'Kampala Night Owl';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: isDark ? 0.08 : 0.05),
      ),
      child: Column(
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor),
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceColor),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.onSurfaceColor)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(displayName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(auth.userEmail ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.mutedColor, fontSize: 12)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Text(roleLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final AuthProvider auth;
  final BookmarksProvider bookmarks;
  const _StatsRow({required this.auth, required this.bookmarks});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.bookmark_rounded,
            value: '${bookmarks.totalBookmarks}',
            label: 'Bookmarks',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BookmarksScreen()),
            ),
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.check_circle_rounded,
            value: '${auth.checkInCount}',
            label: 'Check-ins',
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.calendar_month_rounded,
            value: '${auth.savedEventCount}',
            label: 'Events',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;
  const _StatCard({required this.icon, required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceColor : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.lightBorder,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  final AuthProvider auth;
  const _ProfileMenu({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (auth.canManageVenue) ...[
            _MenuSection(items: [
              _MenuItem(
                icon: Icons.store_rounded,
                label: 'My Venue Dashboard',
                trailing: _RoleBadge(auth.isAdmin ? 'Admin' : 'Owner'),
                onTap: () => context.push('/venue-owner'),
              ),
            ]),
            const SizedBox(height: 14),
          ] else ...[
            _MenuSection(items: [
              _MenuItem(
                icon: Icons.add_business_rounded,
                label: 'List Your Venue',
                onTap: () => context.push('/applications/new'),
              ),
            ]),
            const SizedBox(height: 14),
          ],

          const _SectionLabel('Activity'),
          const SizedBox(height: 8),
          _MenuSection(items: [
            _MenuItem(
              icon: Icons.confirmation_number_rounded,
              label: 'My Tickets',
              onTap: () => context.push('/bookings'),
            ),
            _MenuItem(
              icon: Icons.event_seat_rounded,
              label: 'My Reservations',
              onTap: () => context.push('/reservations'),
            ),
            _MenuItem(
              icon: Icons.bookmark_rounded,
              label: 'My Bookmarks',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BookmarksScreen()),
              ),
            ),
            _MenuItem(
              icon: Icons.calendar_month_rounded,
              label: 'Discover Events',
              onTap: () => context.go('/discover'),
            ),
          ]),
          const SizedBox(height: 14),

          const _SectionLabel('Support'),
          const SizedBox(height: 8),
          _MenuSection(items: [
            _MenuItem(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            _MenuItem(
              icon: Icons.headset_mic_rounded,
              label: 'Help & Support',
              onTap: () => _showHelp(context),
            ),
            _MenuItem(
              icon: Icons.info_outline_rounded,
              label: 'About VibeKLA',
              trailing: const _VersionBadge(),
              onTap: () => _showAbout(context),
            ),
          ]),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              await auth.signOut();
              if (context.mounted) context.go('/home');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Sign Out',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    final content = context.read<ContentProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HelpSheet(helpContacts: content.helpContacts),
    );
  }

  void _showAbout(BuildContext context) {
    final content = context.read<ContentProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AboutSheet(licenses: content.licenses),
    );
  }
}

class _HelpSheet extends StatelessWidget {
  final List<dynamic> helpContacts;
  const _HelpSheet({required this.helpContacts});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF130030) : Colors.white;

    // Fallback contacts if backend hasn't loaded yet
    final contacts = helpContacts.isNotEmpty
        ? helpContacts
        : [
            {'icon': 'email', 'label': 'Email Support', 'value': 'support@vibekla.com'},
            {'icon': 'instagram', 'label': 'Instagram', 'value': '@vibekla'},
            {'icon': 'web', 'label': 'Website', 'value': 'vibekla.com'},
          ];

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.75,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Help & Support', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('We\'re here to help', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: contacts.length,
                itemBuilder: (ctx, i) {
                  final c = contacts[i] as Map<String, dynamic>;
                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_contactIcon(c['icon'] as String? ?? ''),
                          size: 18, color: AppTheme.primaryColor),
                    ),
                    title: Text(c['label'] as String? ?? '',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(c['value'] as String? ?? '',
                        style: const TextStyle(fontSize: 13, color: AppTheme.primaryColor)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.mutedColor),
                    onTap: () => _launchContact(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchContact(BuildContext context, Map<String, dynamic> c) async {
    final type = c['icon'] as String? ?? '';
    final value = (c['value'] as String? ?? '').trim();
    if (value.isEmpty) return;

    Uri uri;
    LaunchMode mode = LaunchMode.externalApplication;

    if (type == 'email' || value.startsWith('mailto:')) {
      uri = Uri.parse(value.startsWith('mailto:') ? value : 'mailto:$value');
    } else if (type == 'phone') {
      uri = Uri.parse('tel:$value');
    } else if (type == 'whatsapp') {
      final digits = value.replaceAll('+', '').replaceAll(' ', '');
      uri = Uri.parse('https://wa.me/$digits');
    } else if (type == 'web' || value.startsWith('http')) {
      uri = Uri.parse(value.startsWith('http') ? value : 'https://$value');
    } else if (value.startsWith('+') || RegExp(r'^\d').hasMatch(value)) {
      uri = Uri.parse('tel:$value');
    } else {
      uri = Uri.parse('https://$value');
    }

    try {
      await launchUrl(uri, mode: mode);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $value')),
        );
      }
    }
  }

  IconData _contactIcon(String type) {
    switch (type) {
      case 'email':    return Icons.email_outlined;
      case 'phone':    return Icons.phone_outlined;
      case 'instagram': return Icons.camera_alt_outlined;
      case 'twitter':  return Icons.alternate_email_rounded;
      case 'web':      return Icons.language_rounded;
      case 'whatsapp': return Icons.message_outlined;
      default:         return Icons.contact_support_outlined;
    }
  }
}

class _AboutSheet extends StatelessWidget {
  final List<dynamic> licenses;
  const _AboutSheet({required this.licenses});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF130030) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.88,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.nightlife_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VibeKLA', style: Theme.of(context).textTheme.headlineSmall),
                      Text('v${AppConfig.appVersion} · Kampala Nightlife',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                children: [
                  Text('About', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Find the vibe in Kampala — discover clubs, bars, lounges and events near you. Rate venues, check in and share the best spots with the community.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (licenses.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Open Source Licenses', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    ...licenses.map((l) {
                      final lic = l as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceColor : AppTheme.lightSurface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppTheme.borderColor : AppTheme.lightBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lic['name'] as String? ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              if ((lic['version'] as String?)?.isNotEmpty == true)
                                Text('v${lic['version']}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.mutedColor)),
                              if ((lic['license'] as String?)?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Text(lic['license'] as String,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.accentColor)),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  Text('© ${DateTime.now().year} VibeKLA. All rights reserved.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 0),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppTheme.mutedColor, letterSpacing: 1)),
      );
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
      );
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  @override
  Widget build(BuildContext context) => const Text(
        'v${AppConfig.appVersion}',
        style: TextStyle(fontSize: 12, color: AppTheme.mutedColor),
      );
}

class _MenuSection extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceColor : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.lightBorder,
        ),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              item,
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.lightBorder,
                  indent: 52,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _MenuItem({required this.icon, required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceColor)),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.mutedColor),
          ],
        ),
      ),
    );
  }
}
