import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:predictrix/firebase_options.dart';
import 'package:predictrix/screens/home_screen.dart';
import 'package:predictrix/widgets/auth_gate_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const Predictrix());
}

class Predictrix extends StatelessWidget {
  const Predictrix({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Predictrix',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: GoogleFonts.aBeeZee().fontFamily,
          tabBarTheme: const TabBarTheme(
              indicator: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.black))))),
      home: const AuthGate(child: HomePage()),
    );
  }
}
