import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _searching = false;
  int _tab = 0; // 0 = Friends, 1 = Requests, 2 = Find
  late final String _uid;

  List<Map<String, dynamic>> _friendships = [];
  List<Map<String, dynamic>> _searchResults = [];

  static const List<String> _tabs = ['Friends', 'Requests', 'Find'];

  @override
  void initState() {
    super.initState();
    _uid = _supabase.auth.currentUser?.id ?? '';
    _loadFriendships();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriendships() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('friendships')
          .select('id, status, requester_id, addressee_id, '
              'requester:requester_id(id, full_name, avatar_url), '
              'addressee:addressee_id(id, full_name, avatar_url)')
          .or('requester_id.eq.$_uid,addressee_id.eq.$_uid')
          .order('created_at');
      if (mounted) {
        setState(() {
          _friendships = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Failed to load friends');
      }
    }
  }

  // ── Derived lists ──────────────────────────────────────────
  List<Map<String, dynamic>> get _friends =>
      _friendships.where((f) => f['status'] == 'accepted').toList();

  List<Map<String, dynamic>> get _incoming => _friendships
      .where((f) => f['status'] == 'pending' && f['addressee_id'] == _uid)
      .toList();

  List<Map<String, dynamic>> get _outgoing => _friendships
      .where((f) => f['status'] == 'pending' && f['requester_id'] == _uid)
      .toList();

  Map<String, dynamic>? _otherProfile(Map<String, dynamic> friendship) {
    final isRequester = friendship['requester_id'] == _uid;
    final raw = isRequester ? friendship['addressee'] : friendship['requester'];
    return raw == null ? null : Map<String, dynamic>.from(raw);
  }

  /// Relationship between the current user and [userId]:
  /// 'friend', 'requested', 'incoming' or 'none'.
  String _relation(String userId) {
    for (final f in _friendships) {
      final involves = (f['requester_id'] == userId &&
              f['addressee_id'] == _uid) ||
          (f['addressee_id'] == userId && f['requester_id'] == _uid);
      if (!involves) continue;
      if (f['status'] == 'accepted') return 'friend';
      return f['requester_id'] == _uid ? 'requested' : 'incoming';
    }
    return 'none';
  }

  Map<String, dynamic>? _friendshipWith(String userId) {
    for (final f in _friendships) {
      if ((f['requester_id'] == userId && f['addressee_id'] == _uid) ||
          (f['addressee_id'] == userId && f['requester_id'] == _uid)) {
        return f;
      }
    }
    return null;
  }

  // ── Actions ────────────────────────────────────────────────
  Future<void> _sendRequest(String userId) async {
    try {
      await _supabase.from('friendships').insert({
        'requester_id': _uid,
        'addressee_id': userId,
        'status': 'pending',
      });
      await _loadFriendships();
    } catch (e) {
      _showError('Could not send request');
    }
  }

  Future<void> _acceptRequest(String friendshipId) async {
    try {
      await _supabase
          .from('friendships')
          .update({'status': 'accepted'}).eq('id', friendshipId);
      await _loadFriendships();
    } catch (e) {
      _showError('Could not accept request');
    }
  }

  Future<void> _removeFriendship(String friendshipId) async {
    try {
      await _supabase.from('friendships').delete().eq('id', friendshipId);
      await _loadFriendships();
    } catch (e) {
      _showError('Action failed');
    }
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final data = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .ilike('full_name', '%$q%')
          .neq('id', _uid)
          .limit(20);
      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data);
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
        _showError('Search failed');
      }
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

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildTabs(),
                    const SizedBox(height: 16),
                    Expanded(child: _buildTabContent()),
                  ],
                ),
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
            Text('Friends',
                style: GoogleFonts.bebasNeue(
                    color: Colors.white, fontSize: 28, letterSpacing: 2)),
            Text('${_friends.length} gym bros',
                style:
                    GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _tabs.asMap().entries.map((e) {
          final selected = e.key == _tab;
          final isRequests = e.key == 1;
          final label = isRequests && _incoming.isNotEmpty
              ? '${e.value} (${_incoming.length})'
              : e.value;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: selected ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w400,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 1:
        return _buildRequestsTab();
      case 2:
        return _buildFindTab();
      default:
        return _buildFriendsTab();
    }
  }

  // ── Friends tab ────────────────────────────────────────────
  Widget _buildFriendsTab() {
    if (_friends.isEmpty) {
      return _emptyState(
        Icons.group_outlined,
        'No friends yet',
        'Use the Find tab to search and add gym bros',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFriendships,
      color: AppTheme.primary,
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final friendship = _friends[i];
          final profile = _otherProfile(friendship);
          return _userTile(
            profile: profile,
            trailing: _iconButton(
              icon: Icons.person_remove_outlined,
              color: Colors.red,
              onTap: () => _removeFriendship(friendship['id'] as String),
            ),
          ).animate().fadeIn(
              delay: Duration(milliseconds: i * 60), duration: 350.ms);
        },
      ),
    );
  }

  // ── Requests tab ───────────────────────────────────────────
  Widget _buildRequestsTab() {
    if (_incoming.isEmpty && _outgoing.isEmpty) {
      return _emptyState(
        Icons.mark_email_unread_outlined,
        'No pending requests',
        'Friend requests you send or receive show up here',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFriendships,
      color: AppTheme.primary,
      backgroundColor: const Color(0xFF1A1A1A),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_incoming.isNotEmpty) ...[
            _sectionLabel('INCOMING'),
            const SizedBox(height: 10),
            ..._incoming.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _userTile(
                    profile: _otherProfile(f),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _iconButton(
                          icon: Icons.check_rounded,
                          color: const Color(0xFFA3F900),
                          onTap: () => _acceptRequest(f['id'] as String),
                        ),
                        const SizedBox(width: 8),
                        _iconButton(
                          icon: Icons.close_rounded,
                          color: Colors.red,
                          onTap: () =>
                              _removeFriendship(f['id'] as String),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
          if (_outgoing.isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionLabel('SENT'),
            const SizedBox(height: 10),
            ..._outgoing.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _userTile(
                    profile: _otherProfile(f),
                    trailing: _pillButton(
                      label: 'Cancel',
                      color: Colors.white38,
                      onTap: () => _removeFriendship(f['id'] as String),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // ── Find tab ───────────────────────────────────────────────
  Widget _buildFindTab() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _search,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name',
              hintStyle:
                  GoogleFonts.inter(color: Colors.white30, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppTheme.primary, size: 20),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: Colors.white38, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _search('');
                      },
                    ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_searchCtrl.text.trim().isEmpty) {
      return _emptyState(
        Icons.search_rounded,
        'Find your gym bros',
        'Type a name to search for other users',
      );
    }
    if (_searchResults.isEmpty) {
      return _emptyState(
        Icons.person_off_outlined,
        'No users found',
        'Try a different name',
      );
    }
    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final profile = _searchResults[i];
        return _userTile(
          profile: profile,
          trailing: _searchAction(profile['id'] as String),
        );
      },
    );
  }

  Widget _searchAction(String userId) {
    switch (_relation(userId)) {
      case 'friend':
        return _pillButton(
            label: 'Friends', color: const Color(0xFFA3F900), onTap: null);
      case 'requested':
        return _pillButton(
            label: 'Requested', color: Colors.white38, onTap: null);
      case 'incoming':
        final f = _friendshipWith(userId);
        return _pillButton(
          label: 'Accept',
          color: AppTheme.primary,
          onTap: f == null ? null : () => _acceptRequest(f['id'] as String),
        );
      default:
        return _pillButton(
          label: 'Add',
          color: AppTheme.primary,
          filled: true,
          onTap: () => _sendRequest(userId),
        );
    }
  }

  // ── Shared widgets ─────────────────────────────────────────
  Widget _userTile({
    required Map<String, dynamic>? profile,
    required Widget trailing,
  }) {
    final name = (profile?['full_name'] as String?)?.trim();
    final displayName = (name == null || name.isEmpty) ? 'Athlete' : name;
    final avatarUrl = profile?['avatar_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          _avatar(displayName, avatarUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Text(displayName,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _avatar(String name, String? url) {
    Widget fallback() => Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'A',
            style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20),
          ),
        );
    return Container(
      width: 44,
      height: 44,
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
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback(),
              ),
            ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _sectionLabel(String text) {
    return Text(text,
        style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5));
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white12, size: 56),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.bebasNeue(
                  color: Colors.white54, fontSize: 22, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}
