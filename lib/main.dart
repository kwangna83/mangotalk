import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = AppConfig.fromEnvironment();
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.publishableKey,
    );
    runApp(const ProviderScope(child: MangoTalkApp()));
  } on AppConfigException catch (error) {
    runApp(_ConfigurationErrorApp(message: error.message));
  }
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}
