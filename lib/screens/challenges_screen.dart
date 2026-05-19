import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final _supabase = Supabase.instance.client;
  late final String _uid;

  bool _loading = true;
  List<Map<String, dynamic>> _challenges = [];

  @override
  void initState() {
    super.initState();
    _uid = _supabase.auth.currentUser?.id ?? '';
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('challenges')
          .select('id, title, metric, starts_at, ends_at, creator_id, '
              'created_at, challenge_participants(user_id)')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _challenges = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Failed to load challenges');
      }
    }
  }

  // ── helpers ────────────────────────────────────────────────
  List<dynamic> _participants(Map<String, dynamic> c) =>
      (c['challenge_participants'] as List?) ?? const [];

  bool _joined(Map<String, dynamic> c) =>
      _participants(c).any((p) => p['user_id'] == _uid);

  String _metricLabel(String m) => switch (m) {
        'minutes' => 'Workout minutes',
        'calories' => 'Calories burned',
        _ => 'Workouts',
      };

  String _scoreLabel(String m, num s) => switch (m) {
        'minutes' => '${s.toInt()} min',
        'calories' => '${s.toInt()} kcal',
        _ => '${s.toInt()}',
      };

  IconData _metricIcon(String m) => switch (m) {
        'minutes' => Icons.timer_outlined,
        'calories' => Icons.local_fire_department,
        _ => Icons.fitness_center,
      };

  String _status(Map<String, dynamic> c) {
    final now = DateTime.now();
    final start = DateTime.tryParse(c['starts_at'] as String? ?? '');
    final end = DateTime.tryParse(c['ends_at'] as String? ?? '');
    if (start == null || end == null) return 'Active';
    if (now.isBefore(start)) return 'Upcoming';
    if (now.isAfter(end.add(const Duration(days: 1)))) return 'Ended';
    return 'Active';
  }

  String _dateRange(Map<String, dynamic> c) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final s = DateTime.tryParse(c['starts_at'] as String? ?? '');
    final e = DateTime.tryParse(c['ends_at'] as String? ?? '');
    if (s == null || e == null) return '';
    return '${months[s.month - 1]} ${s.day} – ${months[e.month - 1]} ${e.day}';
  }

  // ── actions ────────────────────────────────────────────────
  Future<void> _join(Map<String, dynamic> c) async {
    try {
      await _supabase.from('challenge_participants').insert({
        'challenge_id': c['id'],
        'user_id': _uid,
      });
      await _loadChallenges();
    } catch (e) {
      _showError('Could not join challenge');
    }
  }

  Future<void> _leave(Map<String, dynamic> c) async {
    try {
      await _supabase
          .from('challenge_participants')
          .delete()
          .eq('challenge_id', c['id'])
          .eq('user_id', _uid);
      await _loadChallenges();
    } catch (e) {
      _showError('Action failed');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: Colors.red.shade800,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildHeader(),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _challenges.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadChallenges,
                            color: AppTheme.primary,
                            backgroundColor: const Color(0xFF1A1A1A),
                            child: ListView.separated(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  20, 0, 20, 32),
                              itemCount: _challenges.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) => _buildCard(
                                      _challenges[i])
                                  .animate()
                                  .fadeIn(
                                      delay: Duration(
                                          milliseconds: i * 60),
                                      duration: 350.ms),
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Challenge',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => context.go('/feed'),
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
            Text('Challenges',
                style: GoogleFonts.bebasNeue(
                    color: Colors.white, fontSize: 28, letterSpacing: 2)),
            Text('Compete with your gym bros',
                style:
                    GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.emoji_events_outlined,
            color: Colors.white12, size: 64),
        const SizedBox(height: 16),
        Text('No challenges yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.bebasNeue(
                color: Colors.white54, fontSize: 24, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text('Create one and invite your friends to compete',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> c) {
    final metric = (c['metric'] as String?) ?? 'workouts';
    final joined = _joined(c);
    final count = _participants(c).length;
    final status = _status(c);
    final isMine = c['creator_id'] == _uid;

    final statusColor = switch (status) {
      'Active' => const Color(0xFFA3F900),
      'Upcoming' => const Color(0xFF04C7DD),
      _ => Colors.white38,
    };

    return GestureDetector(
      onTap: () => _showLeaderboard(c),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_metricIcon(metric),
                      color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['title'] as String? ?? '',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_metricLabel(metric),
                          style: GoogleFonts.inter(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.toUpperCase(),
                      style: GoogleFonts.inter(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    color: Colors.white24, size: 13),
                const SizedBox(width: 6),
                Text(_dateRange(c),
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 12)),
                const SizedBox(width: 14),
                const Icon(Icons.group_rounded,
                    color: Colors.white24, size: 13),
                const SizedBox(width: 6),
                Text('$count',
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 12)),
                const Spacer(),
                if (isMine)
                  Text('Yours',
                      style: GoogleFonts.inter(
                          color: Colors.white24,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))
                else if (joined)
                  _pill('Leave', Colors.white38, () => _leave(c))
                else
                  _pill('Join', AppTheme.primary, () => _join(c),
                      filled: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color, VoidCallback onTap,
      {bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(filled ? 1 : 0.4)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                color: filled ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── leaderboard sheet ──────────────────────────────────────
  void _showLeaderboard(Map<String, dynamic> c) {
    final metric = (c['metric'] as String?) ?? 'workouts';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
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
              Text(c['title'] as String? ?? '',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white, fontSize: 24, letterSpacing: 1)),
              Text('${_metricLabel(metric)} · ${_dateRange(c)}',
                  style: GoogleFonts.inter(
                      color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _fetchLeaderboard(c['id'] as String),
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary));
                    }
                    final rows = snap.data ?? [];
                    if (rows.isEmpty) {
                      return Center(
                        child: Text('No standings yet',
                            style: GoogleFonts.inter(
                                color: Colors.white38, fontSize: 13)),
                      );
                    }
                    return ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _leaderboardRow(i, rows[i], metric),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<dynamic>> _fetchLeaderboard(String challengeId) async {
    try {
      final res = await _supabase.rpc('challenge_leaderboard',
          params: {'p_challenge': challengeId});
      return res as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  Widget _leaderboardRow(int index, Map<String, dynamic> row, String metric) {
    final rank = index + 1;
    final isMe = row['member_id'] == _uid;
    final name = (row['member_name'] as String?)?.trim();
    final displayName =
        (name == null || name.isEmpty) ? 'Athlete' : name;
    final score = (row['score'] as num?) ?? 0;

    final medal = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => Colors.white24,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppTheme.primary.withOpacity(0.1)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? AppTheme.primary.withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: rank <= 3
                ? Icon(Icons.emoji_events_rounded, color: medal, size: 20)
                : Text('$rank',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bebasNeue(
                        color: Colors.white38, fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primary, Color(0xFFCC4400)],
              ),
            ),
            child: Center(
              child: Text(
                displayName[0].toUpperCase(),
                style: GoogleFonts.bebasNeue(
                    color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(isMe ? '$displayName (you)' : displayName,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          Text(_scoreLabel(metric, score),
              style: GoogleFonts.bebasNeue(
                  color: AppTheme.primary,
                  fontSize: 18,
                  letterSpacing: 1)),
        ],
      ),
    );
  }

  // ── create sheet ───────────────────────────────────────────
  void _showCreateSheet() {
    final titleCtrl = TextEditingController();
    String metric = 'workouts';
    int durationDays = 7;
    bool saving = false;

    const metrics = {
      'workouts': 'Workouts',
      'minutes': 'Minutes',
      'calories': 'Calories',
    };
    const durations = {7: '1 week', 14: '2 weeks', 30: '1 month'};

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
              Text('New Challenge',
                  style: GoogleFonts.bebasNeue(
                      color: Colors.white, fontSize: 24, letterSpacing: 1)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: titleCtrl,
                  style:
                      GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Challenge name',
                    hintStyle: GoogleFonts.inter(
                        color: Colors.white30, fontSize: 13),
                    prefixIcon: const Icon(Icons.emoji_events_outlined,
                        color: AppTheme.primary, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Metric',
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: metrics.entries.map((e) {
                  final sel = e.key == metric;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setSheet(() => metric = e.key),
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
                        child: Text(e.value,
                            style: GoogleFonts.inter(
                                color:
                                    sel ? Colors.white : Colors.white54,
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text('Duration',
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: durations.entries.map((e) {
                  final sel = e.key == durationDays;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setSheet(() => durationDays = e.key),
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
                        child: Text(e.value,
                            style: GoogleFonts.inter(
                                color:
                                    sel ? Colors.white : Colors.white54,
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                      ),
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
                          if (titleCtrl.text.trim().isEmpty) return;
                          setSheet(() => saving = true);
                          try {
                            final now = DateTime.now();
                            final end = now.add(
                                Duration(days: durationDays - 1));
                            await _supabase.from('challenges').insert({
                              'creator_id': _uid,
                              'title': titleCtrl.text.trim(),
                              'metric': metric,
                              'starts_at':
                                  now.toIso8601String().split('T')[0],
                              'ends_at':
                                  end.toIso8601String().split('T')[0],
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _loadChallenges();
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
                      : Text('CREATE CHALLENGE',
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
}
