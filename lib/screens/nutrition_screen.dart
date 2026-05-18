import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen>
    with TickerProviderStateMixin {
  late AnimationController _animCtrl;
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  int _selectedMeal = 0;
  final List<String> _mealTypes = ['All', 'Breakfast', 'Lunch', 'Dinner', 'Snack'];

  List<Map<String, dynamic>> _meals = [];
  int _waterMl = 0;
  final int _targetCalories = 2400;
  final int _targetProtein = 150;
  final int _targetCarbs = 280;
  final int _targetFat = 80;
  final int _targetWater = 2500;

  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final today = DateTime.now().toIso8601String().split('T')[0];

    try {
      // Load meals
      final meals = await _supabase
          .from('nutrition_logs')
          .select()
          .eq('user_id', user.id)
          .eq('meal_date', today)
          .order('created_at');

      // Load water
      final water = await _supabase
          .from('water_logs')
          .select('amount_ml')
          .eq('user_id', user.id)
          .eq('log_date', today);

      final totalWater = water.fold<double>(
          0, (sum, w) => sum + (w['amount_ml'] as num).toDouble());

      if (mounted) {
        setState(() {
          _meals = List<Map<String, dynamic>>.from(meals);
          _waterMl = totalWater.toInt();
          _loading = false;
        });
        _animCtrl.forward(from: 0);
        _ringCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalCalories =>
      _meals.fold(0, (s, m) => s + (m['calories'] as num).toInt());
  int get _totalProtein =>
      _meals.fold(0, (s, m) => s + (m['protein'] as num).toInt());
  int get _totalCarbs =>
      _meals.fold(0, (s, m) => s + (m['carbs'] as num).toInt());
  int get _totalFat =>
      _meals.fold(0, (s, m) => s + (m['fat'] as num).toInt());

  List<Map<String, dynamic>> get _filteredMeals {
    if (_selectedMeal == 0) return _meals;
    final type = _mealTypes[_selectedMeal];
    return _meals
        .where((m) => (m['meal_type'] as String).toLowerCase() ==
        type.toLowerCase())
        .toList();
  }

  Future<void> _addWater(int ml) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _supabase.from('water_logs').insert({
      'user_id': user.id,
      'amount_ml': ml,
      'log_date': today,
    });
    setState(() => _waterMl += ml);
  }

  Future<void> _deleteMeal(String id) async {
    await _supabase.from('nutrition_logs').delete().eq('id', id);
    await _loadData();
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
          onRefresh: _loadData,
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
                _buildCaloriesRing(),
                const SizedBox(height: 24),
                _buildMacros(),
                const SizedBox(height: 24),
                _buildWaterTracker(),
                const SizedBox(height: 24),
                _buildMealFilter(),
                const SizedBox(height: 16),
                _buildMealList(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMealSheet,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Meal',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final months = ['JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC'];
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
            Text('Nutrition',
                style: GoogleFonts.bebasNeue(
                    color: Colors.white, fontSize: 28, letterSpacing: 2)),
            Text('${months[now.month-1]} ${now.day}, ${now.year}',
                style: GoogleFonts.inter(
                    color: Colors.white38, fontSize: 12)),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: _loadData,
          child: const Icon(Icons.refresh_rounded,
              color: Colors.white38, size: 22),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildCaloriesRing() {
    final progress = _targetCalories > 0
        ? (_totalCalories / _targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final remaining = _targetCalories - _totalCalories;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _ringCtrl,
                  builder: (_, __) => CustomPaint(
                    size: const Size(110, 110),
                    painter: _RingPainter(
                      progress: progress * _ringCtrl.value,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$_totalCalories',
                        style: GoogleFonts.bebasNeue(
                            color: Colors.white,
                            fontSize: 24,
                            letterSpacing: 1)),
                    Text('kcal',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _calorieRow('Eaten', '$_totalCalories kcal', AppTheme.primary),
                const SizedBox(height: 8),
                _calorieRow('Goal', '$_targetCalories kcal', Colors.white38),
                const SizedBox(height: 8),
                _calorieRow(
                  remaining >= 0 ? 'Remaining' : 'Over',
                  '${remaining.abs()} kcal',
                  remaining >= 0 ? const Color(0xFFA3F900) : Colors.red,
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedBuilder(
                    animation: _ringCtrl,
                    builder: (_, __) => LinearProgressIndicator(
                      value: progress * _ringCtrl.value,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primary),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 500.ms);
  }

  Widget _calorieRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
        Text(value,
            style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildMacros() {
    final macros = [
      {'label': 'Protein', 'current': _totalProtein, 'target': _targetProtein, 'unit': 'g', 'color': const Color(0xFF04C7DD)},
      {'label': 'Carbs', 'current': _totalCarbs, 'target': _targetCarbs, 'unit': 'g', 'color': const Color(0xFFFFD700)},
      {'label': 'Fat', 'current': _totalFat, 'target': _targetFat, 'unit': 'g', 'color': const Color(0xFFA3F900)},
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
          Text('Macronutrients',
              style: GoogleFonts.bebasNeue(
                  color: Colors.white, fontSize: 20, letterSpacing: 1)),
          const SizedBox(height: 16),
          Row(
            children: macros.map((m) {
              final ratio = _targetCalories > 0
                  ? ((m['current'] as int) / (m['target'] as int))
                  .clamp(0.0, 1.0)
                  : 0.0;
              final color = m['color'] as Color;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _ringCtrl,
                              builder: (_, __) => CustomPaint(
                                size: const Size(70, 70),
                                painter: _RingPainter(
                                  progress: ratio * _ringCtrl.value,
                                  color: color,
                                  strokeWidth: 6,
                                ),
                              ),
                            ),
                            Text('${m['current']}',
                                style: GoogleFonts.bebasNeue(
                                    color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(m['label'] as String,
                          style: GoogleFonts.inter(
                              color: Colors.white54, fontSize: 11)),
                      Text(
                          '${m['current']}/${m['target']}${m['unit']}',
                          style: GoogleFonts.inter(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms, duration: 500.ms);
  }

  Widget _buildWaterTracker() {
    final ratio = (_waterMl / _targetWater).clamp(0.0, 1.0);
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
              Text('Hydration',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 1)),
              Text('$_waterMl / $_targetWater ml',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF4285F4),
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4285F4)),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [150, 250, 350, 500].map((ml) {
              return GestureDetector(
                onTap: () => _addWater(ml),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF4285F4).withOpacity(0.3)),
                  ),
                  child: Text('+${ml}ml',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF4285F4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms, duration: 500.ms);
  }

  Widget _buildMealFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _mealTypes.asMap().entries.map((e) {
          final selected = e.key == _selectedMeal;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedMeal = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Text(e.value,
                    style: GoogleFonts.inter(
                      color: selected ? Colors.white : Colors.white54,
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
    );
  }

  Widget _buildMealList() {
    if (_filteredMeals.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.restaurant_menu_rounded,
                  color: Colors.white12, size: 48),
              const SizedBox(height: 12),
              Text('No meals yet',
                  style: GoogleFonts.inter(
                      color: Colors.white38, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Tap + Add Meal to get started',
                  style: GoogleFonts.inter(
                      color: Colors.white24, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _filteredMeals.asMap().entries.map((e) {
        final meal = e.value;
        final mealType = meal['meal_type'] as String;
        final emoji = mealType == 'Breakfast'
            ? '🥣'
            : mealType == 'Lunch'
            ? '🍗'
            : mealType == 'Dinner'
            ? '🐟'
            : '🥤';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: Key(meal['id'].toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.delete_rounded,
                  color: Colors.red, size: 24),
            ),
            onDismissed: (_) => _deleteMeal(meal['id'].toString()),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border:
                Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meal['meal_name'] as String,
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          'P:${meal['protein']}g  C:${meal['carbs']}g  F:${meal['fat']}g',
                          style: GoogleFonts.inter(
                              color: Colors.white38, fontSize: 11),
                        ),
                        Text(mealType,
                            style: GoogleFonts.inter(
                                color: Colors.white24,
                                fontSize: 10)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          '${(meal['calories'] as num).toInt()} kcal',
                          style: GoogleFonts.bebasNeue(
                              color: AppTheme.primary,
                              fontSize: 18,
                              letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(
              delay: Duration(milliseconds: e.key * 80),
              duration: 400.ms),
        );
      }).toList(),
    );
  }

  void _showAddMealSheet() {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final protCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    String selectedType = 'Breakfast';
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
              Text('Add Meal',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 1)),
              const SizedBox(height: 16),
              _sheetField(nameCtrl, 'Meal name',
                  Icons.restaurant_menu_rounded),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _sheetField(calCtrl, 'Calories',
                          Icons.local_fire_department,
                          TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _sheetField(protCtrl, 'Protein (g)',
                          Icons.fitness_center,
                          TextInputType.number)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _sheetField(carbCtrl, 'Carbs (g)',
                          Icons.grain, TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _sheetField(fatCtrl, 'Fat (g)',
                          Icons.water_drop, TextInputType.number)),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                      .map((t) {
                    final sel = t == selectedType;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () =>
                            setSheet(() => selectedType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.primary
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(t,
                              style: GoogleFonts.inter(
                                  color: sel
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w400)),
                        ),
                      ),
                    );
                  }).toList(),
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
                    if (nameCtrl.text.isEmpty) return;
                    setSheet(() => saving = true);
                    try {
                      final user =
                      _supabase.auth.currentUser!;
                      final today = DateTime.now()
                          .toIso8601String()
                          .split('T')[0];
                      await _supabase
                          .from('nutrition_logs')
                          .insert({
                        'user_id': user.id,
                        'meal_name': nameCtrl.text.trim(),
                        'meal_type': selectedType,
                        'calories':
                        double.tryParse(calCtrl.text) ??
                            0,
                        'protein':
                        double.tryParse(protCtrl.text) ??
                            0,
                        'carbs':
                        double.tryParse(carbCtrl.text) ??
                            0,
                        'fat':
                        double.tryParse(fatCtrl.text) ??
                            0,
                        'meal_date': today,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadData();
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
                      : Text('ADD MEAL',
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

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border:
        Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.go('/home'),
            child: _navItem(Icons.home_rounded, 'Home', false),
          ),
          GestureDetector(
            onTap: () => context.go('/stats'),
            child: _navItem(Icons.bar_chart_rounded, 'Stats', false),
          ),
          GestureDetector(
            onTap: () => context.go('/workout-plan'),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFFFF8C42)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.white, size: 24),
            ),
          ),
          _navItem(Icons.restaurant_menu_rounded, 'Nutrition', true),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child:
            _navItem(Icons.person_outline_rounded, 'Profile', false),
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
            color: active ? AppTheme.primary : Colors.white30,
            size: 24),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(
              color: active ? AppTheme.primary : Colors.white30,
              fontSize: 10,
              fontWeight:
              active ? FontWeight.w700 : FontWeight.w400,
            )),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final bg = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      2 * 3.14159 * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}