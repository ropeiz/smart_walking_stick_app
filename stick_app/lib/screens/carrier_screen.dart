import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:stick_app/screens/start_screen.dart';
import 'package:stick_app/screens/bluetooth_screen.dart'; // Importa la nueva pantalla
import 'package:stick_app/services/session_manager.dart'; // Importa el CognitoManager
import 'package:stick_app/services/cognito_manager.dart'; // Importar User
import 'package:latlong2/latlong.dart'; // Importar LatLng de latlong2

class CarrierScreen extends StatefulWidget {
  final User user;

  const CarrierScreen({super.key, required this.user});

  @override
  _CarrierScreenState createState() => _CarrierScreenState();
}

class _CarrierScreenState extends State<CarrierScreen> {
  bool isFlashing = false;
  bool showOkButton = false;
  Color sosButtonColor = Colors.red;
  Timer? flashTimer;
  Timer? sosTimer;
  Timer? longPressTimer;
  Timer? emergencyTimer;
  double progress = 0.0;

  // Número de teléfono al que se llamará
  final String emergencyNumber = "+34648985564"; // Cambia esto al número deseado

  // Generador de coordenadas aleatorias
  LatLng generateRandomCoordinate(LatLng center, double radius) {
    final random = Random();
    final offsetLat = (random.nextDouble() - 0.5) * radius * 2; // Random latitude within the radius
    final offsetLng = (random.nextDouble() - 0.5) * radius * 2; // Random longitude within the radius

    final newLat = center.latitude + offsetLat;
    final newLng = center.longitude + offsetLng;

    return LatLng(newLat, newLng);
  }

  // Cerrar sesión
  Future<void> _logout() async {
    await SessionManager.clearUserSession();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const StartScreen()), // Redirige a la pantalla de inicio
      (route) => false, // Elimina todas las rutas anteriores
    );
  }

  void startFlashing() {
    flashTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        sosButtonColor = sosButtonColor == Colors.red ? Colors.white : Colors.red;
      });
    });

    // Inicia el temporizador de emergencia para enviar datos después de 10 segundos
    emergencyTimer = Timer(const Duration(seconds: 10), sendEmergencyMessage);
  }

  // Enviar un mensaje de emergencia
  void sendEmergencyMessage() async {
    const String apiUrl = "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/emergency";

    try {
      final user = await SessionManager.getUserSession();
      if (user == null) {
        print("Error: Usuario no autenticado.");
        return;
      }

      final jwtToken = user.jwtToken;

      LatLng centralParkCenter = LatLng(40.785091, -73.968285); // Centro de Central Park
      double radius = 0.001; // Radio para generar las coordenadas aleatorias

      LatLng randomCoordinate = generateRandomCoordinate(centralParkCenter, radius);

      final requestBody = {
        "stickCarrier": "John's Smart Cane",
        "email": "ropson2663@gmail.com",
        "gpsLocation": "${randomCoordinate.latitude}, ${randomCoordinate.longitude}",
      };

      final headers = {
        "Content-Type": "application/json",
        "Authorization": jwtToken,
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        print("Emergency message sent successfully: ${response.body}");
      } else {
        print("Error sending emergency message: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Exception occurred while sending emergency message: $e");
    }
  }

  @override
  void dispose() {
    flashTimer?.cancel();
    sosTimer?.cancel();
    longPressTimer?.cancel();
    emergencyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Elimina la flecha de regreso
        title: const Text('Carrier'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Cerrar sesión') {
                _logout();
              } else if (value == 'Bluetooth') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BluetoothScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Cerrar sesión', 'Bluetooth'}.map((String choice) {
                return PopupMenuItem<String>(value: choice, child: Text(choice));
              }).toList();
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.lightBlue[50],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: startFlashing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: sosButtonColor,
                  minimumSize: const Size(200, 200),
                ),
                child: const Text('SOS', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: sendEmergencyMessage,
                child: const Text('Enviar Datos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
