import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:stick_app/screens/start_screen.dart';
import 'package:stick_app/services/session_manager.dart'; // Importa el CognitoManager
import 'package:stick_app/services/cognito_manager.dart'; // Importar User
import 'package:latlong2/latlong.dart'; // Importar LatLng de latlong2
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'; // Asegúrate de tener esta librería instalada
import 'package:permission_handler/permission_handler.dart'; // Para manejar permisos
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle; 

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

  Map<String, dynamic> sensorData = {
    "accelerometer": {"x": "0.0", "y": "0.0", "z": "0.0"},
    "gyroscope": {"x": "0.0", "y": "0.0", "z": "0.0"},
    "magnetometer": {"x": "0.0", "y": "0.0", "z": "0.0"},
    "pressure": {"sensor_1": "0", "sensor_2": "0"},
    "battery": "0"
  };

  Map<String, dynamic>? lastGeneratedJson;

  String connectionStatus = "Desconectado"; // Estado inicial
  DiscoveredDevice? connectedDevice; // Dispositivo actualmente conectado

  final String emergencyNumber = "+34648985584"; // Número al que se llamará

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final List<DiscoveredDevice> _devicesList = [];
  bool _isScanning = false;
  String _statusMessage = "";

  StreamSubscription? _scanSubscription;

  bool isSosActive = false;
  bool hasFallen = false;
  List<Map<String, double>> pressureHistory = []; // Historial de presión reducido

  // Predefined path of coordinates. Replace these with your actual path coordinates.
  List<LatLng> _predefinedPath = [];
  int _currentPathIndex = 0;

  Future<void> _loadCoordinates() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/coordinates.json');
      final List<dynamic> jsonData = jsonDecode(jsonString);

      // Parse the JSON into a list of LatLng objects
      _predefinedPath = jsonData.map((item) {
        final lat = item['latitude'] as double;
        final lng = item['longitude'] as double;
        return LatLng(lat, lng);
      }).toList();

      setState(() {}); // Update the UI if needed
    } catch (e) {
      print("Error loading coordinates: $e");
      _predefinedPath = [];
    }
  }

  LatLng getNextPathCoordinate() {
    if (_predefinedPath.isEmpty) {
      // Fallback if no path is defined
      return LatLng(40.785091, -73.968285);
    }

    final coord = _predefinedPath[_currentPathIndex];

    // Move to the next coordinate for next time
    _currentPathIndex++;
    if (_currentPathIndex >= _predefinedPath.length) {
      // If you want to loop back to the start, uncomment the next line
      _currentPathIndex = 0;

      // If not looping, just remain on the last coordinate:
      //_currentPathIndex = _predefinedPath.length - 1;
    }

    return coord;
  }

  Future<void> _logout() async {
    await SessionManager.clearUserSession();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const StartScreen()),
      (route) => false,
    );
  }

  void _scanForDevices(Function setStateModal) async {
    await _requestPermissions();

    if (!mounted) return;

    setState(() {
      _devicesList.clear();
      _isScanning = true;
      _statusMessage = "Buscando dispositivos BLE...";
    });

    final scanStream = _ble.scanForDevices(withServices: []);
    _scanSubscription = scanStream.listen((device) {
      if (!mounted) return;

      setState(() {
        if (!_devicesList.any((d) => d.id == device.id)) {
          _devicesList.add(device);
        }
      });

      setStateModal(() {
        // Actualiza la subventana con la lista de dispositivos
      });
    }, onError: (error) {
      if (!mounted) return;

      setState(() {
        _statusMessage = "Error durante el escaneo: $error";
        _isScanning = false;
      });
    });

    await Future.delayed(const Duration(seconds: 5));
    await _scanSubscription?.cancel();

    if (!mounted) return;

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

  void startFlashing() {
    if (!isSosActive) {
      setState(() {
        isFlashing = true;
        showOkButton = true;
        sosButtonColor = Colors.red;
        isSosActive = true;
      });

      flashTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        setState(() {
          sosButtonColor = sosButtonColor == Colors.red ? Colors.white : Colors.red;
        });
      });

      emergencyTimer = Timer(const Duration(seconds: 10), sendEmergencyMessage);
      print("SOS activado");
    }
  }

  void sendEmergencyMessage() async {
    const String apiUrl = "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/emergency";

    try {
      final user = await SessionManager.getUserSession();
      if (user == null) {
        print("Error: Usuario no autenticado.");
        return;
      }

      final jwtToken = user.jwtToken;

      // Use the next coordinate in the predefined path instead of random:
      LatLng nextCoordinate = getNextPathCoordinate();

      final requestBody = {
        "stickCarrier": "John's Smart Cane",
        "email": "ropson2663@gmail.com",
        "gpsLocation": "${nextCoordinate.latitude}, ${nextCoordinate.longitude}",
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

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Conexión establecida con: ${device.name.isNotEmpty ? device.name : device.id}')),
            );

            Navigator.pop(context);
            _discoverAndReadCharacteristics(device.id);
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

  bool _isPressureStable() {
    if (pressureHistory.length < 2) {
      print("Historial insuficiente para verificar presión estable.");
      return false;
    }

    double firstS1 = pressureHistory[0]["sensor_1"]!;
    double firstS2 = pressureHistory[0]["sensor_2"]!;
    double secondS1 = pressureHistory[1]["sensor_1"]!;
    double secondS2 = pressureHistory[1]["sensor_2"]!;

    double tolerance = 3.0; 

    bool isStable =
        (secondS1 >= firstS1 - tolerance && secondS1 <= firstS1 + tolerance) &&
        (secondS2 >= firstS2 - tolerance && secondS2 <= firstS2 + tolerance);

    if (isStable) {
      print("Presión estable detectada. Lecturas: "
          "sensor_1=$firstS1, $secondS1; "
          "sensor_2=$firstS2, $secondS2");
      return true;
    } else {
      print("Presión fuera de rango. Lecturas: "
          "sensor_1=$firstS1, $secondS1; "
          "sensor_2=$firstS2, $secondS2");
      return false;
    }
  }

  void _analyzeFall(Map<String, String> accelerometerData) {
    final double x = double.tryParse(accelerometerData["x"] ?? "0") ?? 0.0;
    final double y = double.tryParse(accelerometerData["y"] ?? "0") ?? 0.0;
    final double z = double.tryParse(accelerometerData["z"] ?? "0") ?? 0.0;

    final double magnitude = sqrt(x * x + y * y + z * z);

    const double impactThreshold = 20.0;

    if (magnitude > impactThreshold) {
      print("Impacto detectado. Magnitud: $magnitude");

      if (_isPressureStable()) {
        print("Presión estable detectada antes del impacto. Evaluando caída.");

        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          final double s1 = double.tryParse(sensorData["pressure"]?["sensor_1"] ?? "0") ?? 0.0;
          final double s2 = double.tryParse(sensorData["pressure"]?["sensor_2"] ?? "0") ?? 0.0;

          if (s1 == 0.0 && s2 == 0.0) {
            print("Presión en 0 detectada tras múltiples impactos. Confirmando caída.");
            timer.cancel();
            setState(() {
              hasFallen = true;
            });
            _triggerEmergency();
          } else {
            print("Presión aún activa tras impacto. Continuando evaluación...");
          }
        });
      } else {
        print("Presión no estable antes del impacto. No se considera caída.");
      }
    }
  }

  void _triggerEmergency() {
    print("Caída detectada. Activando SOS...");
    startFlashing(); 
  }

  void _decodeAndLogSensorData(Uint8List data) {
    final buffer = ByteData.sublistView(data);
    final int identifier = buffer.getUint8(0);

    setState(() {
      int? modeValue;

      switch (identifier) {
        case 0x01: // Acelerómetro
          if (data.length >= 14) {
            sensorData["accelerometer"] = {
              "x": buffer.getFloat32(1, Endian.little).toString(),
              "y": buffer.getFloat32(5, Endian.little).toString(),
              "z": buffer.getFloat32(9, Endian.little).toString()
            };
            modeValue = buffer.getUint8(13);
            _analyzeFall(sensorData["accelerometer"]!);
          } else {
            print('Datos insuficientes para acelerómetro');
          }
          break;

        case 0x02: // Giroscopio
          if (data.length >= 14) {
            sensorData["gyroscope"] = {
              "x": buffer.getFloat32(1, Endian.little).toString(),
              "y": buffer.getFloat32(5, Endian.little).toString(),
              "z": buffer.getFloat32(9, Endian.little).toString()
            };
            modeValue = buffer.getUint8(13);
          } else {
            print('Datos insuficientes para giroscopio');
          }
          break;

        case 0x03: // Magnetómetro
          if (data.length >= 14) {
            sensorData["magnetometer"] = {
              "x": buffer.getFloat32(1, Endian.little).toString(),
              "y": buffer.getFloat32(5, Endian.little).toString(),
              "z": buffer.getFloat32(9, Endian.little).toString()
            };
            modeValue = buffer.getUint8(13);
          } else {
            print('Datos insuficientes para magnetómetro');
          }
          break;

        case 0x04: // Presión
          if (data.length >= 10) {
            sensorData["pressure"] = {
              "sensor_1": buffer.getFloat32(1, Endian.little).toString(),
              "sensor_2": buffer.getFloat32(5, Endian.little).toString()
            };
            modeValue = buffer.getUint8(9);

            double s1 = double.tryParse(sensorData["pressure"]!["sensor_1"]!) ?? 0.0;
            double s2 = double.tryParse(sensorData["pressure"]!["sensor_2"]!) ?? 0.0;

            pressureHistory.add({"sensor_1": s1, "sensor_2": s2});
            if (pressureHistory.length > 2) {
              pressureHistory.removeAt(0);
            }

            print("Historial de presión actualizado: $pressureHistory");
          } else {
            print('Datos insuficientes para presión');
          }
          break;

        case 0x05: // Batería
          if (data.length >= 6) {
            sensorData["battery"] = buffer.getFloat32(1, Endian.little).toString();
            modeValue = buffer.getUint8(5);
          } else {
            print('Datos insuficientes para batería');
          }
          break;

        default:
          print('Identificador desconocido: $identifier. Datos sin procesar: $data');
      }

      if (modeValue != null) {
        print("Modo actual (log): $modeValue");
      }

      // Use the next predefined path coordinate instead of random:
      LatLng nextCoordinate = getNextPathCoordinate();

      lastGeneratedJson = {
        "stick_code": "1234",
        "GPS_device": {
          "latitude": nextCoordinate.latitude.toString(),
          "longitude": nextCoordinate.longitude.toString(),
          "altitude": "15.3"
        },
        "IMU": {
          "accelerometer": sensorData["accelerometer"],
          "gyroscope": sensorData["gyroscope"],
          "magnetometer": sensorData["magnetometer"]
        },
        "pressure": sensorData["pressure"],
        "battery": sensorData["battery"],
        "user": "ropson2663"
      };

      print("json generado: ${jsonEncode(lastGeneratedJson)}");
      sendSensorData();
    });
  }

  void sendSensorData() async {
    if (lastGeneratedJson == null) {
      print("No hay datos disponibles para enviar.");
      return;
    }

    const String apiUrl = "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/sensor-data";

    try {
      final user = await SessionManager.getUserSession();
      if (user == null) {
        print("Error: Usuario no autenticado.");
        return;
      }

      final jwtToken = user.jwtToken;

      final headers = {
        "Content-Type": "application/json",
        "Authorization": jwtToken,
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: headers,
        body: jsonEncode(lastGeneratedJson),
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
    emergencyTimer?.cancel(); 
    setState(() {
      sosButtonColor = Colors.red;
      showOkButton = false;
      isFlashing = false;
      progress = 0.0;
      isSosActive = false;
    });
  }

  void startLongPress() {
    const pressDuration = Duration(milliseconds: 2500);
    final interval = const Duration(milliseconds: 50);
    final increment = interval.inMilliseconds / pressDuration.inMilliseconds;

    longPressTimer = Timer.periodic(interval, (timer) {
      setState(() {
        progress += increment;
        if (progress >= 1.0) {
          sosTimer?.cancel();
          stopFlashing();
          timer.cancel();
        }
      });
    });
  }

  void cancelLongPress() {
    longPressTimer?.cancel();
    setState(() {
      progress = 0.0;
    });
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
                        ? null
                        : () {
                            setStateModal(() {
                              _scanForDevices(setStateModal);
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
      _stopScanning();
    });
  }

  @override
  void dispose() {
    flashTimer?.cancel();
    sosTimer?.cancel();
    longPressTimer?.cancel();
    emergencyTimer?.cancel();
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        title: const Text('Carrier'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Cerrar sesión') {
                _logout();
              } else if (value == 'Bluetooth') {
                _openBluetoothModal();
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
              Text(
                connectionStatus,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
              ElevatedButton(
                onPressed: () {
                  if (!isFlashing) {
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
                            height: 70, 
                            width: 150 * progress, 
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