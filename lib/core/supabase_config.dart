class SupabaseConfig {
  /// Switch the whole app between backends.
  ///   false → hosted Supabase cloud project
  ///   true  → local self-hosted Supabase running in Docker (`supabase start`)
  static const bool useLocalDocker = true;

  // ── Cloud project ──────────────────────────────────────────
  static const String _cloudUrl = 'https://dwflunjwgklcsrfyuork.supabase.co';
  static const String _cloudAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR3Zmx1bmp3Z2tsY3NyZnl1b3JrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg0MTMyMTAsImV4cCI6MjA5Mzk4OTIxMH0.khm2j2yTiEZsJysUGBfItduRiv1wat7j0TEYnBdt2Ls';

  // ── Local Docker (Supabase CLI) ────────────────────────────
  // The publishable key below is the shared default the Supabase CLI
  // prints on `supabase start` — it is a local dev key, not a secret.
  // Web / desktop reach the stack at 127.0.0.1; an Android emulator must
  // use 10.0.2.2 instead (it cannot see the host's localhost).
  static const String _localUrl = 'http://127.0.0.1:54321';
  static const String _localAnonKey =
      'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

  static String get supabaseUrl => useLocalDocker ? _localUrl : _cloudUrl;
  static String get supabaseAnonKey =>
      useLocalDocker ? _localAnonKey : _cloudAnonKey;
}
