import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

/// A macOS-style floating dock used as the app's bottom navigation.
///
/// Inspired by the dribbble dock concept: glass background, gentle
/// floating animation, hover/press scale + lift + glow on items, and a
/// little active-indicator dot below the current screen's icon.
class DockNav extends StatefulWidget {
  final List<DockNavItem> items;
  final int activeIndex;

  const DockNav({
    super.key,
    required this.items,
    this.activeIndex = 0,
  });

  /// The 5 default destinations used by every main screen.
  static List<DockNavItem> defaultItems(BuildContext context) => [
        DockNavItem(
          icon: Icons.home_rounded,
          label: 'Home',
          onTap: () => context.go('/home'),
        ),
        DockNavItem(
          icon: Icons.bar_chart_rounded,
          label: 'Stats',
          onTap: () => context.go('/stats'),
        ),
        DockNavItem(
          icon: Icons.fitness_center,
          label: 'Plan',
          onTap: () => context.go('/workout-plan'),
        ),
        DockNavItem(
          icon: Icons.restaurant_menu_rounded,
          label: 'Nutrition',
          onTap: () => context.go('/nutrition'),
        ),
        DockNavItem(
          icon: Icons.person_outline_rounded,
          label: 'Profile',
          onTap: () => context.go('/profile'),
        ),
      ];

  @override
  State<DockNav> createState() => _DockNavState();
}

class DockNavItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const DockNavItem({
    required this.icon,
    required this.label,
    this.onTap,
  });
}

class _DockNavState extends State<DockNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  int? _hovered;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Center(
          child: AnimatedBuilder(
            animation: _floatCtrl,
            builder: (_, child) {
              final t = _floatCtrl.value * 2 - 1; // -1..1
              return Transform.translate(
                offset: Offset(0, t * 2),
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(28),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.10)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(widget.items.length, (i) {
                      return _DockItem(
                        item: widget.items[i],
                        isActive: i == widget.activeIndex,
                        isHovered: _hovered == i,
                        onHoverChange: (h) =>
                            setState(() => _hovered = h ? i : null),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final DockNavItem item;
  final bool isActive;
  final bool isHovered;
  final ValueChanged<bool> onHoverChange;

  const _DockItem({
    required this.item,
    required this.isActive,
    required this.isHovered,
    required this.onHoverChange,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChange(true),
      onExit: (_) => onHoverChange(false),
      child: Tooltip(
        message: item.label,
        waitDuration: const Duration(milliseconds: 250),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => onHoverChange(true),
          onTapUp: (_) {
            onHoverChange(false);
            item.onTap?.call();
          },
          onTapCancel: () => onHoverChange(false),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0, end: isHovered ? 1.0 : 0.0),
            builder: (_, t, __) {
              final scale = 1 + 0.22 * t;
              final rotate = -0.07 * t;
              final lift = -8 * t;
              return Transform.translate(
                offset: Offset(0, lift),
                child: Transform.rotate(
                  angle: rotate,
                  child: Transform.scale(
                    scale: scale,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(
                                  (isActive ? 0.14 : 0.0) + 0.10 * t),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primary
                                    .withOpacity(0.45 * t),
                                width: 1,
                              ),
                              boxShadow: t > 0
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary
                                            .withOpacity(0.35 * t),
                                        blurRadius: 18 * t,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              item.icon,
                              color: isActive
                                  ? AppTheme.primary
                                  : Colors.white70,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
