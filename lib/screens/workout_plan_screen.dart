import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../widgets/dock_nav.dart';

class WorkoutPlanScreen extends StatefulWidget {
  const WorkoutPlanScreen({super.key});

  @override
  State<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends State<WorkoutPlanScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  List<Map<String, dynamic>> _exercises = [];

  static const List<String> _muscleGroups = [
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Core',
    'Cardio',
  ];

  static const Map<String, IconData> _groupIcons = {
    'Chest': Icons.fitness_center,
    'Back': Icons.sports_gymnastics,
    'Legs': Icons.directions_run,
    'Shoulders': Icons.sports_handball,
    'Arms': Icons.sports_mma,
    'Core': Icons.self_improvement,
    'Cardio': Icons.favorite,
  };

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _loading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('workout_exercises')
          .select()
          .eq('user_id', user.id)
          .order('created_at');
      if (mounted) {
        setState(() {
          _exercises = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleDone(Map<String, dynamic> exercise) async {
    final newValue = !(exercise['is_done'] as bool? ?? false);
    setState(() => exercise['is_done'] = newValue);
    try {
      await _supabase
          .from('workout_exercises')
          .update({'is_done': newValue}).eq('id', exercise['id']);
    } catch (_) {
      if (mounted) setState(() => exercise['is_done'] = !newValue);
    }
  }

  Future<void> _deleteExercise(String id) async {
    try {
      await _supabase.from('workout_exercises').delete().eq('id', id);
    } catch (_) {}
    await _loadExercises();
  }

  Future<void> _resetAll() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() {
      for (final e in _exercises) {
        e['is_done'] = false;
      }
    });
    try {
      await _supabase
          .from('workout_exercises')
          .update({'is_done': false}).eq('user_id', user.id);
    } catch (_) {}
  }

  int get _doneCount =>
      _exercises.where((e) => e['is_done'] as bool? ?? false).length;

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in _exercises) {
      final group = e['muscle_group'] as String? ?? 'Other';
      map.putIfAbsent(group, () => []).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final total = _exercises.length;
    final progress = total > 0 ? _doneCount / total : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadExercises,
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
                      _buildProgressCard(progress),
                      const SizedBox(height: 24),
                      if (_exercises.isEmpty)
                        _buildEmptyState()
                      else
                        ..._buildGroups(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Exercise',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: DockNav(
        items: DockNav.defaultItems(context),
        activeIndex: 2,
      ),
    );
  }

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
            Text('Workout Plan',
                style: GoogleFonts.bebasNeue(
                    color: Colors.white, fontSize: 28, letterSpacing: 2)),
            Text('Your training routine',
                style:
                    GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
          ],
        ),
        const Spacer(),
        if (_exercises.isNotEmpty)
          GestureDetector(
            onTap: _resetAll,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.refresh_rounded,
                      color: Colors.white54, size: 14),
                  const SizedBox(width: 4),
                  Text('Reset',
                      style: GoogleFonts.inter(
                          color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildProgressCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.18),
            const Color(0xFFFF8C42).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Progress",
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white, fontSize: 20, letterSpacing: 1)),
              Text('$_doneCount/${_exercises.length}',
                  style: GoogleFonts.bebasNeue(
                      color: AppTheme.primary,
                      fontSize: 22,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress >= 1.0 && _exercises.isNotEmpty
                ? 'All done — great work! 💪'
                : '${(progress * 100).toInt()}% complete',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(Icons.fitness_center, color: Colors.white12, size: 56),
          const SizedBox(height: 16),
          Text('No exercises yet',
              style: GoogleFonts.bebasNeue(
                  color: Colors.white54, fontSize: 22, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text('Tap "Add Exercise" to build your plan',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  List<Widget> _buildGroups() {
    final groups = _grouped;
    return groups.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_groupIcons[entry.key] ?? Icons.fitness_center,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(entry.key.toUpperCase(),
                    style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 2)),
                const SizedBox(width: 8),
                Text('${entry.value.length}',
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            ...entry.value.map(_buildExerciseTile),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildExerciseTile(Map<String, dynamic> exercise) {
    final done = exercise['is_done'] as bool? ?? false;
    final sets = exercise['sets'] ?? 0;
    final reps = exercise['reps'] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(exercise['id'].toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.red),
        ),
        onDismissed: (_) => _deleteExercise(exercise['id'].toString()),
        child: GestureDetector(
          onTap: () => _toggleDone(exercise),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: done
                  ? AppTheme.primary.withOpacity(0.08)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: done
                    ? AppTheme.primary.withOpacity(0.3)
                    : Colors.white.withOpacity(0.06),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: done ? AppTheme.primary : Colors.white24,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    exercise['name'] as String? ?? '',
                    style: GoogleFonts.inter(
                      color: done ? Colors.white60 : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$sets × $reps',
                      style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '10');
    String selectedGroup = _muscleGroups.first;
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
              Text('Add Exercise',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white, fontSize: 24, letterSpacing: 1)),
              const SizedBox(height: 16),
              _sheetField(nameCtrl, 'Exercise name', Icons.fitness_center),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _sheetField(setsCtrl, 'Sets',
                        Icons.repeat_rounded, TextInputType.number),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _sheetField(repsCtrl, 'Reps',
                        Icons.tag_rounded, TextInputType.number),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Muscle group',
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _muscleGroups.map((g) {
                  final sel = g == selectedGroup;
                  return GestureDetector(
                    onTap: () => setSheet(() => selectedGroup = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppTheme.primary
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? AppTheme.primary
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(g,
                          style: GoogleFonts.inter(
                              color: sel ? Colors.white : Colors.white54,
                              fontSize: 12,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w400)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setSheet(() => saving = true);
                          try {
                            final user = _supabase.auth.currentUser!;
                            await _supabase
                                .from('workout_exercises')
                                .insert({
                              'user_id': user.id,
                              'name': nameCtrl.text.trim(),
                              'sets':
                                  int.tryParse(setsCtrl.text) ?? 3,
                              'reps':
                                  int.tryParse(repsCtrl.text) ?? 10,
                              'muscle_group': selectedGroup,
                              'is_done': false,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _loadExercises();
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
                      : Text('ADD EXERCISE',
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

}
