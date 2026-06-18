// Smoke test for the app's design tokens. Full widget tests aren't useful
// here because most screens require a live Supabase connection, and the
// theme getter touches GoogleFonts which needs a Flutter binding.
// Unit tests for the pure helpers live in `test/calculations_test.dart`.
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbro_app/core/theme.dart';

void main() {
  test('AppTheme palette tokens are defined', () {
    expect(AppTheme.primary.value, isNonZero);
    expect(AppTheme.accent.value, isNonZero);
    expect(AppTheme.dark.value, isNonZero);
    expect(AppTheme.surface.value, isNonZero);
  });
}
