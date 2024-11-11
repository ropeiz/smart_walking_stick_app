// en verification_screen.dart

import 'package:flutter/material.dart';
import 'package:stick_app/services/cognito_manager.dart';
import 'package:stick_app/screens/carrier_screen.dart'; // Importar CarrierScreen
import 'package:stick_app/screens/supervisor_screen.dart'; // Importar SupervisorScreen

class VerificationScreen extends StatelessWidget {
  final String email;
  final String userType;  // Añadir userType
  const VerificationScreen({Key? key, required this.email, required this.userType}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificación de correo')),
      body: VerificationForm(email: email, userType: userType),
    );
  }
}

class VerificationForm extends StatefulWidget {
  final String email;
  final String userType;  // Añadir userType
  const VerificationForm({Key? key, required this.email, required this.userType}) : super(key: key);

  @override
  _VerificationFormState createState() => _VerificationFormState();
}

class _VerificationFormState extends State<VerificationForm> {
  final _confirmationCodeController = TextEditingController();
  late final CognitoManager _cognitoManager;

  @override
  void initState() {
    super.initState();
    _cognitoManager = CognitoManager();
    _cognitoManager.init();
  }

  void _confirmRegistration() async {
    final confirmationCode = _confirmationCodeController.text;

    if (confirmationCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa el código de verificación')),
      );
      return;
    }

    try {
      bool isConfirmed = await _cognitoManager.confirmUser(widget.email, confirmationCode);
      if (isConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario verificado con éxito')),
        );

        // Navegar a la pantalla correcta según el tipo de usuario
        if (widget.userType == 'Carrier') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CarrierScreen()),
          );
        } else if (widget.userType == 'Supervisor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SupervisorScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código de verificación incorrecto')),
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
          TextField(
            controller: _confirmationCodeController,
            decoration: const InputDecoration(labelText: 'Código de verificación'),
          ),
          ElevatedButton(
            onPressed: _confirmRegistration,
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
