import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _supabase = Supabase.instance.client;
  late final String _uid;

  bool _loading = true;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _uid = _supabase.auth.currentUser?.id ?? '';
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('activities')
          .select('id, type, title, detail, created_at, user_id, '
              'author:user_id(id, full_name, avatar_url), '
              'activity_likes(user_id)')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _activities = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Failed to load feed');
      }
    }
  }

  List<dynamic> _likes(Map<String, dynamic> a) =>
      (a['activity_likes'] as List?) ?? const [];

  bool _likedByMe(Map<String, dynamic> a) =>
      _likes(a).any((l) => l['user_id'] == _uid);

  Future<void> _toggleLike(Map<String, dynamic> a) async {
    final liked = _likedByMe(a);
    final likes = (a['activity_likes'] as List?) ?? [];
    a['activity_likes'] = likes;

    setState(() {
      if (liked) {
        likes.removeWhere((l) => l['user_id'] == _uid);
      } else {
        likes.add({'user_id': _uid});
      }
    });

    try {
      if (liked) {
        await _supabase
            .from('activity_likes')
            .delete()
            .eq('activity_id', a['id'])
            .eq('user_id', _uid);
      } else {
        await _supabase
            .from('activity_likes')
            .insert({'activity_id': a['id'], 'user_id': _uid});
      }
    } catch (e) {
      // Revert the optimistic change on failure.
      if (mounted) {
        setState(() {
          if (liked) {
            likes.add({'user_id': _uid});
          } else {
            likes.removeWhere((l) => l['user_id'] == _uid);
          }
        });
      }
    }
  }

  String _timeAgo(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${(d.inDays / 7).floor()}w ago';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'pr':
        return Icons.emoji_events_rounded;
      case 'weight':
        return Icons.monitor_weight_outlined;
      default:
        return Icons.fitness_center;
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
                    child: _activities.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadFeed,
                            color: AppTheme.primary,
                            backgroundColor: const Color(0xFF1A1A1A),
                            child: ListView.separated(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  20, 0, 20, 32),
                              itemCount: _activities.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) => _buildCard(
                                      _activities[i], i)
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
            Text('Feed',
                style: GoogleFonts.bebasNeue(
                    color: Colors.white, fontSize: 28, letterSpacing: 2)),
            Text('You and your gym bros',
                style:
                    GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => context.go('/challenges'),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: const Icon(Icons.emoji_events_outlined,
                color: AppTheme.primary, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => context.go('/friends'),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: const Icon(Icons.group_outlined,
                color: AppTheme.primary, size: 20),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.dynamic_feed_outlined,
            color: Colors.white12, size: 64),
        const SizedBox(height: 16),
        Text('No activity yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.bebasNeue(
                color: Colors.white54, fontSize: 24, letterSpacing: 1)),
        const SizedBox(height: 6),
        Text('Log a workout or add friends to fill the feed',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> a, int index) {
    final author = a['author'] as Map<String, dynamic>?;
    final name = (author?['full_name'] as String?)?.trim();
    final displayName = (name == null || name.isEmpty) ? 'Athlete' : name;
    final avatarUrl = author?['avatar_url'] as String?;
    final isMine = a['user_id'] == _uid;
    final type = (a['type'] as String?) ?? 'workout';
    final likeCount = _likes(a).length;
    final liked = _likedByMe(a);

    return Container(
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
              _avatar(displayName, avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMine ? 'You' : displayName,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(_timeAgo(a['created_at'] as String? ?? ''),
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(type.toUpperCase(),
                    style: GoogleFonts.inter(
                        color: AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_typeIcon(type),
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['title'] as String? ?? '',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if ((a['detail'] as String?)?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(a['detail'] as String,
                          style: GoogleFonts.inter(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleLike(a),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: liked
                            ? const Color(0xFFFF2D55)
                            : Colors.white38,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        likeCount == 0 ? 'Like' : '$likeCount',
                        style: GoogleFonts.inter(
                          color: liked
                              ? const Color(0xFFFF2D55)
                              : Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name, String? url) {
    Widget fallback() => Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'A',
            style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18),
          ),
        );
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppTheme.primary, Color(0xFFCC4400)],
        ),
      ),
      child: (url == null || url.isEmpty)
          ? fallback()
          : ClipOval(
              child: Image.network(
                url,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback(),
              ),
            ),
    );
  }
}
