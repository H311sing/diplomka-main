import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/calculations.dart';
import '../core/theme.dart';
import '../widgets/dock_nav.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animCtrl;
  int _selectedPeriod = 1;
  int? _hoveredBar;

  final _supabase = Supabase.instance.client;
  bool _loading = true;
  int _totalWorkouts = 0;
  int _totalCaloriesBurned = 0;
  double _totalHours = 0;
  int _currentStreak = 0;
  List<Map<String, dynamic>> _weightLogs = [];
  double? _userWeight; // from profile — used for MET calorie estimates

  final List<String> _periods = ['Week', 'Month', 'Year'];

  final List<Map<String, dynamic>> _healthStats = [
    {'title': 'Sleep', 'value': '7.5', 'unit': 'h', 'change': '+5%', 'up': true},
    {'title': 'Hydration', 'value': '0', 'unit': 'L', 'change': '0%', 'up': true},
    {'title': 'Steps', 'value': '0', 'unit': '', 'change': '0%', 'up': true},
  ];

  final List<Map<String, dynamic>> _graphData = [
    {'label': 'Sleep', 'value': 0, 'color': Color(0xFF3B82F6), 'description': 'Sleep quality'},
    {'label': 'Hydration', 'value': 0, 'color': Color(0xFF22C55E), 'description': 'Water intake level'},
    {'label': 'Exercise', 'value': 0, 'color': Color(0xFFF59E0B), 'description': 'Active minutes today'},
    {'label': 'Nutrition', 'value': 0, 'color': Color(0xFFEF4444), 'description': 'Daily nutrition goal met'},
  ];

  List<Map<String, dynamic>> _weeklyData = List.generate(7, (i) => {
    'day': ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
    'calories': 0,
    'workout': 0,
  });

  final List<Map<String, dynamic>> _achievements = [
    {'icon': Icons.local_fire_department, 'color': Color(0xFFFF6B35), 'title': '7 Day Streak', 'desc': 'Train 7 days in a row'},
    {'icon': Icons.fitness_center, 'color': Color(0xFFA3F900), 'title': '10 Workouts', 'desc': 'Complete 10 sessions'},
    {'icon': Icons.monitor_weight, 'color': Color(0xFF04C7DD), 'title': 'Hydration', 'desc': 'Drink 2L water daily'},
    {'icon': Icons.emoji_events, 'color': Color(0xFFFFD700), 'title': 'PRO Athlete', 'desc': 'Reach Pro level'},
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final now = DateTime.now();
      final monthStart =
      DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];

      // Load workouts this month
      final workouts = await _supabase
          .from('workout_logs')
          .select()
          .eq('user_id', user.id)
          .gte('workout_date', monthStart);

      // Load water today
      final today = now.toIso8601String().split('T')[0];
      final water = await _supabase
          .from('water_logs')
          .select('amount_ml')
          .eq('user_id', user.id)
          .eq('log_date', today);

      final totalWaterL = water.fold<double>(
          0, (s, w) => s + (w['amount_ml'] as num).toDouble()) /
          1000;

      // Load nutrition today
      final nutrition = await _supabase
          .from('nutrition_logs')
          .select('calories')
          .eq('user_id', user.id)
          .eq('meal_date', today);

      final totalCaloriesEaten = nutrition.fold<double>(
          0, (s, n) => s + (n['calories'] as num).toDouble());

      // Weight history
      final weightData = await _supabase
          .from('weight_logs')
          .select()
          .eq('user_id', user.id)
          .order('logged_at');

      // Profile weight (for MET calorie estimation in the add-workout sheet)
      final profileRow = await _supabase
          .from('profiles')
          .select('weight')
          .eq('id', user.id)
          .maybeSingle();
      final profileWeight = (profileRow?['weight'] as num?)?.toDouble();

      // Weekly data
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final newWeeklyData = List<Map<String, dynamic>>.generate(7, (i) => {
        'day': ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
        'calories': 0,
        'workout': 0,
      });

      for (final w in workouts) {
        final wDate = w['workout_date'] as String;
        for (int i = 0; i < 7; i++) {
          final day = weekStart
              .add(Duration(days: i))
              .toIso8601String()
              .split('T')[0];
          if (wDate == day) {
            newWeeklyData[i]['calories'] = (newWeeklyData[i]['calories'] as int) +
                (w['calories_burned'] as num).toInt();
            newWeeklyData[i]['workout'] = (newWeeklyData[i]['workout'] as int) +
                (w['duration_minutes'] as num).toInt();
          }
        }
      }

      // Exercise progress for today (minutes vs 30 min target)
      final todayWorkouts = workouts
          .where((w) => w['workout_date'] == today)
          .toList();
      final todayMins = todayWorkouts.fold<int>(
          0, (s, w) => s + (w['duration_minutes'] as num).toInt());
      final exerciseProgress = (todayMins / 30 * 100).clamp(0, 100).toInt();
      final nutritionProgress =
      (totalCaloriesEaten / 2400 * 100).clamp(0, 100).toInt();
      final hydrationProgress =
      (totalWaterL / 2.5 * 100).clamp(0, 100).toInt();

      if (mounted) {
        setState(() {
          _totalWorkouts = (workouts as List).length;
          _totalCaloriesBurned = (workouts as List).fold<int>(
              0, (s, w) => s + (w['calories_burned'] as num).toInt());
          _totalHours = (workouts as List).fold<double>(
              0,
                  (s, w) =>
              s + (w['duration_minutes'] as num).toDouble()) /
              60;
          _weeklyData = newWeeklyData;
          _weightLogs = List<Map<String, dynamic>>.from(weightData);
          _userWeight = profileWeight;
          _loading = false;

          // Update health stats
          _healthStats[1]['value'] = totalWaterL.toStringAsFixed(1);
          _healthStats[1]['change'] =
          hydrationProgress > 0 ? '+$hydrationProgress%' : '0%';

          // Update graph data
          _graphData[1]['value'] = hydrationProgress;
          _graphData[2]['value'] = exerciseProgress;
          _graphData[3]['value'] = nutritionProgress;
        });
        _animCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: AppTheme.primary))
          : SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          color: AppTheme.primary,
          backgroundColor: const Color(0xFF1A1A1A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildHealthStatCard(),
                const SizedBox(height: 24),
                _buildPeriodSelector(),
                const SizedBox(height: 16),
                _buildCaloriesChart(),
                const SizedBox(height: 24),
                _buildWorkoutChart(),
                const SizedBox(height: 24),
                _buildOverviewCards(),
                const SizedBox(height: 24),
                _buildWeightChart(),
                const SizedBox(height: 24),
                _buildBodyMetrics(),
                const SizedBox(height: 24),
                _buildAchievements(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWorkoutSheet,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Workout',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: DockNav(
        items: DockNav.defaultItems(context),
        activeIndex: 1,
      ),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.go('/home'),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white60, size: 18),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistics',
                style: GoogleFonts.bebasNeue(
                    color: Colors.white,
                    fontSize: 28,
                    letterSpacing: 2)),
            Text('Daily Health Overview',
                style:
                GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: _loadStats,
          child: const Icon(Icons.refresh_rounded,
              color: Colors.white38, size: 22),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  // ─── HEALTH STAT CARD ─────────────────────────────────────
  Widget _buildHealthStatCard() {
    return Container(
      width: double.infinity,
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Daily Health Overview',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: _healthStats.map((s) {
              final isUp = s['up'] as bool;
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(s['value'] as String,
                            style: GoogleFonts.bebasNeue(
                                color: Colors.white,
                                fontSize: 28,
                                letterSpacing: 1)),
                        if ((s['unit'] as String).isNotEmpty)
                          Padding(
                            padding:
                            const EdgeInsets.only(bottom: 4, left: 2),
                            child: Text(s['unit'] as String,
                                style: GoogleFonts.inter(
                                    color: Colors.white38,
                                    fontSize: 12)),
                          ),
                      ],
                    ),
                    Text(s['title'] as String,
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isUp
                            ? Colors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(s['change'] as String,
                          style: GoogleFonts.inter(
                            color: isUp ? Colors.green : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Animated graph bars
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _graphData.asMap().entries.map((e) {
                      final i = e.key;
                      final bar = e.value;
                      final color = bar['color'] as Color;
                      final value = bar['value'] as int;
                      final isHovered = _hoveredBar == i;

                      return Expanded(
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTapDown: (_) =>
                                setState(() => _hoveredBar = i),
                            onTapUp: (_) =>
                                setState(() => _hoveredBar = null),
                            onTapCancel: () =>
                                setState(() => _hoveredBar = null),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Tooltip
                                if (isHovered)
                                  Container(
                                    margin:
                                    const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2A2A2A),
                                      borderRadius:
                                      BorderRadius.circular(8),
                                      border: Border.all(
                                          color:
                                          color.withOpacity(0.4)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(bar['label'] as String,
                                            style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight:
                                                FontWeight.w700)),
                                        Text('$value%',
                                            style: GoogleFonts.inter(
                                                color: color,
                                                fontSize: 10)),
                                        Text(
                                            bar['description'] as String,
                                            style: GoogleFonts.inter(
                                                color: Colors.white38,
                                                fontSize: 9),
                                            textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                                // Bar
                                AnimatedContainer(
                                  duration:
                                  const Duration(milliseconds: 200),
                                  transform: isHovered
                                      ? (Matrix4.identity()
                                    ..translate(0.0, -6.0))
                                      : Matrix4.identity(),
                                  child: AnimatedBuilder(
                                    animation: _animCtrl,
                                    builder: (_, __) => Container(
                                      width: double.infinity,
                                      height: value > 0
                                          ? (value / 100) *
                                          100 *
                                          _animCtrl.value
                                          : 4,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            color,
                                            color.withOpacity(0.6),
                                          ],
                                        ),
                                        boxShadow: isHovered
                                            ? [
                                          BoxShadow(
                                            color: color
                                                .withOpacity(0.4),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          )
                                        ]
                                            : [],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Legend
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data Breakdown',
                        style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: _graphData.map((item) {
                        final color = item['color'] as Color;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item['label']} (${item['value']}%)',
                              style: GoogleFonts.inter(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 600.ms).slideY(begin: 0.1);
  }

  // ─── PERIOD SELECTOR ──────────────────────────────────────
  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _periods.asMap().entries.map((e) {
          final selected = e.key == _selectedPeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(e.value,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: selected ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  // ─── CALORIES CHART ───────────────────────────────────────
  Widget _buildCaloriesChart() {
    final maxCal = _weeklyData
        .map((d) => d['calories'] as int)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

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
              Text('Calories Burned',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$_totalCaloriesBurned CAL',
                    style: GoogleFonts.inter(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: maxCal == 0
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fitness_center,
                      color: Colors.white12, size: 32),
                  const SizedBox(height: 8),
                  Text('No workouts this week',
                      style: GoogleFonts.inter(
                          color: Colors.white24, fontSize: 12)),
                ],
              ),
            )
                : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _weeklyData.asMap().entries.map((e) {
                final d = e.value;
                final cal = d['calories'] as int;
                final ratio = maxCal > 0 ? cal / maxCal : 0.0;
                final isToday =
                    e.key == DateTime.now().weekday - 1;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cal > 0)
                      Text('$cal',
                          style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 9)),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _animCtrl,
                      builder: (_, __) => Container(
                        width: 32,
                        height: cal > 0
                            ? 90 * ratio * _animCtrl.value
                            : 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: cal == 0
                              ? Colors.white.withOpacity(0.05)
                              : null,
                          gradient: cal > 0
                              ? LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isToday
                                ? [
                              AppTheme.primary,
                              const Color(0xFFFF8C42)
                            ]
                                : [
                              AppTheme.primary
                                  .withOpacity(0.4),
                              AppTheme.primary
                                  .withOpacity(0.2),
                            ],
                          )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(d['day'] as String,
                        style: GoogleFonts.inter(
                          color: isToday
                              ? AppTheme.primary
                              : Colors.white38,
                          fontSize: 11,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                        )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms);
  }

  // ─── WORKOUT CHART ────────────────────────────────────────
  Widget _buildWorkoutChart() {
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
          Text('Workout Minutes',
              style: GoogleFonts.bebasNeue(
                  color: Colors.white, fontSize: 20, letterSpacing: 1)),
          const SizedBox(height: 16),
          ..._weeklyData.map((d) {
            final mins = d['workout'] as int;
            final ratio = mins > 0 ? (mins / 60.0).clamp(0.0, 1.0) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(d['day'] as String,
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        if (mins > 0)
                          AnimatedBuilder(
                            animation: _animCtrl,
                            builder: (_, __) => FractionallySizedBox(
                              widthFactor:
                              (ratio * _animCtrl.value).clamp(0.0, 1.0),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF04C7DD),
                                      Color(0xFF4DDFED)
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${mins}m',
                      style: GoogleFonts.inter(
                          color: Colors.white54, fontSize: 11)),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms);
  }

  // ─── OVERVIEW CARDS ───────────────────────────────────────
  Widget _buildOverviewCards() {
    final cards = [
      {'label': 'Workouts', 'value': '$_totalWorkouts', 'unit': 'this month', 'icon': Icons.fitness_center, 'color': AppTheme.primary},
      {'label': 'Calories', 'value': '$_totalCaloriesBurned', 'unit': 'burned', 'icon': Icons.local_fire_department, 'color': Color(0xFFFF6B35)},
      {'label': 'Hours', 'value': _totalHours.toStringAsFixed(1), 'unit': 'trained', 'icon': Icons.timer_outlined, 'color': Color(0xFF04C7DD)},
      {'label': 'Streak', 'value': '$_currentStreak', 'unit': 'days', 'icon': Icons.bolt, 'color': Color(0xFFFFD700)},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: cards.asMap().entries.map((e) {
        final card = e.value;
        final color = card['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(card['icon'] as IconData, color: color, size: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card['value'] as String,
                      style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: 28,
                          letterSpacing: 1)),
                  Text(card['unit'] as String,
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(
            delay: Duration(milliseconds: 450 + e.key * 100),
            duration: 500.ms);
      }).toList(),
    );
  }

  // ─── WEIGHT PROGRESS ──────────────────────────────────────
  Widget _buildWeightChart() {
    final weights =
        _weightLogs.map((w) => (w['weight'] as num).toDouble()).toList();
    final recent =
        weights.length > 12 ? weights.sublist(weights.length - 12) : weights;

    return Container(
      width: double.infinity,
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
              Text('Weight Progress',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white, fontSize: 20, letterSpacing: 1)),
              GestureDetector(
                onTap: _showAddWeightSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded,
                          color: AppTheme.primary, size: 14),
                      const SizedBox(width: 4),
                      Text('Log',
                          style: GoogleFonts.inter(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.monitor_weight_outlined,
                        color: Colors.white12, size: 40),
                    const SizedBox(height: 10),
                    Text('No weight entries yet',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('Tap "Log" to record your weight',
                        style: GoogleFonts.inter(
                            color: Colors.white24, fontSize: 11)),
                  ],
                ),
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(recent.last.toStringAsFixed(1),
                    style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 36,
                        letterSpacing: 1)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text('kg',
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 13)),
                ),
                const Spacer(),
                if (recent.length > 1)
                  Builder(builder: (_) {
                    final delta = recent.last - recent.first;
                    final down = delta < 0;
                    final color = down
                        ? const Color(0xFFA3F900)
                        : delta > 0
                            ? const Color(0xFFFF6B35)
                            : Colors.white38;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            down
                                ? Icons.south_rounded
                                : delta > 0
                                    ? Icons.north_rounded
                                    : Icons.remove_rounded,
                            color: color,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text('${delta.abs().toStringAsFixed(1)} kg',
                              style: GoogleFonts.inter(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (_, __) => CustomPaint(
                  size: Size.infinite,
                  painter: _WeightChartPainter(
                    values: recent,
                    progress: _animCtrl.value,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Low ${recent.reduce((a, b) => a < b ? a : b).toStringAsFixed(1)} kg',
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 10)),
                Text('${recent.length} entries',
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 10)),
                Text(
                    'High ${recent.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} kg',
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 10)),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 550.ms, duration: 500.ms);
  }

  void _showAddWeightSheet() {
    final weightCtrl = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Log Weight',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white, fontSize: 24, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('Records today — one entry per day',
                  style: GoogleFonts.inter(
                      color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              _sheetField(weightCtrl, 'Weight (kg)',
                  Icons.monitor_weight_outlined, TextInputType.number),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final value = double.tryParse(
                              weightCtrl.text.replaceAll(',', '.'));
                          if (value == null || value <= 0) return;
                          setSheet(() => saving = true);
                          try {
                            final user = _supabase.auth.currentUser!;
                            final today = DateTime.now()
                                .toIso8601String()
                                .split('T')[0];
                            await _supabase.from('weight_logs').upsert({
                              'user_id': user.id,
                              'weight': value,
                              'logged_at': today,
                            }, onConflict: 'user_id,logged_at');
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _loadStats();
                          } catch (_) {
                            setSheet(() => saving = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('SAVE WEIGHT',
                          style: GoogleFonts.bebasNeue(
                              color: Colors.white,
                              fontSize: 18,
                              letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BODY METRICS ─────────────────────────────────────────
  Widget _buildBodyMetrics() {
    final metrics = [
      {'label': 'Weight', 'value': '—', 'unit': 'kg', 'change': '—', 'up': false},
      {'label': 'BMI', 'value': '—', 'unit': '', 'change': '—', 'up': false},
      {'label': 'Body Fat', 'value': '—', 'unit': '%', 'change': '—', 'up': false},
      {'label': 'Muscle', 'value': '—', 'unit': 'kg', 'change': '—', 'up': true},
    ];

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
              Text('Body Metrics',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 1)),
              Text('Coming Soon',
                  style: GoogleFonts.inter(
                      color: Colors.white24, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.85,
            children: metrics.map((m) {
              final isUp = m['up'] as bool;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m['label'] as String,
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 11)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(
                              text: m['value'] as String,
                              style: GoogleFonts.bebasNeue(
                                  color: Colors.white,
                                  fontSize: 22,
                                  letterSpacing: 1),
                            ),
                            TextSpan(
                              text: ' ${m['unit']}',
                              style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 11),
                            ),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(m['change'] as String,
                              style: GoogleFonts.inter(
                                color: Colors.white24,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 550.ms, duration: 500.ms);
  }

  // ─── ACHIEVEMENTS ─────────────────────────────────────────
  Widget _buildAchievements() {
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
          Text('Achievements',
              style: GoogleFonts.bebasNeue(
                  color: Colors.white, fontSize: 20, letterSpacing: 1)),
          const SizedBox(height: 16),
          ..._achievements.map((a) {
            // Check if unlocked
            bool unlocked = false;
            if (a['title'] == '10 Workouts') {
              unlocked = _totalWorkouts >= 10;
            } else if (a['title'] == '7 Day Streak') {
              unlocked = _currentStreak >= 7;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: unlocked
                          ? (a['color'] as Color).withOpacity(0.15)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(a['icon'] as IconData,
                        color: unlocked
                            ? a['color'] as Color
                            : Colors.white24,
                        size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['title'] as String,
                          style: GoogleFonts.inter(
                              color: unlocked
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(a['desc'] as String,
                          style: GoogleFonts.inter(
                              color: Colors.white24, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    unlocked
                        ? Icons.check_circle_rounded
                        : Icons.lock_outline_rounded,
                    color: unlocked
                        ? const Color(0xFFA3F900)
                        : Colors.white24,
                    size: 20,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 650.ms, duration: 500.ms);
  }

  // ─── ADD WORKOUT SHEET ────────────────────────────────────
  void _showAddWorkoutSheet() {
    final nameCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final caloriesCtrl = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add Workout',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 1)),
              const SizedBox(height: 16),
              _sheetField(
                  nameCtrl, 'Workout name', Icons.fitness_center),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _sheetField(durationCtrl, 'Duration (min)',
                        Icons.timer_outlined, TextInputType.number),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _sheetField(
                        caloriesCtrl,
                        'Calories burned',
                        Icons.local_fire_department,
                        TextInputType.number),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Auto-calc burned calories from MET table × profile weight × duration.
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final mins = int.tryParse(durationCtrl.text) ?? 0;
                    if (nameCtrl.text.trim().isEmpty || mins <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Enter workout name and duration first',
                            style: GoogleFonts.inter()),
                        backgroundColor: Colors.orange.shade800,
                        behavior: SnackBarBehavior.floating,
                      ));
                      return;
                    }
                    if (_userWeight == null || _userWeight! <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Set your weight in Profile first',
                            style: GoogleFonts.inter()),
                        backgroundColor: Colors.orange.shade800,
                        behavior: SnackBarBehavior.floating,
                      ));
                      return;
                    }
                    final cals = caloriesBurnedMet(
                      exerciseName: nameCtrl.text,
                      durationMinutes: mins,
                      weightKg: _userWeight,
                    );
                    setSheet(() => caloriesCtrl.text = '$cals');
                  },
                  icon: const Icon(Icons.auto_awesome,
                      color: AppTheme.primary, size: 16),
                  label: Text(
                    _userWeight != null
                        ? 'Auto-calc (your weight: ${_userWeight!.toStringAsFixed(1)} kg)'
                        : 'Auto-calc (set weight in Profile)',
                    style: GoogleFonts.inter(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppTheme.primary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                    final name = nameCtrl.text.trim();
                    final mins = int.tryParse(durationCtrl.text) ?? 0;
                    final cals = double.tryParse(caloriesCtrl.text) ?? 0;
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('Enter the workout name',
                            style: GoogleFonts.inter()),
                        backgroundColor: Colors.red.shade800,
                        behavior: SnackBarBehavior.floating,
                      ));
                      return;
                    }
                    if (mins <= 0 || mins > 600) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(
                            'Duration must be between 1 and 600 minutes',
                            style: GoogleFonts.inter()),
                        backgroundColor: Colors.red.shade800,
                        behavior: SnackBarBehavior.floating,
                      ));
                      return;
                    }
                    if (cals < 0 || cals > 10000) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(
                            'Calories must be a non-negative number',
                            style: GoogleFonts.inter()),
                        backgroundColor: Colors.red.shade800,
                        behavior: SnackBarBehavior.floating,
                      ));
                      return;
                    }
                    setSheet(() => saving = true);
                    try {
                      final user =
                      _supabase.auth.currentUser!;
                      final today = DateTime.now()
                          .toIso8601String()
                          .split('T')[0];
                      await _supabase
                          .from('workout_logs')
                          .insert({
                        'user_id': user.id,
                        'name': name,
                        'duration_minutes': mins,
                        'calories_burned': cals,
                        'workout_date': today,
                      });

                      // Surface the workout in the friends feed.
                      try {
                        await _supabase.from('activities').insert({
                          'user_id': user.id,
                          'type': 'workout',
                          'title': name,
                          'detail':
                              '$mins min · ${cals.toInt()} kcal',
                        });
                      } catch (_) {}

                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadStats();
                    } catch (e) {
                      setSheet(() => saving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: saving
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : Text('ADD WORKOUT',
                      style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: 18,
                          letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(
      TextEditingController ctrl,
      String hint,
      IconData icon, [
        TextInputType type = TextInputType.text,
      ]) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          GoogleFonts.inter(color: Colors.white30, fontSize: 13),
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

}

// ─── WEIGHT CHART PAINTER ─────────────────────────────────────
class _WeightChartPainter extends CustomPainter {
  final List<double> values;
  final double progress;

  _WeightChartPainter({required this.values, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;

    const topPad = 14.0;
    const bottomPad = 14.0;
    final chartH = size.height - topPad - bottomPad;
    final baseline = size.height - bottomPad;
    final stepX =
        values.length > 1 ? size.width / (values.length - 1) : 0.0;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final norm = (values[i] - minV) / range;
      final x = values.length > 1 ? stepX * i : size.width / 2;
      final fullY = topPad + chartH * (1 - norm);
      final y = baseline - (baseline - fullY) * progress;
      points.add(Offset(x, y));
    }

    const accent = Color(0xFFFF6B35);

    final fillPath = Path()..moveTo(points.first.dx, baseline);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, baseline);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withOpacity(0.35), accent.withOpacity(0.0)],
        ).createShader(Offset.zero & size),
    );

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF1A1A1A));
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) =>
      old.progress != progress || old.values != values;
}