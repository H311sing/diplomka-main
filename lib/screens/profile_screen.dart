import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../core/notification_service.dart';
import '../widgets/auth_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  bool _waterReminders = false;
  bool _workoutReminders = false;
  bool _isAdmin = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadReminderPrefs();
  }

  Future<void> _loadReminderPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _waterReminders = prefs.getBool('water_reminders') ?? false;
        _workoutReminders = prefs.getBool('workout_reminders') ?? false;
      });
    }
  }

  Future<void> _toggleWaterReminders(bool value) async {
    if (kIsWeb) {
      _showError('Reminders are available in the mobile app only');
      return;
    }
    if (value) {
      final granted =
          await NotificationService.instance.requestPermission();
      if (!granted) {
        _showError('Notification permission denied');
        return;
      }
      await NotificationService.instance.scheduleWaterReminders();
    } else {
      await NotificationService.instance.cancelWaterReminders();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('water_reminders', value);
    if (mounted) {
      setState(() => _waterReminders = value);
      _showSuccess(value
          ? 'Water reminders enabled'
          : 'Water reminders turned off');
    }
  }

  Future<void> _toggleWorkoutReminders(bool value) async {
    if (kIsWeb) {
      _showError('Reminders are available in the mobile app only');
      return;
    }
    if (value) {
      final granted =
          await NotificationService.instance.requestPermission();
      if (!granted) {
        _showError('Notification permission denied');
        return;
      }
      await NotificationService.instance.scheduleWorkoutReminder();
    } else {
      await NotificationService.instance.cancelWorkoutReminder();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('workout_reminders', value);
    if (mounted) {
      setState(() => _workoutReminders = value);
      _showSuccess(value
          ? 'Workout reminder enabled'
          : 'Workout reminder turned off');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        _nameCtrl.text = data['full_name'] ?? '';
        _weightCtrl.text = data['weight']?.toString() ?? '';
        _heightCtrl.text = data['height']?.toString() ?? '';
        _ageCtrl.text = data['age']?.toString() ?? '';
        setState(() {
          _avatarUrl = data['avatar_url'];
          _isAdmin = data['is_admin'] == true;
        });
      } else {
        _nameCtrl.text =
            user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? '';
      }
    } catch (e) {
      _showError('Failed to load profile');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,  // на вебе это открывает file picker
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() => _avatarBytes = bytes);

      // Upload to Supabase Storage
      final user = _supabase.auth.currentUser!;
      final fileName = '${user.id}/avatar.jpg';

      await _supabase.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final url = _supabase.storage.from('avatars').getPublicUrl(fileName);
      setState(() => _avatarUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}');

      _showSuccess('Avatar updated!');
    } catch (e) {
      _showError('Failed to upload avatar');
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final user = _supabase.auth.currentUser!;
      final weight = _weightCtrl.text.isNotEmpty
          ? double.tryParse(_weightCtrl.text.replaceAll(',', '.'))
          : null;
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': _nameCtrl.text.trim(),
        'weight': weight,
        'height': _heightCtrl.text.isNotEmpty
            ? double.tryParse(_heightCtrl.text)
            : null,
        'age': _ageCtrl.text.isNotEmpty ? int.tryParse(_ageCtrl.text) : null,
        'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Record a weight entry so the Stats chart can track progress.
      if (weight != null && weight > 0) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        await _supabase.from('weight_logs').upsert({
          'user_id': user.id,
          'weight': weight,
          'logged_at': today,
        }, onConflict: 'user_id,logged_at');
      }

      _showSuccess('Profile saved!');
    } catch (e) {
      _showError('Failed to save profile');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out',
            style: GoogleFonts.bebasNeue(
                color: Colors.white, fontSize: 24, letterSpacing: 1)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.inter(color: Colors.white60, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Out',
                style: GoogleFonts.inter(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.auth.signOut();
      if (mounted) context.go('/login');
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

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: Colors.green.shade800,
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 32),
              _buildAvatar(),
              const SizedBox(height: 32),
              _buildForm(),
              const SizedBox(height: 16),
              _buildRemindersCard(),
              if (_isAdmin) ...[
                const SizedBox(height: 16),
                _buildAdminCard(),
              ],
              const SizedBox(height: 24),
              _buildSaveButton(),
              const SizedBox(height: 16),
              _buildSignOutButton(),
              const SizedBox(height: 40),
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
        Text('Profile',
            style: GoogleFonts.bebasNeue(
                color: Colors.white, fontSize: 28, letterSpacing: 2)),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }

  Widget _buildAvatar() {
    final user = _supabase.auth.currentUser;
    final name = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'G';

    return Column(
      children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, Color(0xFFFF8C42)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: _avatarBytes != null
                    ? ClipOval(
                    child: Image.memory(_avatarBytes!,
                        fit: BoxFit.cover,
                        width: 110,
                        height: 110))
                    : _avatarUrl != null
                    ? ClipOval(
                  child: Image.network(
                    _avatarUrl!,
                    fit: BoxFit.cover,
                    width: 110,
                    height: 110,
                    errorBuilder: (_, __, ___) => _avatarPlaceholder(name),
                  ),
                )
                    : _avatarPlaceholder(name),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF0D0D0D), width: 2.5),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Your Name',
          style: GoogleFonts.bebasNeue(
              color: Colors.white, fontSize: 24, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          user?.email ?? '',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms, duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _avatarPlaceholder(String name) {
    return Center(
      child: Text(
        name[0].toUpperCase(),
        style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 44),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal Info',
                style: GoogleFonts.bebasNeue(
                    color: Colors.white, fontSize: 20, letterSpacing: 1)),
            const SizedBox(height: 20),
            _profileField(
              controller: _nameCtrl,
              hint: 'Full Name',
              icon: Icons.person_outline_rounded,
              onChanged: (_) => setState(() {}),
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _profileField(
                    controller: _ageCtrl,
                    hint: 'Age',
                    icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.positiveIntInRange(v,
                        min: 10, max: 120, label: 'Age'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _profileField(
                    controller: _weightCtrl,
                    hint: 'Weight (kg)',
                    icon: Icons.monitor_weight_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.positiveNumberInRange(v,
                        min: 20, max: 300, label: 'Weight'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _profileField(
              controller: _heightCtrl,
              hint: 'Height (cm)',
              icon: Icons.height_rounded,
              keyboardType: TextInputType.number,
              validator: (v) => Validators.positiveNumberInRange(v,
                  min: 50, max: 250, label: 'Height'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms);
  }

  Widget _profileField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        color: Colors.white.withOpacity(0.04),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: GoogleFonts.inter(
              color: Colors.redAccent.shade100,
              fontSize: 11,
              fontWeight: FontWeight.w500),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRemindersCard() {
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
          Text('Reminders',
              style: GoogleFonts.bebasNeue(
                  color: Colors.white, fontSize: 20, letterSpacing: 1)),
          const SizedBox(height: 8),
          _reminderRow(
            icon: Icons.water_drop_outlined,
            color: const Color(0xFF4285F4),
            title: 'Water Reminders',
            subtitle: 'Daily at 10:00 · 13:00 · 16:00 · 19:00',
            value: _waterReminders,
            onChanged: _toggleWaterReminders,
          ),
          Divider(color: Colors.white.withOpacity(0.06), height: 8),
          _reminderRow(
            icon: Icons.fitness_center,
            color: AppTheme.primary,
            title: 'Workout Reminder',
            subtitle: 'Daily at 18:00',
            value: _workoutReminders,
            onChanged: _toggleWorkoutReminders,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms, duration: 500.ms);
  }

  Widget _reminderRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard() {
    return GestureDetector(
      onTap: () => context.go('/admin'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B61FF), Color(0xFF4285F4)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B61FF).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
              child: const Icon(Icons.shield_outlined,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin Panel',
                      style: GoogleFonts.bebasNeue(
                          color: Colors.white,
                          fontSize: 22,
                          letterSpacing: 1)),
                  Text('Manage users · ban · delete',
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
    ).animate().fadeIn(delay: 380.ms, duration: 500.ms);
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5))
            : Text('SAVE CHANGES',
            style: GoogleFonts.bebasNeue(fontSize: 20, letterSpacing: 3)),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms);
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _signOut,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.withOpacity(0.4)),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: Colors.red,
        ),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text('SIGN OUT',
            style: GoogleFonts.bebasNeue(fontSize: 20, letterSpacing: 3)),
      ),
    ).animate().fadeIn(delay: 450.ms, duration: 500.ms);
  }
}