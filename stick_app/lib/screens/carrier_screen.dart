import 'package:flutter/material.dart';
import 'package:stick_app/screens/start_screen.dart'; // Importación de StartScreen
import 'dart:async';
import 'package:stick_app/services/session_manager.dart'; // Importa el CognitoManager
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stick_app/services/cognito_manager.dart'; // Importar User


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
  double progress = 0.0;

  // Número de teléfono al que se llamará
  final String emergencyNumber = "+34648985564"; // Cambia esto al número deseado


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
  }

void sendSensorData() async {
  final String apiUrl = "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/sensor-data";

  try {
    // Obtener datos del usuario desde SessionManager
    final user = await SessionManager.getUserSession();
    if (user == null) {
      print("Error: Usuario no autenticado.");
      return;
    }

    final jwtToken = user.jwtToken;
    final username = user.username;

    print('JWT Token: $jwtToken');

    // JSON payload
    final requestBody = {
      "device_id": "SWS1",
      "GPS_device": {
        "latitude": 41.3851,
        "longitude": 2.1734,
        "altitude": 15.3,
      },
      "IMU": {
        "accelerometer": {"x": 0.02, "y": -0.98, "z": 9.81},
        "gyroscope": {"x": 0.01, "y": 0.02, "z": 0.00},
        "magnetometer": {"x": 30.1, "y": -15.4, "z": 42.8},
      },
      "pressure": {
        "sensor_1": 20,
        "sensor_2": 22,
      },
      "battery": 85,
      "user": username, // Include the username in the payload
    };

    // Headers with Cognito JWT token
    final headers = {
      "Content-Type": "application/json",
      "Authorization": jwtToken,
    };

    // POST request to API Gateway
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: headers,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      print("Data sent successfully: ${response.body}");
    } else {
      print("Error sending data: ${response.statusCode}");
      print("Response body: ${response.body}");
    }
  } catch (e) {
    print("Exception occurred: $e");
  }
}

  void stopFlashing() {
    flashTimer?.cancel();
    sosTimer?.cancel();
    setState(() {
      sosButtonColor = Colors.red;
      showOkButton = false;
      isFlashing = false;
      progress = 0.0;
    });
  }


  void startLongPress() {
    const pressDuration = Duration(milliseconds: 2500); // 2.5 segundos
    final interval = const Duration(milliseconds: 50); // Intervalo de actualización
    final increment = interval.inMilliseconds / pressDuration.inMilliseconds; // Incremento de progreso

    longPressTimer = Timer.periodic(interval, (timer) {
      setState(() {
        progress += increment;
        if (progress >= 1.0) {
          sosTimer?.cancel(); // Cancela la llamada SOS
          stopFlashing();
          timer.cancel();
        }
      });
    });
  }

  void cancelLongPress() {
    longPressTimer?.cancel();
    setState(() {
      progress = 0.0; // Restablece el progreso si se cancela la pulsación larga
    });
  }


  @override
  void dispose() {
    flashTimer?.cancel();
    sosTimer?.cancel();
    longPressTimer?.cancel();
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
              _logout(); // Llamamos al método para cerrar sesión
            }
          },
          itemBuilder: (BuildContext context) {
            return {'Cerrar sesión'}.map((String choice) {
              return PopupMenuItem<String>(value: choice, child: Text(choice));
            }).toList();
          },
        ),
      ],
    ),
    body: Container(
      color: Colors.lightBlue[50], // Fondo azul claro
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                if (!isFlashing) {
                  setState(() {
                    isFlashing = true;
                    showOkButton = true;
                  });
                  startFlashing();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: sosButtonColor,
                minimumSize: const Size(200, 200),
              ),
              child: const Text('SOS', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 20),
            if (showOkButton)
              GestureDetector(
                onLongPressStart: (_) {
                  startLongPress();
                },
                onLongPressEnd: (_) {
                  cancelLongPress();
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green,
                        minimumSize: const Size(150, 70),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 70, // Altura de la barra
                          width: 150 * progress, // Ancho proporcional al progreso
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20), // Espaciado adicional
            ElevatedButton(
              onPressed: sendSensorData, // Llama a la función sendSensorData
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(150, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Prueba Enviar Datos',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
