import 'package:mahafez_core/mahafez_core.dart';

import 'user_profile.dart';

abstract interface class IdentityService {
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;

  Future<Result<UserProfile>> signInWithGoogle();
  Future<Result<UserProfile>> signInWithEmailPassword({
    required String email,
    required String password,
  });
  Future<Result<UserProfile>> signUpWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  });
  Future<Result<void>> updateDisplayName({
    required String uid,
    required String displayName,
  });
  Future<Result<void>> signOut();
  Future<Result<UserProfile>> getUserProfile(String uid);
}
