import 'package:flutter/material.dart';
import 'package:stick_app/services/cognito_manager.dart';
import 'carrier_screen.dart';
import 'supervisor_screen.dart';
import 'package:stick_app/services/session_manager.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(child: LoginForm()),
    );
  }
}

class LoginForm extends StatefulWidget {
  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final CognitoManager _cognitoManager;

  @override
  void initState() {
    super.initState();
    _cognitoManager = CognitoManager();
    _cognitoManager.init();
  }

  void _signIn() async {
  final email = _emailController.text;
  final password = _passwordController.text;

  try {
    final user = await _cognitoManager.signIn(email, password);
    final userType = user.claims['custom:Type'] ?? 'Carrier';

    // Guardar sesión del usuario
    await SessionManager.saveUserSession(userType);

    if (userType == 'Carrier') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CarrierScreen()),
      );
    } else if (userType == 'Supervisor') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SupervisorScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tipo de usuario desconocido')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          ElevatedButton(
            onPressed: _signIn,
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
