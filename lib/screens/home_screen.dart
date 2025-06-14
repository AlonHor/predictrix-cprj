import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:predictrix/screens/chats_screen.dart';
import 'package:predictrix/utils/navigator.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:predictrix/redux/reducers.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      await FirebaseAuth.instance.signOut();

      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            StoreConnector<AppState, String>(
              converter: (store) => store.state.displayName,
              builder: (context, displayName) {
                return Text(
                  "Hey $displayName",
                  style: const TextStyle(fontSize: 24),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _signOut,
        child: const Icon(Icons.exit_to_app, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SizedBox(
        height: 72,
        child: Container(
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey, width: 0.5))),
          child: BottomNavigationBar(
            elevation: 8,
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(
                    Icons.home,
                    size: 32,
                  ),
                  label: "Home"),
              BottomNavigationBarItem(
                  icon: Hero(
                      tag: "chats-icon",
                      child: Material(
                          color: Colors.transparent,
                          child: Icon(Icons.chat, size: 32))),
                  label: "Chats"),
            ],
            onTap: (index) {
              switch (index) {
                case 0:
                  // Navigator.pushNamed(context, "/");
                  break;
                case 1:
                  NavigatorUtils.navigateTo(context, const ChatsPage());
                  break;
              }
            },
          ),
        ),
      ),
    );
  }
}
