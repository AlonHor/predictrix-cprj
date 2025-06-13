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
  final String officialServerIp = "34.22.247.161";

  // Shows a dialog to get the host IP address or select official server
  Future<void> _showHostIpDialog(BuildContext context) async {
    final TextEditingController ipController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // Dialog cannot be dismissed by tapping outside
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            constraints: const BoxConstraints(maxWidth: 500, minWidth: 400),
            child: AlertDialog(
              title: const Text('Server Connection'),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              insetPadding: EdgeInsets.zero,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud),
                    label: const Text('Connect to Official Server'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () {
                      host = officialServerIp;
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text("OR", textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Form(
                    key: formKey,
                    child: TextFormField(
                      controller: ipController,
                      decoration: InputDecoration(
                        hintText: 'Enter custom IP address',
                        labelText: 'Custom Host IP',
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
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    host = officialServerIp;
                    Navigator.of(dialogContext).pop();
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.private_connectivity),
                  label: const Text('Connect'),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      host = ipController.text;
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            ),
          ),
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
