import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:predictrix/screens/login_screen.dart';
import 'package:predictrix/utils/socket_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription? _subscription;
  static bool isConnected = false;

  @override
  void initState() {
    super.initState();
    User user = FirebaseAuth.instance.currentUser!;
    user
        .getIdToken()
        .then((token) => SocketService().init("user$token"))
        .catchError((error) {
      if (error is FirebaseAuthException) {
        debugPrint('FirebaseAuthException: ${error.message}');
      } else {
        debugPrint('Unknown error: $error');
      }
    });

    _subscription = SocketService().onData.listen((data) {
      debugPrint('Auth gate got: $data');
      if (mounted && data == "token_ok") {
        setState(() {
          isConnected = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          if (!isConnected) {
            return const Center(child: CircularProgressIndicator());
          }
          return widget.child;
        }
        return const LoginScreen();
      },
    );
  }
}
