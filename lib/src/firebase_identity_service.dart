import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mahafez_core/mahafez_core.dart';
import 'package:rxdart/rxdart.dart';

import 'identity_service.dart';
import 'user_profile.dart';

final class FirebaseIdentityService implements IdentityService {
  FirebaseIdentityService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
  }) : _auth = auth,
       _firestore = firestore,
       _googleSignIn = googleSignIn;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  static const _usersCollection = 'users';

  @override
  Stream<UserProfile?> get authStateChanges =>
      _auth.authStateChanges().switchMap(
        (user) => user == null
            ? Stream.value(null)
            : _firestore
                  .collection(_usersCollection)
                  .doc(user.uid)
                  .snapshots()
                  .where(
                    (snapshot) => snapshot.exists && snapshot.data() != null,
                  )
                  .map(
                    (snapshot) => _profileFromMap(user.uid, snapshot.data()!),
                  ),
      );

  @override
  UserProfile? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return UserProfile(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  @override
  Future<Result<UserProfile>> signInWithGoogle() => _execute(() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthFailure(
        code: 'google-sign-in-cancelled',
        technicalMessage: 'Google sign-in cancelled by user.',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final credentialResult = await _auth.signInWithCredential(credential);
    final user = _requireUser(credentialResult.user);
    await _createProfileIfMissing(user);
    return getUserProfile(user.uid).then(
      (result) => result.fold((failure) => throw failure, (profile) => profile),
    );
  });

  @override
  Future<Result<UserProfile>> signInWithEmailPassword({
    required String email,
    required String password,
  }) => _execute(() async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _getProfileOrThrow(_requireUser(result.user).uid);
  });

  @override
  Future<Result<UserProfile>> signUpWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) => _execute(() async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = _requireUser(result.user);
    await user.updateDisplayName(displayName);
    final updatedUser = _auth.currentUser ?? user;
    final reference = _firestore.collection(_usersCollection).doc(user.uid);
    final snapshot = await reference.get();
    if (!snapshot.exists) {
      await reference.set({
        'name': displayName,
        'email': user.email,
        'createdAt': DateTime.now(),
        'nameConfirmed': true,
      });
    }
    return _getProfileOrThrow(updatedUser.uid);
  });

  @override
  Future<Result<void>> updateDisplayName({
    required String uid,
    required String displayName,
  }) => _execute(() async {
    final user = _auth.currentUser;
    if (user != null && user.uid == uid) {
      await user.updateDisplayName(displayName);
    }
    await _firestore.collection(_usersCollection).doc(uid).update({
      'name': displayName,
      'nameConfirmed': true,
    });
  });

  @override
  Future<Result<void>> signOut() => _execute(() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  });

  @override
  Future<Result<UserProfile>> getUserProfile(String uid) =>
      _execute(() => _getProfileOrThrow(uid));

  Future<UserProfile> _getProfileOrThrow(String uid) async {
    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const ServerFailure(
        code: '404',
        technicalMessage: 'User profile not found.',
      );
    }
    return _profileFromMap(uid, data);
  }

  Future<void> _createProfileIfMissing(User user) async {
    final reference = _firestore.collection(_usersCollection).doc(user.uid);
    final snapshot = await reference.get();
    if (snapshot.exists) return;
    await reference.set({
      'name': user.displayName ?? '',
      'email': user.email,
      'createdAt': DateTime.now(),
      'nameConfirmed': false,
    });
  }

  UserProfile _profileFromMap(String uid, Map<String, Object?> data) {
    final createdAt = data['createdAt'];
    return UserProfile(
      uid: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String?,
      createdAt: switch (createdAt) {
        Timestamp timestamp => timestamp.toDate(),
        DateTime dateTime => dateTime,
        _ => DateTime.fromMillisecondsSinceEpoch(0),
      },
      nameConfirmed: data['nameConfirmed'] as bool? ?? true,
    );
  }

  User _requireUser(User? user) {
    if (user != null) return user;
    throw const AuthFailure(
      code: 'missing-user',
      technicalMessage: 'Firebase Auth returned no user.',
    );
  }

  Future<Result<T>> _execute<T>(Future<T> Function() operation) async {
    try {
      return Success(await operation());
    } on FirebaseAuthException catch (error, stackTrace) {
      log(
        'Identity operation failed: ${error.code}',
        name: 'IdentityService',
        stackTrace: stackTrace,
      );
      return FailureResult(
        AuthFailure(code: error.code, technicalMessage: error.message),
      );
    } on FirebaseException catch (error, stackTrace) {
      log(
        'Identity profile operation failed: ${error.code}',
        name: 'IdentityService',
        stackTrace: stackTrace,
      );
      return FailureResult(
        error.code == 'permission-denied'
            ? PermissionFailure(
                code: error.code,
                technicalMessage: error.message,
              )
            : ServerFailure(code: error.code, technicalMessage: error.message),
      );
    } on Failure catch (failure) {
      return FailureResult(failure);
    } catch (error, stackTrace) {
      log(
        'Unexpected identity operation failure',
        name: 'IdentityService',
        error: error,
        stackTrace: stackTrace,
      );
      return FailureResult(UnknownFailure(technicalMessage: error.toString()));
    }
  }
}
