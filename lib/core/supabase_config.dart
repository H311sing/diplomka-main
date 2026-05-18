class SupabaseConfig {
  /// Switch the whole app between backends.
  ///   false → hosted Supabase cloud project
  ///   true  → local self-hosted Supabase running in Docker (`supabase start`)
  static const bool useLocalDocker = false;

  // ── Cloud project ──────────────────────────────────────────
  static const String _cloudUrl = 'https://dwflunjwgklcsrfyuork.supabase.co';
  static const String _cloudAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR3Zmx1bmp3Z2tsY3NyZnl1b3JrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg0MTMyMTAsImV4cCI6MjA5Mzk4OTIxMH0.khm2j2yTiEZsJysUGBfItduRiv1wat7j0TEYnBdt2Ls';

  // ── Local Docker (Supabase CLI) ────────────────────────────
  // The anon key below is the fixed demo key the Supabase CLI uses for
  // every local install — it is not a secret.
  // Web / desktop reach the stack at 127.0.0.1; an Android emulator must
  // use 10.0.2.2 instead (it cannot see the host's localhost).
  static const String _localUrl = 'http://127.0.0.1:54321';
  static const String _localAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  static String get supabaseUrl => useLocalDocker ? _localUrl : _cloudUrl;
  static String get supabaseAnonKey =>
      useLocalDocker ? _localAnonKey : _cloudAnonKey;
}
