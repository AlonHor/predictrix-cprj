import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:predictrix/screens/login_screen.dart';
import 'package:predictrix/utils/socket_service.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:predictrix/redux/reducers.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStateChanges;
  late final StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();

    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    _authSubscription = _authStateChanges.listen((user) {
      if (user != null) {
        user
            .getIdToken()
            .then((token) => SocketService().init(token ?? ""))
            .catchError((error) {
          if (error is FirebaseAuthException) {
            debugPrint('FirebaseAuthException: \\${error.message}');
          } else {
            debugPrint('Unknown error: \\$error');
          }
        });
      } else {
        debugPrint('No user is currently signed in.');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, bool>(
      distinct: true,
      converter: (store) => store.state.isConnected,
      builder: (context, isConnected) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (FirebaseAuth.instance.currentUser == null) {
              return const LoginScreen();
            }
            if (snapshot.connectionState == ConnectionState.waiting ||
                !isConnected) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasData) {
              return widget.child;
            }
            return const LoginScreen();
          },
        );
      },
    );
  }
}
