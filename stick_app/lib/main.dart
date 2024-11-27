import 'package:flutter/material.dart';
import 'package:stick_app/screens/carrier_screen.dart';
import 'package:stick_app/screens/start_screen.dart';
import 'package:stick_app/screens/supervisor_screen.dart';
import 'package:stick_app/screens/login_screen.dart';
import 'package:stick_app/services/session_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safety App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // Cambiamos StartScreen por SplashScreen
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getInitialScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          return snapshot.data as Widget;
        } else {
          return const LoginScreen();
        }
      },
    );
  }

  Future<Widget> _getInitialScreen() async {
  final isLoggedIn = await SessionManager.isLoggedIn();
  if (!isLoggedIn) return const StartScreen();

  final user = await SessionManager.getUserSession();
  if (user == null) return const StartScreen(); // Manejar el caso donde no haya datos del usuario

  if (user.userType == 'Carrier') {
    return CarrierScreen(user: user); // Pasa el objeto User
  } else if (user.userType == 'Supervisor') {
    return SupervisorScreen(); // Similar para Supervisor
  } else {
    return const StartScreen();
  }
}
}
