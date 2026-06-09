import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/calculations.dart';
import '../core/steps_service.dart';
import '../core/theme.dart';
import '../widgets/dock_nav.dart';

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
  int _pendingRequests = 0;
  RealtimeChannel? _reqChannel;

  // ── Real daily stats (Supabase) ──────────────────────────
  int _todayCalories = 0; // burned today (workout_logs.calories_burned)
  int _todayMinutes = 0; // workout minutes today
  int _todayWaterMl = 0; // water consumed today
  int _monthWorkouts = 0; // for level badge
  List<int> _weekWorkoutMins = List.filled(7, 0); // last 7 days
  List<int> _weekWaterMl = List.filled(7, 0); // last 7 days

  // Daily targets (could later live in profile)
  static const int _targetCals = 800;
  static const int _targetMins = 30;
  static const int _targetWaterMl = 2500;

  double get _moveProgress =>
      (_todayCalories / _targetCals).clamp(0.0, 1.0);
  double get _exerciseProgress =>
      (_todayMinutes / _targetMins).clamp(0.0, 1.0);
  double get _hydrationProgress =>
      (_todayWaterMl / _targetWaterMl).clamp(0.0, 1.0);
  int get _scorePercent => dailyScorePercent(
        caloriesBurned: _todayCalories,
        targetCalories: _targetCals,
        workoutMinutes: _todayMinutes,
        targetMinutes: _targetMins,
        waterMl: _todayWaterMl,
        targetWaterMl: _targetWaterMl,
      );
  int get _level => levelFromWorkouts(_monthWorkouts);

  List<Map<String, dynamic>> get _activities => [
        {
          'label': 'MOVE',
          'current': _todayCalories,
          'target': _targetCals,
          'unit': 'CAL',
          'color': const Color(0xFFFF2D55),
          'progress': _moveProgress,
          'size': 90.0,
        },
        {
          'label': 'EXERCISE',
          'current': _todayMinutes,
          'target': _targetMins,
          'unit': 'MIN',
          'color': const Color(0xFFA3F900),
          'progress': _exerciseProgress,
          'size': 70.0,
        },
        {
          'label': 'HYDRATE',
          'current': _todayWaterMl,
          'target': _targetWaterMl,
          'unit': 'ML',
          'color': const Color(0xFF04C7DD),
          'progress': _hydrationProgress,
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
    _loadRequests();
    _loadDailyStats();
    _startQuoteTimer();
  }

  Future<void> _loadDailyStats() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = today.toIso8601String().split('T')[0];
    final weekStart = today.subtract(const Duration(days: 6));
    final weekStartStr = weekStart.toIso8601String().split('T')[0];
    final monthStart =
        DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];

    try {
      final results = await Future.wait([
        supabase
            .from('workout_logs')
            .select('duration_minutes, calories_burned, workout_date')
            .eq('user_id', user.id)
            .gte('workout_date', weekStartStr),
        supabase
            .from('water_logs')
            .select('amount_ml, log_date')
            .eq('user_id', user.id)
            .gte('log_date', weekStartStr),
        supabase
            .from('workout_logs')
            .select('id')
            .eq('user_id', user.id)
            .gte('workout_date', monthStart),
      ]);

      final workouts = results[0] as List;
      final waters = results[1] as List;
      final monthCount = (results[2] as List).length;

      int todayCals = 0;
      int todayMins = 0;
      int todayWater = 0;
      final weekMins = List<int>.filled(7, 0);
      final weekWater = List<int>.filled(7, 0);

      for (final w in workouts) {
        final dStr = w['workout_date'] as String;
        final d = DateTime.parse(dStr);
        final daysAgo =
            today.difference(DateTime(d.year, d.month, d.day)).inDays;
        final idx = 6 - daysAgo;
        final mins = (w['duration_minutes'] as num?)?.toInt() ?? 0;
        final cals = (w['calories_burned'] as num?)?.toInt() ?? 0;
        if (idx >= 0 && idx < 7) weekMins[idx] += mins;
        if (dStr == todayStr) {
          todayMins += mins;
          todayCals += cals;
        }
      }
      for (final wl in waters) {
        final dStr = wl['log_date'] as String;
        final d = DateTime.parse(dStr);
        final daysAgo =
            today.difference(DateTime(d.year, d.month, d.day)).inDays;
        final idx = 6 - daysAgo;
        final ml = (wl['amount_ml'] as num?)?.toInt() ?? 0;
        if (idx >= 0 && idx < 7) weekWater[idx] += ml;
        if (dStr == todayStr) todayWater += ml;
      }

      if (mounted) {
        setState(() {
          _todayCalories = todayCals;
          _todayMinutes = todayMins;
          _todayWaterMl = todayWater;
          _monthWorkouts = monthCount;
          _weekWorkoutMins = weekMins;
          _weekWaterMl = weekWater;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRequests() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await _refreshRequestCount(user.id);
    _subscribeRequests(user.id);
  }

  Future<void> _refreshRequestCount(String uid) async {
    try {
      final data = await Supabase.instance.client
          .from('friendships')
          .select('id')
          .eq('addressee_id', uid)
          .eq('status', 'pending');
      if (mounted) {
        setState(() => _pendingRequests = (data as List).length);
      }
    } catch (_) {}
  }

  void _subscribeRequests(String uid) {
    if (_reqChannel != null) return;
    _reqChannel = Supabase.instance.client
        .channel('friend_requests:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (_) => _refreshRequestCount(uid),
        )
        .subscribe();
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
        user.email?.split('@').first ?? 'Athlete';

    // Load profile from DB for avatar
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
    if (_reqChannel != null) {
      Supabase.instance.client.removeChannel(_reqChannel!);
    }
    _ringController.dispose();
    super.dispose();
  }

  String _getGreeting() => greetingFor(DateTime.now());

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
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 20),
                _buildAiCoachCard(),
                const SizedBox(height: 12),
                _buildRepCounterCard(),
                const SizedBox(height: 12),
                _buildStepsCard(),
                const SizedBox(height: 24),
                _buildActivitySection(),
                const SizedBox(height: 24),
                _buildMetricsRow(),
                const SizedBox(height: 24),
                _buildWeeklyProgress(),
                const SizedBox(height: 24),
                _buildTodayWorkout(),
                const SizedBox(height: 24),
                _buildQuoteBanner(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DockNav(
        items: DockNav.defaultItems(context),
        activeIndex: 0,
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: Colors.white38, size: 12),
                const SizedBox(width: 4),
                Text(_getFormattedDate(),
                    style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${_getGreeting()}, ',
                    style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 18,
                        fontWeight: FontWeight.w400),
                  ),
                  TextSpan(
                    text: '$_userName!',
                    style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 22,
                        letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite,
                          color: AppTheme.primary, size: 10),
                      const SizedBox(width: 4),
                      Text('$_scorePercent% Today',
                          style: GoogleFonts.inter(
                              color: AppTheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.blue.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star,
                          color: Colors.blue, size: 10),
                      const SizedBox(width: 4),
                      Text('Lv. $_level',
                          style: GoogleFonts.inter(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // Feed + Notification + Avatar
        Row(
          children: [
            GestureDetector(
              onTap: () => context.go('/feed'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.dynamic_feed_outlined,
                    color: Colors.white60, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => context.go('/friends', extra: 1),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: Colors.white60, size: 18),
                  ),
                  if (_pendingRequests > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF0D0D0D), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            _pendingRequests > 9 ? '9+' : '$_pendingRequests',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // ← Аватарка кликабельная — переход в профиль
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, Color(0xFFCC4400)],
                  ),
                ),
                child: _avatarUrl != null
                    ? ClipOval(
                  child: Image.network(
                    _avatarUrl!,
                    fit: BoxFit.cover,
                    width: 44,
                    height: 44,
                    errorBuilder: (_, __, ___) => _avatarFallback(),
                  ),
                )
                    : _avatarFallback(),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1);
  }

  Widget _avatarFallback() {
    return Center(
      child: Text(
        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'G',
        style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20),
      ),
    );
  }

  // ─── AI COACH ─────────────────────────────────────────────
  Widget _buildAiCoachCard() {
    return GestureDetector(
      onTap: () => context.go('/recommendations'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, Color(0xFFFF8C42)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Coach',
                      style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: 22,
                          letterSpacing: 1)),
                  Text('Personalized nutrition & workout tips',
                      style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 600.ms).slideY(begin: 0.1);
  }

  // ─── REP COUNTER (camera) ─────────────────────────────────
  Widget _buildRepCounterCard() {
    return GestureDetector(
      onTap: () => context.go('/pose-counter'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE03250), Color(0xFFFF6B35)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE03250).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rep Counter',
                      style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: 22,
                          letterSpacing: 1)),
                  Text('AI counts your push-ups via the camera',
                      style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 600.ms).slideY(begin: 0.1);
  }

  // ─── STEP COUNTER ─────────────────────────────────────────
  // Live step count from the device's hardware step sensor (Android).
  // The card listens to StepsService via a ValueListenableBuilder so it
  // re-renders on every sensor update without rebuilding the whole page.
  Widget _buildStepsCard() {
    const int target = 10000;
    return ValueListenableBuilder<bool>(
      valueListenable: StepsService.instance.unavailable,
      builder: (_, unavailable, __) {
        return ValueListenableBuilder<int>(
          valueListenable: StepsService.instance.todaySteps,
          builder: (_, steps, __) {
            final progress = (steps / target).clamp(0.0, 1.0);
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFA3F900).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.directions_walk_rounded,
                        color: Color(0xFFA3F900), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              unavailable ? '—' : '$steps',
                              style: GoogleFonts.bebasNeue(
                                  color: Colors.white,
                                  fontSize: 28,
                                  letterSpacing: 1),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 4, left: 6),
                              child: Text('/ $target steps',
                                  style: GoogleFonts.inter(
                                      color: Colors.white38,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: unavailable ? 0 : progress,
                            backgroundColor:
                                Colors.white.withOpacity(0.06),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFA3F900)),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          unavailable
                              ? 'Step sensor unavailable (test on real Android)'
                              : 'Today · live from device sensor',
                          style: GoogleFonts.inter(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.1);
  }

  // ─── ACTIVITY RINGS ───────────────────────────────────────
  Widget _buildActivitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Activity Rings',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 1)),
              GestureDetector(
                onTap: () => context.go('/stats'),
                child: Text('See All',
                    style: GoogleFonts.inter(
                        color: AppTheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
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
                  children: _activities.asMap().entries.map((entry) {
                    final act = entry.value;
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
                            strokeWidth: 8,
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
                                      color: Colors.white54,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1)),
                            ],
                          ),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          '${act['current']}/${act['target']}',
                                      style: GoogleFonts.inter(
                                        color: act['color'] as Color,
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
    // Last 7 days as normalized 0..1 bars
    final scoreBars = List<double>.generate(7, (i) {
      final m = (_weekWorkoutMins[i] / _targetMins).clamp(0.0, 1.0);
      final h = (_weekWaterMl[i] / _targetWaterMl).clamp(0.0, 1.0);
      return ((m + h) / 2).toDouble();
    });
    final hydrationBars = _weekWaterMl
        .map((ml) => (ml / _targetWaterMl).clamp(0.0, 1.0).toDouble())
        .toList();

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            label: 'Score',
            value: '$_scorePercent%',
            icon: Icons.bar_chart_rounded,
            color: AppTheme.primary,
            subtitle: 'Today',
            bars: scoreBars,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            label: 'Hydration',
            value: '$_todayWaterMl ml',
            icon: Icons.water_drop_outlined,
            color: const Color(0xFF4285F4),
            subtitle: 'Today',
            bars: hydrationBars,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 350.ms, duration: 600.ms);
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required List<double> bars,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final h = bars.length > i ? bars[i] : 0.0;
              final isToday = i == 6;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: AnimatedBuilder(
                    animation: _ringController,
                    builder: (_, __) => Container(
                      height: (32 * h * _ringController.value)
                          .clamp(2.0, 32.0),
                      decoration: BoxDecoration(
                        color: color.withOpacity(
                            isToday ? 1.0 : (0.3 + h * 0.5)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: GoogleFonts.bebasNeue(
                  color: Colors.white,
                  fontSize: 26,
                  letterSpacing: 1)),
          Text(subtitle,
              style: GoogleFonts.inter(
                  color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  // ─── WEEKLY PROGRESS ──────────────────────────────────────
  Widget _buildWeeklyProgress() {
    // Last 7 days, oldest → today. Label each day by its weekday letter.
    final now = DateTime.now();
    final letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final days = List<String>.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return letters[d.weekday - 1];
    });
    // Normalize: 60+ minutes of workout in a day = full bar.
    final values = _weekWorkoutMins
        .map((m) => (m / 60).clamp(0.0, 1.0).toDouble())
        .toList();
    final today = 6; // today is always the last bar

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Progress',
              style: GoogleFonts.bebasNeue(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 1)),
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
                      width: 32,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withOpacity(0.05),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 32,
                        height: 50 *
                            values[i] *
                            _ringController.value,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isToday
                                ? [
                              AppTheme.primary,
                              const Color(0xFFFF8C42)
                            ]
                                : isDone
                                ? [
                              AppTheme.primary
                                  .withOpacity(0.5),
                              AppTheme.primary
                                  .withOpacity(0.3)
                            ]
                                : [
                              Colors.transparent,
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(days[i],
                      style: GoogleFonts.inter(
                        color: isToday
                            ? AppTheme.primary
                            : Colors.white38,
                        fontSize: 12,
                        fontWeight: isToday
                            ? FontWeight.w700
                            : FontWeight.w400,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Workout",
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 1)),
              GestureDetector(
                onTap: () => context.go('/workout-plan'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                      _todayExercises.isEmpty
                          ? 'Add Plan'
                          : '$doneCount/${_todayExercises.length} done',
                      style: GoogleFonts.inter(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_todayExercises.isEmpty)
            GestureDetector(
              onTap: () => context.go('/workout-plan'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded,
                        color: Colors.white24, size: 36),
                    const SizedBox(height: 8),
                    Text('No plan yet — tap to create one',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 13)),
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
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: done
                              ? AppTheme.primary.withOpacity(0.15)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _groupIcon(w['muscle_group'] as String?),
                          color:
                              done ? AppTheme.primary : Colors.white30,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(w['name'] as String? ?? '',
                            style: GoogleFonts.inter(
                              color:
                                  done ? Colors.white54 : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                      ),
                      Text('${w['sets'] ?? 0}×${w['reps'] ?? 0}',
                          style: GoogleFonts.inter(
                              color: Colors.white38, fontSize: 12)),
                      const SizedBox(width: 12),
                      Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: done
                            ? AppTheme.primary
                            : Colors.white.withOpacity(0.2),
                        size: 20,
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

  // ─── QUOTE BANNER ─────────────────────────────────────────
  Widget _buildQuoteBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey(_quoteIndex),
        width: double.infinity,
        padding:
        const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withOpacity(0.15),
              const Color(0xFFFF8C42).withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppTheme.primary.withOpacity(0.25), width: 1),
        ),
        child: Column(
          children: [
            const Icon(Icons.format_quote_rounded,
                color: AppTheme.primary, size: 28),
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
                    color: AppTheme.primary.withOpacity(0.7),
                    fontSize: 11,
                    letterSpacing: 2)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 650.ms, duration: 600.ms);
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
      ..color = color.withOpacity(0.12)
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