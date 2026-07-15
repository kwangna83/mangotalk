class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.publishableKey});

  final String supabaseUrl;
  final String publishableKey;

  static AppConfig fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || key.isEmpty) {
      throw const AppConfigException(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required.',
      );
    }
    return const AppConfig(supabaseUrl: url, publishableKey: key);
  }
}

class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}
