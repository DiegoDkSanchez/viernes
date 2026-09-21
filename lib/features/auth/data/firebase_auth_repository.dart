import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this.auth);
  final FirebaseAuth auth;
  Future<void>? _initialization;

  @override
  Stream<AppUser?> watchUser() => auth.authStateChanges().map(
    (user) => user == null ? null : AppUser(user.uid, user.displayName ?? ''),
  );

  @override
  Future<void> signIn() async {
    if (kIsWeb) {
      await auth.signInWithPopup(GoogleAuthProvider());
    } else {
      await (_initialization ??= GoogleSignIn.instance.initialize());
      final account = await GoogleSignIn.instance.authenticate();
      await auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: account.authentication.idToken),
      );
    }
  }

  @override
  Future<void> signOut() async {
    await auth.signOut();
    if (!kIsWeb && _initialization != null) {
      await GoogleSignIn.instance.signOut();
    }
  }
}
