import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint("Starting Google Sign-In process");

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      try {
        await googleSignIn.signInSilently();
        debugPrint("Silent sign-in check completed");
      } catch (e) {
        debugPrint("Silent sign-in check failed (expected): $e");
      }

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint("User cancelled the sign-in process");
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      debugPrint("Google Sign-In successful for: ${googleUser.email}");
      final String displayName = googleUser.displayName ?? "";
      final String email = googleUser.email;
      final String photoUrl = googleUser.photoUrl ?? "";

      debugPrint("Google account info - Name: $displayName, Email: $email, Photo URL: $photoUrl");

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        if (user.displayName == null || user.displayName!.isEmpty) {
          debugPrint("Firebase user has no display name, updating with: $displayName");
          await user.updateDisplayName(displayName);
        }

        if (user.photoURL == null || user.photoURL!.isEmpty) {
          if (photoUrl.isNotEmpty) {
            debugPrint("Firebase user has no photo, updating with: $photoUrl");
            await user.updatePhotoURL(photoUrl);
          }
        }

        await user.reload();

        final updatedUser = FirebaseAuth.instance.currentUser;
        debugPrint("Updated user info - Name: ${updatedUser?.displayName}, Email: ${updatedUser?.email}, Photo URL: ${updatedUser?.photoURL}");
      }

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'An unknown error occurred with Firebase authentication';
        debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        debugPrint('Unknown error during sign-in: $e');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Predictrix.',
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              SizedBox(
                width: 300,
                height: 56,
                child: ElevatedButton.icon(
                  icon: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Image.asset('assets/google_logo.png', height: 24), const SizedBox(width: 8)]),
                  label: const Text('Continue with Google'),
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 300,
                  child: SelectableText(_error!,
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
