// en sign_up_screen.dart

import 'package:flutter/material.dart';
import 'package:stick_app/services/cognito_manager.dart';
import 'package:stick_app/screens/verification_screen.dart'; // Importar VerificationScreen

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Center(child: SignUpForm()),
    );
  }
}

class SignUpForm extends StatefulWidget {
  @override
  _SignUpFormState createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _stickCodeController = TextEditingController();
  final List<String> _userTypes = ['Supervisor', 'Carrier'];
  String? _selectedUserType;
  late final CognitoManager _cognitoManager;

  @override
  void initState() {
    super.initState();
    _cognitoManager = CognitoManager();
    _cognitoManager.init();
  }

  void _signUp() async {
    final email = _emailController.text;
    final password = _passwordController.text;
    final stickCode = _stickCodeController.text;
    final userType = _selectedUserType;

    if (userType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un tipo de usuario')),
      );
      return;
    }

    try {
      await _cognitoManager.signUp(email, password, userType, stickCode);

      // Pasamos el tipo de usuario al VerificationScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(email: email, userType: userType),
        ),
      );
    } catch (e) {
      if (e is CognitoServiceException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error desconocido: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
          TextField(controller: _stickCodeController, decoration: const InputDecoration(labelText: 'Stick Code')),
          DropdownButtonFormField<String>(
            value: _selectedUserType,
            hint: const Text('Selecciona el tipo de usuario'),
            items: _userTypes.map((String type) {
              return DropdownMenuItem<String>(value: type, child: Text(type));
            }).toList(),
            onChanged: (String? newValue) => setState(() => _selectedUserType = newValue),
          ),
          ElevatedButton(onPressed: _signUp, child: const Text('Registrarse')),
        ],
      ),
    );
  }
}
