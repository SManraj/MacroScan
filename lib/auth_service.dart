import 'package:dietingapp2026/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

ValueNotifier<AuthService> authService = ValueNotifier<AuthService>(
  AuthService(),
);

class AuthService {
  bool _googleSignInInitialized = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Get current user
  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Register with email and password
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await DatabaseService.createUserProfile(
      uid: credential.user!.uid,
      email: email,
    );

    return credential; // ← return at the end
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found for that email.');
        case 'invalid-email':
          throw Exception('That email address is invalid.');
        default:
          throw Exception(e.message ?? 'An error occurred. Please try again.');
      }
    }
  }

  // TODO: updateUsername
  Future<void> updateUsername(String newUsername) async {
    try {
      await currentUser?.updateDisplayName(newUsername);
      await currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to update username.');
    }
  }

  // TODO: deleteAccount
  Future<void> deleteAccount({required String password}) async {
    //require password to delete account
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in.');
    }

    if (user.email == null) {
      throw Exception('User email is not available.');
    }

    try {
      // Re-authenticate the user with their password before deleting
      // This ensures the password is correct
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Only delete if re-authentication succeeds
      await user.delete();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          throw Exception('Incorrect password. Please try again.');
        case 'user-mismatch':
          throw Exception(
            'The provided credentials do not match the current user.',
          );
        case 'user-not-found':
          throw Exception('User not found.');
        case 'invalid-credential':
          throw Exception('Invalid password. Please try again.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        case 'requires-recent-login':
          throw Exception(
            'This operation requires recent authentication. Please sign out and sign in again.',
          );
        default:
          throw Exception(
            e.message ?? 'Failed to delete account. Please try again.',
          );
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: $e');
    }
  }

  //  resetPasswordFromCurrentPassword
  Future<void> resetPasswordSettings({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in.');
    }

    if (user.email == null) {
      throw Exception('User email is not available.');
    }

    try {
      // Re-authenticate the user with their current password before updating
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Only update password if re-authentication succeeds
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          throw Exception('Incorrect current password. Please try again.');
        case 'user-mismatch':
          throw Exception(
            'The provided credentials do not match the current user.',
          );
        case 'user-not-found':
          throw Exception('User not found.');
        case 'invalid-credential':
          throw Exception('Invalid current password. Please try again.');
        case 'invalid-email':
          throw Exception('Invalid email address.');
        case 'requires-recent-login':
          throw Exception(
            'This operation requires recent authentication. Please sign out and sign in again.',
          );
        default:
          throw Exception(
            e.message ?? 'Failed to reset password. Please try again.',
          );
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Add this helper method
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _googleSignInInitialized = true;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      throw Exception('Google sign-in failed: ${e.description}');
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Firebase auth failed.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
/**
 * Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

 */