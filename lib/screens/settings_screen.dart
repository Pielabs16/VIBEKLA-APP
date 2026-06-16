import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../providers/content_provider.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _keyNotifications = 'vk_notifications_enabled';

  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool(_keyNotifications) ?? false;
    });
  }

  Future<void> _setNotifications(bool val) async {
    setState(() => _notificationsEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, val);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = context.watch<ContentProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.surfaceColor : AppTheme.lightSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionHeader('Notifications'),
          _SettingsGroup(children: [
            _SettingRow(
              icon: Icons.notifications_outlined,
              label: 'Push Notifications',
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: _setNotifications,
                activeThumbColor: AppTheme.primaryColor,
              ),
            ),
            if (_notificationsEnabled) ...[
              _SettingRow(
                icon: Icons.event_rounded,
                label: 'Event Alerts',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: _setNotifications,
                  activeThumbColor: AppTheme.primaryColor,
                ),
              ),
              _SettingRow(
                icon: Icons.local_fire_department_rounded,
                label: 'Vibe Updates',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: _setNotifications,
                  activeThumbColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ]),

          const SizedBox(height: 20),
          const _SectionHeader('Legal'),
          _SettingsGroup(children: [
            _SettingRow(
              icon: Icons.shield_outlined,
              label: 'Privacy Policy',
              onTap: () => _openLegal(context, 'privacy_policy', content),
            ),
            _SettingRow(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => _openLegal(context, 'terms_of_service', content),
            ),
          ]),

          const SizedBox(height: 20),
          const _SectionHeader('App Info'),
          _SettingsGroup(children: [
            const _SettingRow(
              icon: Icons.info_outline_rounded,
              label: 'App Version',
              value: 'v${AppConfig.appVersion}',
            ),
            _SettingRow(
              icon: Icons.cleaning_services_rounded,
              label: 'Clear Cache',
              onTap: () => _showClearCacheDialog(context),
              labelColor: Colors.redAccent,
              iconColor: Colors.redAccent,
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _openLegal(BuildContext context, String key, ContentProvider content) {
    final text = content.appSettings[key] as String?;
    if (text != null && text.isNotEmpty) {
      _showTextSheet(context, key == 'privacy_policy' ? 'Privacy Policy' : 'Terms of Service', text);
      return;
    }
    // Fall back to URL if no text
    final url = key == 'privacy_policy'
        ? 'https://vibekla.com/privacy'
        : 'https://vibekla.com/terms';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _showTextSheet(BuildContext context, String title, String body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, ctrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF130030) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(title, style: Theme.of(context).textTheme.headlineSmall),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  child: Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Cache', style: TextStyle(color: AppTheme.onSurfaceColor)),
        content: const Text(
          'This will remove locally cached data. Your account and bookmarks will not be affected.',
          style: TextStyle(color: AppTheme.mutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.mutedColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService().clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Cache cleared'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: AppTheme.mutedColor, letterSpacing: 1,
          ),
        ),
      );
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

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
        children: children.asMap().entries.map((e) {
          return Column(children: [
            e.value,
            if (e.key < children.length - 1)
              Divider(
                height: 1,
                color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.lightBorder,
                indent: 52,
              ),
          ]);
        }).toList(),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? labelColor;
  final Color? iconColor;

  const _SettingRow({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.labelColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = iconColor ?? AppTheme.primaryColor;
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
                color: effectiveIcon.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: effectiveIcon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500,
                  color: labelColor ?? AppTheme.onSurfaceColor,
                ),
              ),
            ),
            if (value != null)
              Text(value!, style: const TextStyle(fontSize: 13, color: AppTheme.mutedColor)),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null && value == null)
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.mutedColor),
          ],
        ),
      ),
    );
  }
}
