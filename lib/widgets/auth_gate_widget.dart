import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:predictrix/screens/login_screen.dart';
import 'package:predictrix/utils/socket_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          User user = FirebaseAuth.instance.currentUser!;
          SocketService().init(
              "user${user.uid},${user.displayName},${user.email},${user.photoURL}");
          return child;
        }
        return const LoginScreen();
      },
    );
  }
}
