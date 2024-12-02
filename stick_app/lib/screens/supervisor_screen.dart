import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final String apiUrl =
      "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/sensor-data";
  LatLng? sensorLocation;
  String lastUpdate = 'No data received';

  // Marcadores para el mapa
  final List<Marker> _markers = [];

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
        final latitude = double.tryParse(gpsData[0]['latitude']);
        final longitude = double.tryParse(gpsData[0]['longitude']);

        // Verificar que las coordenadas sean válidas
        if (latitude != null && longitude != null) {
          setState(() {
            sensorLocation = LatLng(latitude, longitude);
            lastUpdate = "Última actualización: ${DateTime.now()}";

            // Actualizar el marcador en la nueva ubicación
            _markers.clear();
            _markers.add(
              Marker(
                point: sensorLocation!,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            );
          });
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
  Future<List<Map<String, dynamic>>> fetchGPSData(
      String stickCode, String date, String jwtToken) async {
    final String apiUrl =
        "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/GPS";

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

        if (responseData.containsKey('body')) {
          final bodyData = jsonDecode(responseData['body']);

          if (bodyData.containsKey('gps_data') &&
              bodyData['gps_data'] != null) {
            final gpsData =
                List<Map<String, dynamic>>.from(bodyData['gps_data']);
            return gpsData;
          } else {
            print("Error: No se encontraron datos GPS en el campo 'body'.");
            return [];
          }
        } else {
          print("Error: No se encontró el campo 'body' en la respuesta.");
          return [];
        }
      } else {
        print("Error al obtener datos: ${response.statusCode}");
        print("Cuerpo de la respuesta: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Excepción al obtener datos del sensor: $e");
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
                return PopupMenuItem<String>(
                    value: choice, child: Text(choice));
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                // Cambié 'center' por 'initialCenter' en la nueva versión de flutter_map
                initialCenter: sensorLocation ?? LatLng(0, 0), // Centrar el mapa
                initialZoom: 15, // Nivel de zoom
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: _markers,
                ),
              ],
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
