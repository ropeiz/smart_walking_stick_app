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
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'; // Asegúrate de tener esta librería instalada
import 'package:permission_handler/permission_handler.dart'; // Para manejar permisos
import 'dart:typed_data';

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

  String connectionStatus = "Desconectado"; // Estado inicial

  DiscoveredDevice? connectedDevice; // Dispositivo actualmente conectado
  String _receivedData = ""; // Datos decodificados recibidos

  // Número de teléfono al que se llamará
  final String emergencyNumber = "+34648985584"; // Cambia esto al número deseado

  // Variables Bluetooth
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final List<DiscoveredDevice> _devicesList = [];
  bool _isScanning = false;
  String _statusMessage = "";

  StreamSubscription? _scanSubscription;

void _scanForDevices(Function setStateModal) async {
  await _requestPermissions();

  if (!mounted) return; // Verifica si el widget sigue montado

  setState(() {
    _devicesList.clear();
    _isScanning = true;
    _statusMessage = "Buscando dispositivos BLE...";
  });

  // Inicia el escaneo
  final scanStream = _ble.scanForDevices(withServices: []);
  _scanSubscription = scanStream.listen((device) {
    if (!mounted) return; // Verifica si el widget sigue montado

    setState(() {
      if (!_devicesList.any((d) => d.id == device.id)) {
        _devicesList.add(device);
      }
    });

    setStateModal(() {
      // Actualiza la subventana con la lista de dispositivos
    });
  }, onError: (error) {
    if (!mounted) return; // Verifica si el widget sigue montado

    setState(() {
      _statusMessage = "Error durante el escaneo: $error";
      _isScanning = false;
    });
  });

  // Detiene el escaneo después de 10 segundos
  await Future.delayed(const Duration(seconds: 10));
  await _scanSubscription?.cancel();

  if (!mounted) return; // Verifica si el widget sigue montado

  setState(() {
    _isScanning = false;
    if (_devicesList.isEmpty) {
      _statusMessage = "No se encontraron dispositivos.";
    } else {
      _statusMessage = "Dispositivos encontrados:";
    }
  });
}


Future<void> _requestPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
  ].request();

  statuses.forEach((permission, status) {
    print("$permission: $status");
  });
}

// Detener el escaneo manualmente
void _stopScanning() {
  setState(() {
    _isScanning = false;
  });
}

  Future<void> _stopScan() async {
  await _scanSubscription?.cancel();
  if (mounted) {
    setState(() {
      _isScanning = false;
      if (_devicesList.isEmpty) {
        _statusMessage = "No se encontraron dispositivos.";
      } else {
        _statusMessage = "Dispositivos encontrados:";
      }
    });
  }
}


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
      // Obtener datos del usuario desde SessionManager
      final user = await SessionManager.getUserSession();
      if (user == null) {
        print("Error: Usuario no autenticado.");
        return;
      }

      final jwtToken = user.jwtToken;

      // Generamos coordenadas aleatorias alrededor del centro de Central Park
      LatLng centralParkCenter = LatLng(40.785091, -73.968285); // Centro de Central Park
      double radius = 0.001; // Radio para generar las coordenadas aleatorias

      LatLng randomCoordinate = generateRandomCoordinate(centralParkCenter, radius);

      // JSON payload
      final requestBody = {
        "stickCarrier": "John's Smart Cane",
        "email": "ropson2663@gmail.com",
        "gpsLocation": "${randomCoordinate.latitude}, ${randomCoordinate.longitude}",
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
        print("Emergency message sent successfully: ${response.body}");
      } else {
        print("Error sending emergency message: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Exception occurred while sending emergency message: $e");
    }
  }

  void _connectToDevice(DiscoveredDevice device) async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Conectando al dispositivo: ${device.name.isNotEmpty ? device.name : device.id}')),
    );

    final connection = _ble.connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: {},
    );

    connection.listen(
      (connectionState) {
        if (connectionState.connectionState == DeviceConnectionState.connected) {
          setState(() {
            connectedDevice = device;
            connectionStatus = "Conectado a ${device.name.isNotEmpty ? device.name : device.id}";
          });

          // Muestra un mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Conexión establecida con: ${device.name.isNotEmpty ? device.name : device.id}')),
          );

          Navigator.pop(context); // Cierra la subventana
          _discoverAndReadCharacteristics(device.id); // Leer datos del dispositivo
        }
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al conectar: $error')),
        );
      },
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}


