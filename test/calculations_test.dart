// Unit tests for the pure helpers in `lib/core/calculations.dart`.
// Run with `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbro_app/core/calculations.dart';

void main() {
  group('calculateBmi', () {
    test('typical adult: 70 kg / 175 cm ≈ 22.9', () {
      final bmi = calculateBmi(70, 175);
      expect(bmi, isNotNull);
      expect(bmi!.toStringAsFixed(1), '22.9');
    });

    test('returns null when weight or height is missing', () {
      expect(calculateBmi(null, 175), isNull);
      expect(calculateBmi(70, null), isNull);
      expect(calculateBmi(null, null), isNull);
    });

    test('returns null for non-positive inputs', () {
      expect(calculateBmi(0, 175), isNull);
      expect(calculateBmi(70, 0), isNull);
      expect(calculateBmi(-1, 175), isNull);
    });

    test('low BMI: 50 kg / 180 cm', () {
      expect(calculateBmi(50, 180)!.toStringAsFixed(1), '15.4');
    });
  });

  group('dailyScorePercent', () {
    test('hitting all three targets gives 100%', () {
      expect(
        dailyScorePercent(
          caloriesBurned: 800,
          targetCalories: 800,
          workoutMinutes: 30,
          targetMinutes: 30,
          waterMl: 2500,
          targetWaterMl: 2500,
        ),
        100,
      );
    });

    test('half progress across the board gives 50%', () {
      expect(
        dailyScorePercent(
          caloriesBurned: 400,
          targetCalories: 800,
          workoutMinutes: 15,
          targetMinutes: 30,
          waterMl: 1250,
          targetWaterMl: 2500,
        ),
        50,
      );
    });

    test('overshooting a ring is capped at 100% per ring', () {
      // One ring at 4×, others at zero → 100/3 ≈ 33%, not above.
      expect(
        dailyScorePercent(
          caloriesBurned: 3200,
          targetCalories: 800,
          workoutMinutes: 0,
          targetMinutes: 30,
          waterMl: 0,
          targetWaterMl: 2500,
        ),
        33,
      );
    });

    test('zero progress everywhere gives 0', () {
      expect(
        dailyScorePercent(
          caloriesBurned: 0,
          targetCalories: 800,
          workoutMinutes: 0,
          targetMinutes: 30,
          waterMl: 0,
          targetWaterMl: 2500,
        ),
        0,
      );
    });

    test('guards against divide-by-zero (target = 0)', () {
      expect(
        dailyScorePercent(
          caloriesBurned: 100,
          targetCalories: 0,
          workoutMinutes: 10,
          targetMinutes: 30,
          waterMl: 500,
          targetWaterMl: 2500,
        ),
        0,
      );
    });
  });

  group('levelFromWorkouts', () {
    test('a brand-new account is already Lv. 1', () {
      expect(levelFromWorkouts(0), 1);
    });

    test('nine workouts still Lv. 1', () {
      expect(levelFromWorkouts(9), 1);
    });

    test('ten workouts unlocks Lv. 2', () {
      expect(levelFromWorkouts(10), 2);
    });

    test('twenty-five workouts is Lv. 3', () {
      expect(levelFromWorkouts(25), 3);
    });

    test('negative input clamped to Lv. 1', () {
      expect(levelFromWorkouts(-5), 1);
    });
  });

  group('timeAgo', () {
    final now = DateTime(2026, 1, 15, 12, 0, 0);

    test('< 1 minute → "just now"', () {
      expect(
        timeAgo(now.subtract(const Duration(seconds: 30)), now: now),
        'just now',
      );
    });

    test('minutes', () {
      expect(
        timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
    });

    test('hours', () {
      expect(
        timeAgo(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
    });

    test('days', () {
      expect(
        timeAgo(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
    });

    test('weeks', () {
      expect(
        timeAgo(now.subtract(const Duration(days: 15)), now: now),
        '2w ago',
      );
    });
  });

  group('greetingFor', () {
    test('morning before noon', () {
      expect(greetingFor(DateTime(2026, 1, 1, 8, 0)), 'Good Morning');
    });
    test('afternoon between 12 and 17', () {
      expect(greetingFor(DateTime(2026, 1, 1, 14, 0)), 'Good Afternoon');
    });
    test('evening at or after 17', () {
      expect(greetingFor(DateTime(2026, 1, 1, 17, 0)), 'Good Evening');
      expect(greetingFor(DateTime(2026, 1, 1, 22, 0)), 'Good Evening');
    });
    test('boundary: noon sharp is afternoon', () {
      expect(greetingFor(DateTime(2026, 1, 1, 12, 0)), 'Good Afternoon');
    });
  });

  group('angleBetween (elbow angle for the push-up counter)', () {
    test('three collinear points along a line → 180°', () {
      expect(angleBetween(0, 0, 1, 0, 2, 0).round(), 180);
    });

    test('right angle → 90°', () {
      // a above b, c right of b
      expect(angleBetween(0, 1, 0, 0, 1, 0).round(), 90);
    });

    test('45° angle', () {
      expect(angleBetween(1, 1, 0, 0, 1, 0).round(), 45);
    });

    test('result is always in [0, 180]', () {
      // Random-ish coords; nothing should ever exceed 180°.
      final cases = [
        [3.0, 4.0, 0.0, 0.0, -1.0, -2.0],
        [-5.0, 2.0, 1.0, 1.0, 3.0, -4.0],
        [10.0, -1.0, 0.0, 0.0, -10.0, 1.0],
      ];
      for (final c in cases) {
        final a = angleBetween(c[0], c[1], c[2], c[3], c[4], c[5]);
        expect(a, inInclusiveRange(0, 180));
      }
    });
  });
}
