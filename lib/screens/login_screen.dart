import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithProvider(
        GoogleAuthProvider(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
