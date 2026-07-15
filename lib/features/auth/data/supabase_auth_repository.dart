import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppUser?> restoreSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final profile = await _client
        .from('profiles')
        .select('id, nickname')
        .eq('id', user.id)
        .maybeSingle();
    if (profile == null) return null;
    return AppUser.fromJson(profile);
  }

  @override
  Future<AppUser> signInAnonymously(String nickname) async {
    var user = _client.auth.currentUser;
    if (user == null) {
      final response = await _client.auth.signInAnonymously();
      user = response.user;
    }
    if (user == null) throw const AuthException('익명 로그인에 실패했습니다.');

    final profile = await _client
        .from('profiles')
        .upsert({'id': user.id, 'nickname': nickname.trim()})
        .select('id, nickname')
        .single();
    return AppUser.fromJson(profile);
  }

  @override
  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);
}
