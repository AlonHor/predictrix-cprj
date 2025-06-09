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
  @override
  void initState() {
    super.initState();
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No user is currently signed in.');
      return;
    }
    user
        .getIdToken()
        .then((token) => SocketService().init("$token"))
        .catchError((error) {
      if (error is FirebaseAuthException) {
        debugPrint('FirebaseAuthException: \\${error.message}');
      } else {
        debugPrint('Unknown error: \\$error');
      }
    });
  }

  @override
  void dispose() {
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
