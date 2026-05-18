import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import '../core/theme.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  late VideoPlayerController _videoCtrl;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _videoCtrl = VideoPlayerController.networkUrl(
      Uri.parse(
        'https://dwflunjwgklcsrfyuork.supabase.co/storage/v1/object/public/gymbro2/gymbro.mp4',
      ),
    )
      ..setLooping(true)
      ..setVolume(0);
    await _videoCtrl.initialize();
    await _videoCtrl.play();
    if (mounted) setState(() => _videoReady = true);
  }

  @override
  void dispose() {
    _videoCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      _showError('Passwords do not match');
      return;
    }
    if (_passCtrl.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        data: {'full_name': _nameCtrl.text.trim()},
      );
      if (res.user != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': res.user!.id,
          'full_name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Account created! Check your email to confirm.',
                  style: GoogleFonts.inter()),
              backgroundColor: Colors.green.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) context.go('/login');
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoCtrl.value.size.width,
                height: _videoCtrl.value.size.height,
                child: VideoPlayer(_videoCtrl),
              ),
            ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                  ).animate().fadeIn(),

                  const SizedBox(height: 24),

                  Text('JOIN THE\nGYMBRO\nFAMILY',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 52,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: 2,
                      ))
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .slideY(begin: 0.3),

                  const SizedBox(height: 8),
                  Text('Start your transformation today 💪',
                      style: GoogleFonts.inter(
                          color: Colors.white60, fontSize: 14))
                      .animate()
                      .fadeIn(delay: 250.ms),

                  const SizedBox(height: 36),

                  AuthTextField(
                    controller: _nameCtrl,
                    hint: 'Full name',
                    icon: Icons.person_outline_rounded,
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.2),

                  const SizedBox(height: 14),

                  AuthTextField(
                    controller: _emailCtrl,
                    hint: 'Email address',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2),

                  const SizedBox(height: 14),

                  AuthTextField(
                    controller: _passCtrl,
                    hint: 'Password (min 6 characters)',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white38,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ).animate().fadeIn(delay: 530.ms).slideY(begin: 0.2),

                  const SizedBox(height: 14),

                  AuthTextField(
                    controller: _confirmCtrl,
                    hint: 'Confirm password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                          : Text('CREATE ACCOUNT',
                          style: GoogleFonts.bebasNeue(
                              fontSize: 20, letterSpacing: 3)),
                    ),
                  ).animate().fadeIn(delay: 680.ms),

                  const SizedBox(height: 28),

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ',
                            style: GoogleFonts.inter(
                                color: Colors.white54, fontSize: 14)),
                        GestureDetector(
                          onTap: () => context.go('/login'),
                          child: Text('Log In',
                              style: GoogleFonts.inter(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              )),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 750.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}