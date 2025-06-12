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
  late String host = "";

  // Shows a dialog to get the host IP address
  Future<void> _showHostIpDialog(BuildContext context) async {
    final TextEditingController ipController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Dialog cannot be dismissed by tapping outside
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Enter Host IP'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: ipController,
              decoration: InputDecoration(
                hintText: 'Enter host IP address',
                labelText: 'Host IP',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.computer, color: Colors.blue),
                filled: false,
              ),
              keyboardType: TextInputType.text,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a valid IP address';
                }
                final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                if (!ipRegex.hasMatch(value)) {
                  return 'Please enter a valid IP address format (e.g., 192.168.1.122)';
                }
                return null;
              },
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Connect'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  host = ipController.text;
                  Navigator.of(dialogContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showHostIpDialog(context).then((_) {
        _authStateChanges = FirebaseAuth.instance.authStateChanges();
        _authSubscription = _authStateChanges.listen((user) {
          if (user != null) {
            user.getIdToken().then((token) => SocketService().init(token ?? "", host)).catchError((error) {
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
      });
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
            if (host.isEmpty) {
              return Container();
            }
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
