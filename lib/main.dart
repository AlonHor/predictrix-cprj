import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:predictrix/firebase_options.dart';
import 'package:predictrix/screens/home_screen.dart';
import 'package:predictrix/widgets/auth_gate_widget.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'redux/reducers.dart';
import 'package:predictrix/utils/socket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.requestPermission(provisional: true);
  final store = Store<AppState>(
    appReducer,
    initialState: const AppState(),
  );
  SocketService().registerStore(store);
  runApp(Predictrix(store: store));
}

class Predictrix extends StatelessWidget {
  final Store<AppState> store;
  const Predictrix({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        title: 'Predictrix',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: GoogleFonts.varelaRound().fontFamily,
          tabBarTheme: const TabBarTheme(
            indicator: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black),
              ),
            ),
          ),
        ),
        home: const AuthGate(child: HomePage()),
      ),
    );
  }
}
