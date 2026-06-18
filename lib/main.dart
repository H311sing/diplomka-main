import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'core/supabase_config.dart';
import 'core/theme.dart';
import 'core/notification_service.dart';
import 'core/steps_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/workout_plan_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/pose_counter_screen.dart';
import 'screens/admin_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await NotificationService.instance.init();
  // Start the pedometer listener. Fire-and-forget — it asks for
  // permission internally and degrades gracefully on unsupported
  // platforms.
  // ignore: unawaited_futures
  StepsService.instance.start();

  runApp(const GymBroApp());
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
    GoRoute(path: '/nutrition', builder: (_, __) => const NutritionScreen()),
    GoRoute(
        path: '/workout-plan', builder: (_, __) => const WorkoutPlanScreen()),
    GoRoute(
      path: '/friends',
      builder: (_, state) => FriendsScreen(
        initialTab: state.extra is int ? state.extra as int : 0,
      ),
    ),
    GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
    GoRoute(
        path: '/challenges', builder: (_, __) => const ChallengesScreen()),
    GoRoute(
      path: '/chat',
      builder: (_, state) {
        final friend = state.extra as Map<String, dynamic>?;
        if (friend == null) return const FriendsScreen();
        return ChatScreen(friend: friend);
      },
    ),
    GoRoute(
        path: '/recommendations',
        builder: (_, __) => const RecommendationsScreen()),
    GoRoute(
        path: '/pose-counter',
        builder: (_, __) => const PoseCounterScreen()),
    GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
  ],
);

class GymBroApp extends StatefulWidget {
  const GymBroApp({super.key});

  @override
  State<GymBroApp> createState() => _GymBroAppState();
}

class _GymBroAppState extends State<GymBroApp> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        _router.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GymBro',
      theme: AppTheme.theme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}