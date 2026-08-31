import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangotalk/core/providers/repository_providers.dart';
import 'package:mangotalk/features/auth/domain/app_user.dart';
import 'package:mangotalk/features/auth/domain/auth_repository.dart';
import 'package:mangotalk/features/auth/presentation/auth_controller.dart';
import 'package:mangotalk/features/notifications/domain/notification_repository.dart';
import 'package:mangotalk/features/notifications/presentation/notification_controller.dart';

void main() {
  const user = AppUser(id: 'user-1', nickname: '망고', isAnonymous: true);

  test(
    'restored sessions eagerly start notification synchronization',
    () async {
      final notifications = _FakeNotificationController();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(user)),
          notificationControllerProvider.overrideWith(() => notifications),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(authControllerProvider.future), user);
      await Future<void>.delayed(Duration.zero);

      expect(notifications.buildCount, 1);
    },
  );

  test(
    'notification startup failure does not fail session restoration',
    () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(user)),
          notificationControllerProvider.overrideWith(
            _FailingNotificationController.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(authControllerProvider.future), user);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authControllerProvider).value, user);
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository(this.restoredUser);

  final AppUser? restoredUser;

  @override
  Future<AppUser?> restoreSession() async => restoredUser;

  @override
  Future<AppUser> signInAnonymously(String nickname) async =>
      restoredUser ??
      AppUser(id: 'user-1', nickname: nickname, isAnonymous: true);

  @override
  Future<void> signOut() async {}

  @override
  Future<AppUser> updateProfile({
    required String nickname,
    Uint8List? avatarBytes,
    String? avatarMimeType,
    bool deleteAvatar = false,
  }) async => AppUser(id: 'user-1', nickname: nickname, isAnonymous: true);
}

class _FakeNotificationController extends NotificationController {
  int buildCount = 0;

  @override
  Future<PushPermissionStatus> build() async {
    buildCount++;
    return PushPermissionStatus.authorized;
  }
}

class _FailingNotificationController extends NotificationController {
  @override
  Future<PushPermissionStatus> build() async => throw StateError('FCM failed');
}
