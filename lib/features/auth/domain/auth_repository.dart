import 'app_user.dart';

abstract interface class AuthRepository {
  Future<AppUser?> restoreSession();
  Future<AppUser> signInAnonymously(String nickname);
  Future<void> signOut();
}
