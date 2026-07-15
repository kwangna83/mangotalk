import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../domain/app_user.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() =>
      ref.watch(authRepositoryProvider).restoreSession();

  Future<void> signIn(String nickname) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInAnonymously(nickname),
    );
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}
