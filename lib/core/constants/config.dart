class Config {
  /// Supabase Project URL.
  /// Pass at compile-time via --dart-define=SUPABASE_URL=... or --dart-define-from-file=.env
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hwimpyhxwwgjyldrekpf.supabase.co',
  );

  /// Supabase API Key (Anon Key or Service Role Key).
  /// Safe for public repos: never hardcode live production secrets here.
  /// Pass at compile-time via --dart-define=SUPABASE_KEY=... or --dart-define-from-file=.env
  static const String supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: '',
  );

  /// Staff team access passcode for the scanner app.
  /// Pass at compile-time via --dart-define=TEAM_PASSCODE=... or --dart-define-from-file=.env
  static const String teamPasscode = String.fromEnvironment(
    'TEAM_PASSCODE',
    defaultValue: 'event2026',
  );
}
