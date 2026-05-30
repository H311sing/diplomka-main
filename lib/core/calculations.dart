import 'dart:math' as math;

/// Pure-Dart helpers used by the UI. Kept side-effect-free so they can be
/// covered with unit tests in `test/calculations_test.dart`.

/// Body Mass Index = kg / m². Returns `null` if either input is missing
/// or non-positive.
double? calculateBmi(double? weightKg, double? heightCm) {
  if (weightKg == null || heightCm == null) return null;
  if (weightKg <= 0 || heightCm <= 0) return null;
  final m = heightCm / 100;
  return weightKg / (m * m);
}

/// Daily fitness score — mean completion of the three rings as a 0..100
/// integer. Each ratio is clamped to 100% so overachieving one ring can't
/// inflate the total.
int dailyScorePercent({
  required int caloriesBurned,
  required int targetCalories,
  required int workoutMinutes,
  required int targetMinutes,
  required int waterMl,
  required int targetWaterMl,
}) {
  if (targetCalories <= 0 || targetMinutes <= 0 || targetWaterMl <= 0) {
    return 0;
  }
  final m = (caloriesBurned / targetCalories).clamp(0.0, 1.0);
  final e = (workoutMinutes / targetMinutes).clamp(0.0, 1.0);
  final h = (waterMl / targetWaterMl).clamp(0.0, 1.0);
  return (((m + e + h) / 3) * 100).round();
}

/// User level from the monthly workout count. Every 10 workouts earns a
/// level; the floor is 1 (so a brand-new user is already "Lv. 1").
int levelFromWorkouts(int monthlyWorkouts) {
  if (monthlyWorkouts < 0) return 1;
  return (monthlyWorkouts ~/ 10) + 1;
}

/// Human-friendly "time ago" label. `now` is injectable for tests.
String timeAgo(DateTime dt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final d = reference.difference(dt);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${(d.inDays / 7).floor()}w ago';
}

/// Greeting based on local hour.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good Morning';
  if (now.hour < 17) return 'Good Afternoon';
  return 'Good Evening';
}

/// Angle at point `b` formed by points `a`, `b`, `c`, in degrees (0..180).
/// Used by the pose-detection rep counter to read the elbow angle.
double angleBetween(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
) {
  final ab = math.atan2(ay - by, ax - bx);
  final cb = math.atan2(cy - by, cx - bx);
  var deg = (ab - cb).abs() * 180 / math.pi;
  if (deg > 180) deg = 360 - deg;
  return deg;
}