void _discoverAndReadCharacteristics(String deviceId) async {
  try {
    final discoveredServices = await _ble.discoverServices(deviceId);
    for (var service in discoveredServices) {
      for (var characteristic in service.characteristics) {
        final qualifiedCharacteristic = QualifiedCharacteristic(
          deviceId: deviceId,
          serviceId: service.serviceId,
          characteristicId: characteristic.characteristicId,
        );

        if (characteristic.isNotifiable) {
          _ble.subscribeToCharacteristic(qualifiedCharacteristic).listen(
            (data) {
              if (data.isNotEmpty) {
                _decodeAndLogSensorData(Uint8List.fromList(data));
              } else {
                print('Datos insuficientes recibidos: $data');
              }
            },
            onError: (error) {
              print('Error al suscribirse: $error');
            },
          );
        }
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al descubrir servicios/características: $e')),
    );
  }
}

void _decodeAndLogSensorData(Uint8List data) {
  final buffer = ByteData.sublistView(data);

  // Identificar el paquete por su primer byte
  final int identifier = buffer.getUint8(0);

  switch (identifier) {
    case 0x01: // Acelerómetro
      final accelerometer = [
        buffer.getFloat32(1, Endian.little),
        buffer.getFloat32(5, Endian.little),
        buffer.getFloat32(9, Endian.little),
      ];
      print('Acelerómetro: X=${accelerometer[0]}, Y=${accelerometer[1]}, Z=${accelerometer[2]}');
      break;

    case 0x02: // Giroscopio
      final gyroscope = [
        buffer.getFloat32(1, Endian.little),
        buffer.getFloat32(5, Endian.little),
        buffer.getFloat32(9, Endian.little),
      ];
      print('Giroscopio: X=${gyroscope[0]}, Y=${gyroscope[1]}, Z=${gyroscope[2]}');
      break;

    case 0x03: // Magnetómetro
      final magnetometer = [
        buffer.getFloat32(1, Endian.little),
        buffer.getFloat32(5, Endian.little),
        buffer.getFloat32(9, Endian.little),
      ];
      print('Magnetómetro: X=${magnetometer[0]}, Y=${magnetometer[1]}, Z=${magnetometer[2]}');
      break;

    case 0x04: // Presión
      final pressure = [
        buffer.getFloat32(1, Endian.little),
        buffer.getFloat32(5, Endian.little),
      ];
      print('Presión: Sensor 1=${pressure[0]}, Sensor 2=${pressure[1]}');
      break;

    case 0x05: // Batería
      final battery = buffer.getFloat32(1, Endian.little);
      print('Batería: $battery%');
      break;

    default:
      print('Identificador desconocido: $identifier. Datos sin procesar: $data');
  }
}


  // Función para enviar datos con coordenadas aleatorias
  void sendSensorData() async {
    final String apiUrl = "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/sensor-data";

    try {
      final user = await SessionManager.getUserSession();
      if (user == null) {
        print("Error: Usuario no autenticado.");
        return;
      }

      final jwtToken = user.jwtToken;
      final username = user.username;
      final stickCode = user.stickCode;

      print('JWT Token: $jwtToken');

      LatLng centralParkCenter = LatLng(40.785091, -73.968285); // Centro de Central Park
      double radius = 0.001; // Radio para generar las coordenadas aleatorias

      LatLng randomCoordinate = generateRandomCoordinate(centralParkCenter, radius);

      final requestBody = {
        "stick_code": stickCode,
        "GPS_device": {
          "latitude": randomCoordinate.latitude.toString(),
          "longitude": randomCoordinate.longitude.toString(),
          "altitude": "15.3",
        },
        "IMU": {
          "accelerometer": {"x": "0.02", "y": "-0.98", "z": "9.81"},
          "gyroscope": {"x": "0.01", "y": "0.02", "z": "0.00"},
          "magnetometer": {"x": "30.1", "y": "-15.4", "z": "42.8"},
        },
        "pressure": {
          "sensor_1": "20",
          "sensor_2": "22",
        },
        "battery": "85",
        "user": username,
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
    emergencyTimer?.cancel(); // Cancela el temporizador de emergencia
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

  // Navegar a la pantalla de Bluetooth y pasar el usuario
  void navigateToBluetoothScreen() {
    Navigator.push(
  context,
  MaterialPageRoute(
    //builder: (context) => BluetoothScreen(user: widget.user),
    builder: (context) => BluetoothScreen(),
  ),
);

  }

  void _openBluetoothModal() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateModal) {
          return Container(
            padding: const EdgeInsets.all(8.0),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _isScanning
                      ? null // Desactiva el botón mientras escanea
                      : () {
                          setStateModal(() {
                            _scanForDevices(setStateModal); // Llama al escaneo y actualiza la subventana
                          });
                        },
                  child: const Text('Buscar Dispositivos Bluetooth'),
                ),
                const SizedBox(height: 10),
                if (_isScanning) const CircularProgressIndicator(),
                if (_statusMessage.isNotEmpty) Text(_statusMessage),
                Expanded(
                  child: ListView.builder(
                    itemCount: _devicesList.length,
                    itemBuilder: (context, index) {
                      final device = _devicesList[index];
                      return ListTile(
                        title: Text(device.name.isNotEmpty ? device.name : 'Dispositivo Desconocido'),
                        subtitle: Text('ID: ${device.id}\nRSSI: ${device.rssi}'),
                        onTap: () {
                          setStateModal(() {
                            _statusMessage = "Seleccionaste el dispositivo: ${device.name.isNotEmpty ? device.name : device.id}";
                          });
                          _connectToDevice(device);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    _stopScanning(); // Detener el escaneo al cerrar la subventana
  });
}

  @override
void dispose() {
  // Cancela los temporizadores
  flashTimer?.cancel();
  sosTimer?.cancel();
  longPressTimer?.cancel();
  emergencyTimer?.cancel();

  // Cancela el Stream de escaneo de Bluetooth si está activo
  _scanSubscription?.cancel();

  // Llama a la implementación del método base
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
                _openBluetoothModal(); // Abrir la subventana
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
        color: Colors.lightBlue[50], // Fondo azul claro
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Estado de conexión Bluetooth
              Text(
                connectionStatus,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: sendSensorData,
                child: const Text('Enviar Datos'),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
