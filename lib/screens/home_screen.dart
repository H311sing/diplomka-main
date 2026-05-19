import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _ringController;
  String _userName = 'Athlete';
  String? _avatarUrl;
  List<Map<String, dynamic>> _todayExercises = [];

  final List<Map<String, dynamic>> _activities = [
    {
      'label': 'MOVE',
      'current': 479,
      'target': 800,
      'unit': 'CAL',
      'color': Color(0xFFFF2D55),
      'progress': 0.85,
      'size': 90.0,
    },
    {
      'label': 'EXERCISE',
      'current': 24,
      'target': 30,
      'unit': 'MIN',
      'color': Color(0xFFA3F900),
      'progress': 0.60,
      'size': 70.0,
    },
    {
      'label': 'STAND',
      'current': 6,
      'target': 12,
      'unit': 'HR',
      'color': Color(0xFF04C7DD),
      'progress': 0.30,
      'size': 50.0,
    },
  ];

  final List<String> _quotes = [
    'NO PAIN, NO GAIN',
    'PUSH YOUR LIMITS',
    'EARN YOUR BODY',
    'SWEAT IS FAT CRYING',
    'BE STRONGER THAN YOUR EXCUSES',
  ];
  int _quoteIndex = 0;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
    _loadUser();
    _loadExercises();
    _startQuoteTimer();
  }

  Future<void> _loadExercises() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('workout_exercises')
          .select()
          .eq('user_id', user.id)
          .order('created_at');
      if (mounted) {
        setState(() =>
            _todayExercises = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {}
  }

  Future<void> _toggleExercise(Map<String, dynamic> exercise) async {
    final newValue = !(exercise['is_done'] as bool? ?? false);
    setState(() => exercise['is_done'] = newValue);
    try {
      await Supabase.instance.client
          .from('workout_exercises')
          .update({'is_done': newValue}).eq('id', exercise['id']);
    } catch (_) {
      if (mounted) setState(() => exercise['is_done'] = !newValue);
    }
  }

  Future<void> _loadUser() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final name = user.userMetadata?['full_name'] as String? ??
        user.email?.split('@').first ??
        'Athlete';

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userName = (data?['full_name'] as String? ?? name).split(' ').first;
          _avatarUrl = data?['avatar_url'] as String?;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _userName = name.split(' ').first);
    }
  }

  void _startQuoteTimer() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _quoteIndex = (_quoteIndex + 1) % _quotes.length);
        _startQuoteTimer();
      }
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildActivitySection(),
                const SizedBox(height: 16),
                _buildMetricsRow(),
                const SizedBox(height: 16),
                _buildWeeklyProgress(),
                const SizedBox(height: 16),
                _buildTodayWorkout(),
                const SizedBox(height: 16),
                _buildQuoteBanner(),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── CARD WRAPPER ─────────────────────────────────────────
  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.hairline),
        boxShadow: AppTheme.cardShadow,
      );

  // ─── HEADER ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppTheme.textFaint, size: 12),
                  const SizedBox(width: 5),
                  Text(_getFormattedDate(),
                      style: GoogleFonts.inter(
                          color: AppTheme.textFaint,
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 6),
              Text(_getGreeting(),
                  style: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              Text('$_userName 👋',
                  style: GoogleFonts.bebasNeue(
                      color: AppTheme.ink, fontSize: 30, letterSpacing: 1)),
            ],
          ),
        ),
        _circleButton(
          icon: Icons.dynamic_feed_outlined,
          onTap: () => context.go('/feed'),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.lime,
              border: Border.all(color: AppTheme.ink, width: 2),
            ),
            child: _avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      _avatarUrl!,
                      fit: BoxFit.cover,
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) => _avatarFallback(),
                    ),
                  )
                : _avatarFallback(),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1);
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.hairline),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Icon(icon, color: AppTheme.ink, size: 20),
      ),
    );
  }

  Widget _avatarFallback() {
    return Center(
      child: Text(
        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'G',
        style: GoogleFonts.bebasNeue(color: AppTheme.ink, fontSize: 22),
      ),
    );
  }

  // ─── ACTIVITY RINGS (dark card) ───────────────────────────
  Widget _buildActivitySection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Today\'s Activity',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: 1)),
              GestureDetector(
                onTap: () => context.go('/stats'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.lime,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('See All',
                      style: GoogleFonts.inter(
                          color: AppTheme.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: _activities.map((act) {
                    final size = act['size'] as double;
                    return SizedBox(
                      width: size * 1.22,
                      height: size * 1.22,
                      child: AnimatedBuilder(
                        animation: _ringController,
                        builder: (_, __) => CustomPaint(
                          painter: _RingPainter(
                            progress: (_ringController.value *
                                    (act['progress'] as double))
                                .clamp(0.0, 1.0),
                            color: act['color'] as Color,
                            strokeWidth: 9,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: _activities.map((act) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: act['color'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(act['label'] as String,
                                  style: GoogleFonts.inter(
                                      color: Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1)),
                            ],
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '${act['current']}/${act['target']}',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: ' ${act['unit']}',
                                  style: GoogleFonts.inter(
                                      color: Colors.white38,
                                      fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.1);
  }

  // ─── METRICS ROW ──────────────────────────────────────────
  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            label: 'Fitness Score',
            value: '88%',
            icon: Icons.bar_chart_rounded,
            bg: AppTheme.lime,
            subtitle: 'This week',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMetricCard(
            label: 'Hydration',
            value: '781 ml',
            icon: Icons.water_drop_outlined,
            bg: AppTheme.lavender,
            subtitle: 'Today',
          ),
        ),
      ],
    ).animate().fadeIn(delay: 350.ms, duration: 600.ms);
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color bg,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    style: GoogleFonts.inter(
                        color: AppTheme.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              Icon(icon, color: AppTheme.ink, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final heights = [0.4, 0.6, 0.5, 0.8, 0.7, 0.9, 0.75];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: AnimatedBuilder(
                    animation: _ringController,
                    builder: (_, __) => Container(
                      height: 32 * heights[i] * _ringController.value,
                      decoration: BoxDecoration(
                        color: AppTheme.ink
                            .withOpacity(0.25 + heights[i] * 0.45),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: GoogleFonts.bebasNeue(
                  color: AppTheme.ink, fontSize: 28, letterSpacing: 1)),
          Text(subtitle,
              style: GoogleFonts.inter(
                  color: AppTheme.ink.withOpacity(0.55), fontSize: 10)),
        ],
      ),
    );
  }

  // ─── WEEKLY PROGRESS ──────────────────────────────────────
  Widget _buildWeeklyProgress() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final values = [0.8, 0.6, 1.0, 0.4, 0.9, 0.5, 0.0];
    final today = DateTime.now().weekday - 1;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Progress',
              style: GoogleFonts.bebasNeue(
                  color: AppTheme.ink, fontSize: 22, letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isToday = i == today;
              final isDone = values[i] > 0;
              return Column(
                children: [
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (_, __) => Container(
                      width: 30,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppTheme.appBg,
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 30,
                        height: 56 * values[i] * _ringController.value,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isToday
                              ? AppTheme.lime
                              : isDone
                                  ? AppTheme.ink
                                  : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(days[i],
                      style: GoogleFonts.inter(
                        color: isToday ? AppTheme.ink : AppTheme.textFaint,
                        fontSize: 12,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w400,
                      )),
                ],
              );
            }),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 450.ms, duration: 600.ms);
  }

  // ─── TODAY'S WORKOUT ──────────────────────────────────────
  IconData _groupIcon(String? group) {
    switch (group) {
      case 'Back':
        return Icons.sports_gymnastics;
      case 'Legs':
        return Icons.directions_run;
      case 'Shoulders':
        return Icons.sports_handball;
      case 'Arms':
        return Icons.sports_mma;
      case 'Core':
        return Icons.self_improvement;
      case 'Cardio':
        return Icons.favorite;
      default:
        return Icons.fitness_center;
    }
  }

  Widget _buildTodayWorkout() {
    final doneCount =
        _todayExercises.where((e) => e['is_done'] as bool? ?? false).length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Workout",
                  style: GoogleFonts.bebasNeue(
                      color: AppTheme.ink, fontSize: 22, letterSpacing: 1)),
              GestureDetector(
                onTap: () => context.go('/workout-plan'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.lavender,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                      _todayExercises.isEmpty
                          ? 'Add Plan'
                          : '$doneCount/${_todayExercises.length} done',
                      style: GoogleFonts.inter(
                          color: AppTheme.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_todayExercises.isEmpty)
            GestureDetector(
              onTap: () => context.go('/workout-plan'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded,
                        color: AppTheme.textFaint, size: 36),
                    const SizedBox(height: 8),
                    Text('No plan yet — tap to create one',
                        style: GoogleFonts.inter(
                            color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ..._todayExercises.map((w) {
              final done = w['is_done'] as bool? ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _toggleExercise(w),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: done ? AppTheme.lime : AppTheme.appBg,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          _groupIcon(w['muscle_group'] as String?),
                          color: done ? AppTheme.ink : AppTheme.textFaint,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(w['name'] as String? ?? '',
                            style: GoogleFonts.inter(
                              color:
                                  done ? AppTheme.textFaint : AppTheme.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                      ),
                      Text('${w['sets'] ?? 0}×${w['reps'] ?? 0}',
                          style: GoogleFonts.inter(
                              color: AppTheme.textFaint, fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: done ? AppTheme.limeDeep : AppTheme.hairline,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    ).animate().fadeIn(delay: 550.ms, duration: 600.ms);
  }

  // ─── QUOTE BANNER (dark card) ─────────────────────────────
  Widget _buildQuoteBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey(_quoteIndex),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.ink,
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            const Icon(Icons.format_quote_rounded,
                color: AppTheme.lime, size: 30),
            const SizedBox(height: 8),
            Text(
              _quotes[_quoteIndex],
              textAlign: TextAlign.center,
              style: GoogleFonts.bebasNeue(
                color: Colors.white,
                fontSize: 26,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text('Daily Motivation',
                style: GoogleFonts.inter(
                    color: AppTheme.lime,
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 650.ms, duration: 600.ms);
  }

  // ─── BOTTOM NAV ───────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(top: BorderSide(color: AppTheme.hairline)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navItem(Icons.home_rounded, 'Home', true),
          GestureDetector(
            onTap: () => context.go('/stats'),
            child: _navItem(Icons.bar_chart_rounded, 'Stats', false),
          ),
          GestureDetector(
            onTap: () => context.go('/workout-plan'),
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: AppTheme.ink,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center,
                  color: AppTheme.lime, size: 24),
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/nutrition'),
            child: _navItem(
                Icons.restaurant_menu_rounded, 'Nutrition', false),
          ),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: _navItem(
                Icons.person_outline_rounded, 'Profile', false),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: active ? AppTheme.ink : AppTheme.textFaint, size: 24),
        const SizedBox(height: 3),
        Text(label,
            style: GoogleFonts.inter(
              color: active ? AppTheme.ink : AppTheme.textFaint,
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            )),
      ],
    );
  }
}

// ─── RING PAINTER ─────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      2 * 3.14159 * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
