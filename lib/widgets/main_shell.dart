import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _tabs = ['/home', '/discover', '/map', '/profile'];

  int _indexFor(String path) {
    if (path.startsWith('/discover')) return 1;
    if (path.startsWith('/map')) return 2;
    if (path.startsWith('/profile')) return 3;
    return 0;
  }

  void _go(BuildContext context, int index) {
    context.go(_tabs[index]);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _indexFor(location);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          widget.child,
          // Left-edge swipe zone — doesn't overlap scrollable content
          if (currentIndex > 0)
            Positioned(
              left: 0, top: 0, bottom: 0,
              width: 22,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 300) _go(context, currentIndex - 1);
                },
              ),
            ),
          // Right-edge swipe zone
          if (currentIndex < 3)
            Positioned(
              right: 0, top: 0, bottom: 0,
              width: 22,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) < -300) _go(context, currentIndex + 1);
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: _VibeBottomNav(
        currentIndex: currentIndex,
        onTap: (i) => _go(context, i),
      ),
    );
  }
}

class _VibeBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _VibeBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF100020) : Colors.white;
    final borderC = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8E0F0);

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: borderC, width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded,    label: 'Home',     selected: currentIndex == 0, onTap: () => onTap(0)),
              _NavItem(icon: Icons.explore_rounded,  label: 'Discover', selected: currentIndex == 1, onTap: () => onTap(1)),
              _NavItem(icon: Icons.map_rounded,      label: 'Map',      selected: currentIndex == 2, onTap: () => onTap(2)),
              _NavItem(icon: Icons.person_rounded,   label: 'Profile',  selected: currentIndex == 3, onTap: () => onTap(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = AppTheme.primaryColor;
    final inactiveColor = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: selected
                  ? BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    )
                  : null,
              child: Icon(icon, size: 22, color: selected ? activeColor : inactiveColor),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
