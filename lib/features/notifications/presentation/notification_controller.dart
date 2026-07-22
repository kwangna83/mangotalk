import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../domain/notification_repository.dart';

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, PushPermissionStatus>(
      NotificationController.new,
    );

class NotificationController extends AsyncNotifier<PushPermissionStatus> {
  StreamSubscription<String>? _tokenSubscription;

  @override
  Future<PushPermissionStatus> build() async {
    ref.onDispose(() => _tokenSubscription?.cancel());
    final repository = ref.watch(notificationRepositoryProvider);
    final status = await repository.permissionStatus();
    if (status == PushPermissionStatus.authorized) {
      final enabled =
          await ref.read(installationIdStoreProvider).notificationsEnabled();
      if (enabled == false) return PushPermissionStatus.disabled;
      await _syncToken();
      _listenForTokenRefresh();
    }
    return status;
  }

  Future<void> enable() async {
    final repository = ref.read(notificationRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final status = await repository.requestPermission();
      if (status == PushPermissionStatus.authorized) {
        await ref
            .read(installationIdStoreProvider)
            .setNotificationsEnabled(true);
        await _syncToken();
        _listenForTokenRefresh();
      }
      return status;
    });
  }

  Future<void> disableCurrentSubscription() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final store = ref.read(installationIdStoreProvider);
      await store.setNotificationsEnabled(false);
      _tokenSubscription?.cancel();
      _tokenSubscription = null;

      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId != null) {
        final installationId = await store.getOrCreate();
        await ref
            .read(supabaseClientProvider)
            .from('push_subscriptions')
            .update({
              'enabled': false,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('installation_id', installationId);
      }
      await ref.read(notificationRepositoryProvider).deleteToken();
      return PushPermissionStatus.disabled;
    });
  }

  void _listenForTokenRefresh() {
    _tokenSubscription?.cancel();
    _tokenSubscription = ref
        .read(notificationRepositoryProvider)
        .tokenRefreshes
        .listen((token) => unawaited(_registerToken(token)));
  }

  Future<void> _syncToken() async {
    final token = await ref.read(notificationRepositoryProvider).token();
    if (token != null && token.isNotEmpty) await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final installationId =
        await ref.read(installationIdStoreProvider).getOrCreate();
    final now = DateTime.now().toUtc().toIso8601String();
    await ref.read(supabaseClientProvider).from('push_subscriptions').upsert({
      'user_id': userId,
      'installation_id': installationId,
      'platform': 'web',
      'token': token,
      'enabled': true,
      'last_seen_at': now,
      'updated_at': now,
    }, onConflict: 'user_id,installation_id');
  }
}
