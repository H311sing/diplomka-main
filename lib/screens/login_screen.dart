import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import '../core/supabase_config.dart';
import '../core/theme.dart';
import '../widgets/auth_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        // Web: browser-based OAuth redirect via Supabase. The Google
        // Cloud OAuth client must whitelist the callback URL.
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: '${SupabaseConfig.supabaseUrl}/auth/v1/callback',
        );
        return; // browser will redirect; nothing more to do here
      }

      // Mobile (Android/iOS): native Google Sign-In, then pass the
      // resulting ID token to Supabase.
      final googleSignIn =
          GoogleSignIn(serverClientId: SupabaseConfig.googleWebClientId);
      final account = await googleSignIn.signIn();
      if (account == null) {
        // User cancelled the account picker.
        if (mounted) setState(() => _loading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw 'Google did not return an ID token.';
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: auth.accessToken,
      );
      if (mounted) context.go('/home');
    } catch (e) {
      _showError(e.toString());
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
          // 🎬 Video BG
          if (_videoReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoCtrl.value.size.width,
                height: _videoCtrl.value.size.height,
                child: VideoPlayer(_videoCtrl),
              ),
            ),

          // Dark overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.85),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Logo
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.fitness_center,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GYMBRO',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 32,
                                color: Colors.white,
                                letterSpacing: 4,
                              )),
                          Text('TRAIN. EAT. DOMINATE.',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppTheme.primary,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),

                  const SizedBox(height: 60),

                  Text('WELCOME\nBACK',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 56,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: 2,
                      ))
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideY(begin: 0.3),

                  const SizedBox(height: 8),
                  Text('Log in and crush your goals today',
                      style: GoogleFonts.inter(
                          color: Colors.white60, fontSize: 14))
                      .animate()
                      .fadeIn(delay: 350.ms),

                  const SizedBox(height: 40),

                  AuthTextField(
                    controller: _emailCtrl,
                    hint: 'Email address',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2),

                  const SizedBox(height: 16),

                  AuthTextField(
                    controller: _passCtrl,
                    hint: 'Password',
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
                  ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.2),

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text('Forgot password?',
                          style: GoogleFonts.inter(
                              color: AppTheme.primary, fontSize: 13)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                          : Text('LOG IN',
                          style: GoogleFonts.bebasNeue(
                              fontSize: 20, letterSpacing: 3)),
                    ),
                  ).animate().fadeIn(delay: 650.ms),

                  const SizedBox(height: 28),

                  // Divider
                  Row(
                    children: [
                      const Expanded(
                          child: Divider(color: Colors.white12)),
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or continue with',
                            style: GoogleFonts.inter(
                                color: Colors.white38, fontSize: 12)),
                      ),
                      const Expanded(
                          child: Divider(color: Colors.white12)),
                    ],
                  ).animate().fadeIn(delay: 700.ms),

                  const SizedBox(height: 20),

                  // Google Sign In
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        foregroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  color: Color(0xFF4285F4),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('Sign in with Google',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 750.ms),

                  const SizedBox(height: 40),

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ",
                            style: GoogleFonts.inter(
                                color: Colors.white54, fontSize: 14)),
                        GestureDetector(
                          onTap: () => context.go('/register'),
                          child: Text('Sign Up',
                              style: GoogleFonts.inter(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              )),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 800.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}