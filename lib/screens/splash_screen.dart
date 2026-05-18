import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    context.go(session != null ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [
                  AppTheme.primary,
                  Color(0xFFCC4400),
                ]),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.fitness_center,
                  color: Colors.white, size: 52),
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            Text('GYMBRO',
                style: GoogleFonts.bebasNeue(
                  fontSize: 52,
                  color: Colors.white,
                  letterSpacing: 8,
                ))
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.3, end: 0),
            Text('TRAIN. EAT. DOMINATE.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.primary,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                ))
                .animate()
                .fadeIn(delay: 700.ms, duration: 600.ms),
          ],
        ),
      ),
    );
  }
}