import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

/// Admin Panel — visible to users whose `profiles.is_admin = true`.
/// All privileged actions go through the `admin-users` Edge Function,
/// which re-checks the caller's admin status server-side.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  late final String _myId;

  @override
  void initState() {
    super.initState();
    _myId = _supabase.auth.currentUser?.id ?? '';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'admin-users',
        body: {'action': 'list'},
      );
      if (res.status != 200 || res.data is! Map) {
        setState(() {
          _error = _friendly(res.data);
          _loading = false;
        });
        return;
      }
      final users = (res.data['users'] as List?) ?? [];
      setState(() {
        _users = users
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } on FunctionException catch (e) {
      setState(() {
        _error = _friendly(e.details) ?? 'Server error (${e.status})';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not reach the admin function.\n$e';
        _loading = false;
      });
    }
  }

  String? _friendly(dynamic data) {
    if (data is Map) {
      switch (data['error']) {
        case 'forbidden':
          return 'You do not have admin rights.';
        case 'unauthorized':
          return 'Session expired — sign in again.';
        case 'admin_check_failed':
          return 'Admin check failed: ${data['detail'] ?? ''}';
      }
      if (data['error'] is String) return data['error'] as String;
    }
    return null;
  }

  Future<void> _action(
    String label,
    String action,
    Map<String, dynamic> user, {
    Map<String, dynamic>? extraBody,
  }) async {
    final ok = await _confirm(label, user);
    if (ok != true) return;
    try {
      final res = await _supabase.functions.invoke(
        'admin-users',
        body: {
          'action': action,
          'userId': user['id'],
          ...?extraBody,
        },
      );
      final friendly = _friendly(res.data);
      if (res.status != 200 || friendly != null) {
        _toast(friendly ?? 'Action failed', error: true);
        return;
      }
      _toast('$label: ${user['email']}', error: false);
      await _load();
    } on FunctionException catch (e) {
      _toast(_friendly(e.details) ?? 'Server error (${e.status})',
          error: true);
    } catch (e) {
      _toast('Network error: $e', error: true);
    }
  }

  Future<bool?> _confirm(String label, Map<String, dynamic> u) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('$label?',
            style: GoogleFonts.bebasNeue(
                color: Colors.white, fontSize: 22, letterSpacing: 1)),
        content: Text(
          'User: ${u['email']}\n${u['full_name'] ?? ''}',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirm',
                style: GoogleFonts.inter(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {required bool error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor:
          error ? Colors.red.shade800 : Colors.green.shade800,
      behavior: SnackBarBehavior.floating,
    ));
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
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary))
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppTheme.primary,
                          backgroundColor: const Color(0xFF1A1A1A),
                          child: ListView.separated(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                                20, 0, 20, 32),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _userTile(_users[i]),
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
          onTap: () => context.go('/profile'),
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
                const Icon(Icons.shield_outlined,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 6),
                Text('Admin Panel',
                    style: GoogleFonts.bebasNeue(
                        color: Colors.white,
                        fontSize: 28,
                        letterSpacing: 2)),
              ],
            ),
            Text(
                _loading || _users.isEmpty
                    ? 'Manage users'
                    : '${_users.length} users',
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
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildError() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 28),
      child: Column(
        children: [
          const Icon(Icons.gpp_bad_outlined,
              color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          SelectableText(_error ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
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
    );
  }

  Widget _userTile(Map<String, dynamic> user) {
    final email = (user['email'] as String?) ?? '—';
    final name = (user['full_name'] as String?)?.trim();
    final isAdmin = user['is_admin'] == true;
    final bannedUntil = user['banned_until'] as String?;
    final isBanned = bannedUntil != null &&
        DateTime.tryParse(bannedUntil)?.isAfter(DateTime.now()) == true;
    final isSelf = user['id'] == _myId;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isBanned
              ? Colors.red.withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.15),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    (name?.isNotEmpty == true ? name![0] : email[0])
                        .toUpperCase(),
                    style: GoogleFonts.bebasNeue(
                        color: AppTheme.primary, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name?.isNotEmpty == true ? name! : '—',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          _chip('ADMIN', AppTheme.primary),
                        ],
                        if (isSelf) ...[
                          const SizedBox(width: 6),
                          _chip('YOU', Colors.blueAccent),
                        ],
                        if (isBanned) ...[
                          const SizedBox(width: 6),
                          _chip('BANNED', Colors.red),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(email,
                        style: GoogleFonts.inter(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              if (!isSelf)
                PopupMenuButton<String>(
                  iconColor: Colors.white54,
                  color: const Color(0xFF1A1A1A),
                  onSelected: (action) {
                    switch (action) {
                      case 'ban_24h':
                        _action('Ban 24 hours', 'ban', user,
                            extraBody: {'duration': '24h'});
                        break;
                      case 'ban_7d':
                        _action('Ban 7 days', 'ban', user,
                            extraBody: {'duration': '168h'});
                        break;
                      case 'ban_perma':
                        _action('Permanent ban', 'ban', user,
                            extraBody: {'duration': '876000h'});
                        break;
                      case 'unban':
                        _action('Unban', 'unban', user);
                        break;
                      case 'delete':
                        _action('Delete user', 'delete', user);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isBanned) ...[
                      _menu('ban_24h', Icons.timer_outlined,
                          'Ban for 24 hours', Colors.orangeAccent),
                      _menu('ban_7d', Icons.calendar_today_rounded,
                          'Ban for 7 days', Colors.orangeAccent),
                      _menu('ban_perma', Icons.block_rounded,
                          'Permanent ban', Colors.red),
                    ] else
                      _menu('unban', Icons.lock_open_rounded, 'Unban',
                          const Color(0xFFA3F900)),
                    _menu('delete', Icons.delete_forever_rounded,
                        'Delete forever', Colors.red),
                  ],
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  PopupMenuItem<String> _menu(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1)),
    );
  }
}
