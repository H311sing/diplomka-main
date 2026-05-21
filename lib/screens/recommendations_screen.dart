import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  bool _loading = true;
  String? _error;
  String _summary = '';
  List<Map<String, dynamic>> _nutrition = [];
  List<Map<String, dynamic>> _exercises = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions
          .invoke('recommendations');
      final data = res.data;
      if (res.status != 200 || data is! Map || data['error'] != null) {
        setState(() {
          _error = _friendlyError(data);
          _loading = false;
        });
        return;
      }
      setState(() {
        _summary = (data['summary'] as String?)?.trim() ?? '';
        _nutrition = _asList(data['nutrition']);
        _exercises = _asList(data['exercises']);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not reach the AI service.\nIs the Edge Function '
            'running and the Gemini key set?';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _asList(dynamic v) {
    if (v is List) {
      return v.whereType<Map>().map((e) =>
          Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  String _friendlyError(dynamic data) {
    if (data is Map && data['error'] == 'GEMINI_API_KEY is not set') {
      return 'AI key is not configured on the server.\n'
          'Set GEMINI_API_KEY for the recommendations function.';
    }
    return 'The AI service returned an error. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? _buildLoading()
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppTheme.primary,
                          backgroundColor: const Color(0xFF1A1A1A),
                          child: ListView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 32),
                            children: [
                              if (_summary.isNotEmpty) _buildSummary(),
                              _buildSection(
                                'Nutrition',
                                Icons.restaurant_menu_rounded,
                                _nutrition,
                              ),
                              const SizedBox(height: 8),
                              _buildSection(
                                'Workout',
                                Icons.fitness_center,
                                _exercises,
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
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
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 6),
                Text('AI Coach',
                    style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 28,
                        letterSpacing: 2)),
              ],
            ),
            Text('Powered by Gemini',
                style:
                    GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
          ],
        ),
        const Spacer(),
        if (!_loading)
          GestureDetector(
            onTap: _load,
            child: const Icon(Icons.refresh_rounded,
                color: Colors.white38, size: 22),
          ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 16),
          Text('Analysing your data…',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Retry',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.primary.withOpacity(0.18),
          const Color(0xFFFF8C42).withOpacity(0.08),
        ]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_summary,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSection(
      String title, IconData icon, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(title.toUpperCase(),
                style: GoogleFonts.bebasNeue(
                    color: Colors.white, fontSize: 20, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((e) => _buildTipCard(e.value, e.key)),
      ],
    );
  }

  Widget _buildTipCard(Map<String, dynamic> tip, int i) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tip['title'] as String? ?? '',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          if ((tip['detail'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(tip['detail'] as String,
                style: GoogleFonts.inter(
                    color: Colors.white60, fontSize: 13, height: 1.35)),
          ],
        ],
      ),
    ).animate().fadeIn(
        delay: Duration(milliseconds: i * 70), duration: 350.ms);
  }
}
