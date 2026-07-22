import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../domain/app_user.dart';
import '../../notifications/presentation/notification_controller.dart';

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
    await ref
        .read(notificationControllerProvider.notifier)
        .disableCurrentSubscription();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }

  Future<bool> updateProfile({
    required String nickname,
    Uint8List? avatarBytes,
    String? avatarMimeType,
    bool deleteAvatar = false,
  }) async {
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .updateProfile(
            nickname: nickname,
            avatarBytes: avatarBytes,
            avatarMimeType: avatarMimeType,
            deleteAvatar: deleteAvatar,
          );
      state = AsyncData(user);
      return true;
    } catch (_) {
      return false;
    }
  }
}
