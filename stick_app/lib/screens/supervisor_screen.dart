import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'start_screen.dart';
import 'package:stick_app/services/session_manager.dart'; // Importa el CognitoManager
import 'package:stick_app/services/cognito_manager.dart'; // Importar User

class SupervisorScreen extends StatefulWidget {
  final User user;

  const SupervisorScreen({super.key, required this.user});


  @override
  _SupervisorScreenState createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends State<SupervisorScreen> {
  final String apiUrl = "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/sensor-data";
  LatLng? sensorLocation;
  String lastUpdate = 'No data received';

  // Controlador del mapa
  GoogleMapController? mapController;

  // Función para obtener datos del sensor
  Future<void> getSensorData() async {
  try {
    // Obtener el JWT token del usuario autenticado
    final user = await SessionManager.getUserSession();
    if (user == null) {
      print("Error: Usuario no autenticado.");
      return;
    }

    final jwtToken = user.jwtToken;
    final stickCode = user.stickCode;

    // Parámetros de la solicitud (deberías pasar el stickCode y la fecha)
    final date = "2024-11-27"; // Reemplaza con la fecha correcta en formato YYYY-MM-DD

    // Hacer la solicitud POST para obtener los datos GPS
    final gpsData = await fetchGPSData(stickCode!, date, jwtToken);

    // Verificar si se recibieron datos GPS
    if (gpsData.isNotEmpty) {
      final latitude = gpsData[0]['latitude'];
      final longitude = gpsData[0]['longitude'];

      // Verificar que las coordenadas sean válidas
      if (latitude != null && longitude != null) {
        setState(() {
          sensorLocation = LatLng(latitude, longitude);
          lastUpdate = "Última actualización: ${DateTime.now()}";
        });

        // Mover el mapa a las nuevas coordenadas
        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newLatLng(sensorLocation!),
          );
        }
      } else {
        print("Error: Coordenadas no válidas en los datos recibidos.");
      }
    } else {
      print("No se recibieron datos GPS.");
    }
  } catch (e) {
    print("Excepción al obtener datos del sensor: $e");
  }
}


// Función que obtiene los datos GPS a través de la API
Future<List<Map<String, dynamic>>> fetchGPSData(String stickCode, String date, String jwtToken) async {
  final String apiUrl = "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/GPS";

  try {
    // Cuerpo de la solicitud
    final requestBody = {
      "stick_code": stickCode,
      "date": date, // Formato: YYYY-MM-DD
    };

    // Cabeceras con el JWT Token
    final headers = {
      "Content-Type": "application/json",
      "Authorization": jwtToken,
    };

    // Realizar la solicitud POST
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: headers,
      body: jsonEncode(requestBody),
    );

    print(response.body);

    // Analizar la respuesta
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      
      // Verificar si 'gps_data' existe y no es nulo
      if (responseData.containsKey('gps_data') && responseData['gps_data'] != null) {
        final gpsData = List<Map<String, dynamic>>.from(responseData['gps_data']);
        return gpsData;
      } else {
        print("Error: No se encontraron datos GPS en la respuesta.");
        return [];
      }
    } else {
      print("Error al obtener datos: ${response.statusCode}");
      print("Cuerpo de la respuesta: ${response.body}");
      return [];
    }
  } catch (e) {
    print("Excepción al obtener datos: $e");
    return [];
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Cerrar sesión') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const StartScreen()),
                  (route) => false,
                );
              } else if (value == 'Logs') {
                // Aquí podrías agregar lógica para mostrar logs si es necesario
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Logs', 'Cerrar sesión'}.map((String choice) {
                return PopupMenuItem<String>(value: choice, child: Text(choice));
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) {
                mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: sensorLocation ?? const LatLng(0, 0),
                zoom: 15,
              ),
              markers: sensorLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId("sensorLocation"),
                        position: sensorLocation!,
                        infoWindow: const InfoWindow(title: "Sensor Location"),
                      )
                    }
                  : {},
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(lastUpdate, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: getSensorData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(150, 50),
                  ),
                  child: const Text(
                    'Actualizar Datos',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
