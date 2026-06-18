import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

class ChatScreen extends StatefulWidget {
  /// The friend to chat with — expects keys: id, full_name, avatar_url.
  final Map<String, dynamic> friend;
  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  late final String _uid;
  late final String _friendId;
  RealtimeChannel? _channel;

  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _uid = _supabase.auth.currentUser?.id ?? '';
    _friendId = widget.friend['id'] as String;
    _loadMessages();
    _subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) _supabase.removeChannel(_channel!);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _supabase
          .from('messages')
          .select()
          .or('and(sender_id.eq.$_uid,receiver_id.eq.$_friendId),'
              'and(sender_id.eq.$_friendId,receiver_id.eq.$_uid)')
          .order('created_at');
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _channel = _supabase
        .channel('chat:$_uid:$_friendId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final m = Map<String, dynamic>.from(payload.newRecord);
            final involves = (m['sender_id'] == _uid &&
                    m['receiver_id'] == _friendId) ||
                (m['sender_id'] == _friendId && m['receiver_id'] == _uid);
            if (!involves) return;
            if (_messages.any((x) => x['id'] == m['id'])) return;
            if (mounted) {
              setState(() => _messages.add(m));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      final inserted = await _supabase
          .from('messages')
          .insert({
            'sender_id': _uid,
            'receiver_id': _friendId,
            'content': text,
          })
          .select()
          .single();
      if (mounted && !_messages.any((x) => x['id'] == inserted['id'])) {
        setState(() => _messages.add(inserted));
        _scrollToBottom();
      }
    } catch (e) {
      _msgCtrl.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Message not sent', style: GoogleFonts.inter()),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _time(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (widget.friend['full_name'] as String?)?.trim().isNotEmpty == true
            ? widget.friend['full_name'] as String
            : 'Athlete';
    final avatarUrl = widget.friend['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(name, avatarUrl),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary))
                  : _messages.isEmpty
                      ? _buildEmptyState(name)
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _buildBubble(_messages[i]),
                        ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name, String? avatarUrl) {
    Widget fallback() => Center(
          child: Text(name[0].toUpperCase(),
              style:
                  GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18)),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border:
            Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/friends'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white60, size: 20),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primary, Color(0xFFCC4400)],
              ),
            ),
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? fallback()
                : ClipOval(
                    child: Image.network(avatarUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => fallback()),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: GoogleFonts.bebasNeue(
                    color: Colors.white, fontSize: 22, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> m) {
    final mine = m['sender_id'] == _uid;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: mine ? AppTheme.primary : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(m['content'] as String? ?? '',
                style: GoogleFonts.inter(
                    color: mine ? Colors.white : Colors.white,
                    fontSize: 14,
                    height: 1.3)),
            const SizedBox(height: 2),
            Text(_time(m['created_at'] as String? ?? ''),
                style: GoogleFonts.inter(
                    color: mine ? Colors.white70 : Colors.white38,
                    fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String name) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              color: Colors.white12, size: 56),
          const SizedBox(height: 16),
          Text('No messages yet',
              style: GoogleFonts.bebasNeue(
                  color: Colors.white54, fontSize: 22, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text('Say hi to $name 👋',
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border:
            Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle:
                      GoogleFonts.inter(color: Colors.white30, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
