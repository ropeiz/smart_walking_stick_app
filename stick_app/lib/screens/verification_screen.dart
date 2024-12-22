import 'package:flutter/material.dart';
import 'package:stick_app/services/cognito_manager.dart';
import 'package:stick_app/screens/login_screen.dart'; // Asegúrate de tener una pantalla de inicio de sesión definida

class VerificationScreen extends StatefulWidget {
  final String email;
  final String userType;

  const VerificationScreen({Key? key, required this.email, required this.userType}) : super(key: key);

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _codeController = TextEditingController();
  late final CognitoManager _cognitoManager;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cognitoManager = CognitoManager();
    _cognitoManager.init();
  }

  void _verifyCode() async {
    final code = _codeController.text;

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, introduce el código de verificación')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Confirmar al usuario con el código de verificación
      final isConfirmed = await _cognitoManager.confirmUser(widget.email, code);

      if (isConfirmed) {
        // Mostrar un mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta verificada con éxito. Por favor, inicia sesión.')),
        );

        // Navegar a la pantalla de inicio de sesión
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al confirmar el código')),
        );
      }
    } catch (e) {
      // Verificar el tipo de error y mostrar un mensaje adecuado
      String errorMessage = 'Ocurrió un error desconocido';
      if (e is CognitoServiceException) {
        errorMessage = e.message;
      } else {
        errorMessage = e.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $errorMessage')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación de Cuenta'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Se ha enviado un código de verificación al email ${widget.email}. Ingresa el código para confirmar tu cuenta.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Código de verificación'),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _verifyCode,
                    child: const Text('Verificar'),
                  ),
          ],
        ),
      ),
    );
  }
}
