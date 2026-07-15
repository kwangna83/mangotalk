import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/nickname_screen.dart';
import 'features/chat/presentation/chat_screen.dart';

class MangoTalkApp extends ConsumerWidget {
  const MangoTalkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return MaterialApp(
      title: 'MangoTalk',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: auth.when(
        data: (user) =>
            user == null ? const NicknameScreen() : const ChatScreen(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => ref.invalidate(authControllerProvider),
              child: const Text('다시 연결하기'),
            ),
          ),
        ),
      ),
    );
  }
}
