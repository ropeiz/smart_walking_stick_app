import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'start_screen.dart';
import 'package:stick_app/services/session_manager.dart'; 
import 'package:stick_app/services/cognito_manager.dart'; 

class SupervisorScreen extends StatefulWidget {
  final User user;

  const SupervisorScreen({super.key, required this.user});

  @override
  _SupervisorScreenState createState() => _SupervisorScreenState();
}

class _SupervisorScreenState extends State<SupervisorScreen> {
  final String apiUrl =
      "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/sensor-data";
  String lastUpdate = 'No data received';

  // Lista de puntos para la ruta
  List<LatLng> _routePoints = [];

  // Marcadores para el mapa
  List<Marker> _markers = [];

  Future<void> getSensorData() async {
    try {
      final user = await SessionManager.getUserSession();
      if (user == null) {
        print("Error: Usuario no autenticado.");
        return;
      }

      final jwtToken = user.jwtToken;
      final stickCode = user.stickCode;
      final date = "2024-12-05"; 

      final gpsData = await fetchGPSData(stickCode!, date, jwtToken);

      if (gpsData.isNotEmpty) {
        setState(() {
          lastUpdate = "Última actualización: ${DateTime.now()}";

          _markers.clear();
          _routePoints.clear();

          List<LatLng> allPoints = [];
          for (var data in gpsData) {
            final latitude = double.tryParse(data['latitude']);
            final longitude = double.tryParse(data['longitude']);
            if (latitude != null && longitude != null) {
              allPoints.add(LatLng(latitude, longitude));
            }
          }

          List<LatLng> filteredPoints = [];
          for (int i = 0; i < allPoints.length; i += 60) {
            filteredPoints.add(allPoints[i]);
          }

          if (filteredPoints.isEmpty && allPoints.isNotEmpty) {
            filteredPoints = allPoints;
          }

          _routePoints = filteredPoints;

          if (_routePoints.isNotEmpty) {
            // Marcador inicial (verde)
            _markers.add(
              Marker(
                point: _routePoints.first,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 40,
                ),
              ),
            );

            // Marcador final (rojo), si hay más de un punto
            if (_routePoints.length > 1) {
              _markers.add(
                Marker(
                  point: _routePoints.last,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              );
            }
          }
        });
      } else {
        print("No se recibieron datos GPS.");
      }
    } catch (e) {
      print("Excepción al obtener datos del sensor: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchGPSData(
      String stickCode, String date, String jwtToken) async {
    final String apiUrl =
        "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/GPS";

    try {
      final requestBody = {
        "stick_code": "ABC123",
        "date": date,
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

      print(response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData.containsKey('body')) {
          final bodyData = jsonDecode(responseData['body']);

          if (bodyData.containsKey('gps_data') && bodyData['gps_data'] != null) {
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
                // show logs if needed
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
                initialCenter: _routePoints.isNotEmpty
                    ? _routePoints.first
                    : LatLng(0, 0),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                if (_routePoints.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
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