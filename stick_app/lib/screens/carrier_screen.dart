import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:stick_app/screens/start_screen.dart';
import 'package:stick_app/services/session_manager.dart'; 
import 'package:stick_app/services/cognito_manager.dart'; 
import 'package:latlong2/latlong.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'; 
import 'package:permission_handler/permission_handler.dart'; 
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

  String connectionStatus = "Disconnected";
  DiscoveredDevice? connectedDevice; 

  final String emergencyNumber = "+34648985584";

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final List<DiscoveredDevice> _devicesList = [];
  bool _isScanning = false;
  String _statusMessage = "";

  StreamSubscription? _scanSubscription;

  bool isSosActive = false;
  bool hasFallen = false;
  List<Map<String, double>> pressureHistory = [];

  List<LatLng> _predefinedPath = [];
  int _currentPathIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCoordinates();
  }

  Future<void> _loadCoordinates() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/coordinates.json');
      final List<dynamic> jsonData = jsonDecode(jsonString);

      _predefinedPath = jsonData.map((item) {
        final lat = item['latitude'] as double;
        final lng = item['longitude'] as double;
        return LatLng(lat, lng);
      }).toList();

      setState(() {});
    } catch (e) {
      print("Error loading coordinates: $e");
      _predefinedPath = [];
    }
  }

  LatLng getNextPathCoordinate() {
    if (_predefinedPath.isEmpty) {
      return LatLng(40.785091, -73.968285);
    }

    final coord = _predefinedPath[_currentPathIndex];

    _currentPathIndex++;
    if (_currentPathIndex >= _predefinedPath.length) {
      _currentPathIndex = 0;
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
      _statusMessage = "Searching for BLE devices...";
    });

    final scanStream = _ble.scanForDevices(withServices: []);
    _scanSubscription = scanStream.listen((device) {
      if (!mounted) return;

      setState(() {
        if (!_devicesList.any((d) => d.id == device.id)) {
          _devicesList.add(device);
        }
      });

      setStateModal(() {});
    }, onError: (error) {
      if (!mounted) return;

      setState(() {
        _statusMessage = "Error during scanning: $error";
        _isScanning = false;
      });
    });

    await Future.delayed(const Duration(seconds: 5));
    await _scanSubscription?.cancel();

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      if (_devicesList.isEmpty) {
        _statusMessage = "No devices found.";
      } else {
        _statusMessage = "Devices found:";
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
          _statusMessage = "No devices found.";
        } else {
          _statusMessage = "Devices found:";
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
      print("SOS activated");
    }
  }

  void sendEmergencyMessage() async {
    const String apiUrl = "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/emergency";

    try {
      final user = await SessionManager.getUserSession();
      if (user == null) {
        print("Error: Unauthenticated user.");
        return;
      }

      final jwtToken = user.jwtToken;

      LatLng nextCoordinate = getNextPathCoordinate();

      final requestBody = {
        "stickCarrier": user.username,
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
        SnackBar(content: Text('Connecting to device: ${device.name.isNotEmpty ? device.name : device.id}')),
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
              connectionStatus = "Connected to ${device.name.isNotEmpty ? device.name : device.id}";
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Connection established with: ${device.name.isNotEmpty ? device.name : device.id}')),
            );

            Navigator.pop(context);
            _discoverAndReadCharacteristics(device.id);
          }
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error connecting: $error')),
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
                  print('Insufficient data received: $data');
                }
              },
              onError: (error) {
                print('Error subscribing: $error');
              },
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error discovering services/characteristics: $e')),
      );
    }
  }

  bool _isPressureStable() {
    if (pressureHistory.length < 2) {
      print("Insufficient history to verify stable pressure.");
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
      print("Stable pressure detected. Readings: "
          "sensor_1=$firstS1, $secondS1; "
          "sensor_2=$firstS2, $secondS2");
      return true;
    } else {
      print("Pressure out of range. Readings: "
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
      print("Impact detected. Magnitude: $magnitude");

      if (_isPressureStable()) {
        print("Stable pressure detected before the impact. Evaluating fall...");

        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          final double s1 = double.tryParse(sensorData["pressure"]?["sensor_1"] ?? "0") ?? 0.0;
          final double s2 = double.tryParse(sensorData["pressure"]?["sensor_2"] ?? "0") ?? 0.0;

          if (s1 == 0.0 && s2 == 0.0) {
            print("Zero pressure detected after multiple checks. Confirming fall.");
            timer.cancel();
            setState(() {
              hasFallen = true;
            });
            _triggerEmergency();
          } else {
            print("Pressure still active after impact. Continuing evaluation...");
          }
        });
      } else {
        print("Pressure not stable before impact. Not considered a fall.");
      }
    }
  }

  void _triggerEmergency() {
    print("Fall detected. Activating SOS...");
    startFlashing(); 
  }

  void _decodeAndLogSensorData(Uint8List data) {
    final buffer = ByteData.sublistView(data);
    final int identifier = buffer.getUint8(0);

    setState(() {
      int? modeValue;

      switch (identifier) {
        case 0x01: 
          if (data.length >= 14) {
            sensorData["accelerometer"] = {
              "x": buffer.getFloat32(1, Endian.little).toString(),
              "y": buffer.getFloat32(5, Endian.little).toString(),
              "z": buffer.getFloat32(9, Endian.little).toString()
            };
            modeValue = buffer.getUint8(13);
            _analyzeFall(sensorData["accelerometer"]!);
          } else {
            print('Insufficient data for accelerometer');
          }
          break;

        case 0x02: 
          if (data.length >= 14) {
            sensorData["gyroscope"] = {
              "x": buffer.getFloat32(1, Endian.little).toString(),
              "y": buffer.getFloat32(5, Endian.little).toString(),
              "z": buffer.getFloat32(9, Endian.little).toString()
            };
            modeValue = buffer.getUint8(13);
          } else {
            print('Insufficient data for gyroscope');
          }
          break;

        case 0x03: 
          if (data.length >= 14) {
            sensorData["magnetometer"] = {
              "x": buffer.getFloat32(1, Endian.little).toString(),
              "y": buffer.getFloat32(5, Endian.little).toString(),
              "z": buffer.getFloat32(9, Endian.little).toString()
            };
            modeValue = buffer.getUint8(13);
          } else {
            print('Insufficient data for magnetometer');
          }
          break;

        case 0x04: 
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

            print("Updated pressure history: $pressureHistory");
          } else {
            print('Insufficient data for pressure');
          }
          break;

        case 0x05: 
          if (data.length >= 6) {
            sensorData["battery"] = buffer.getFloat32(1, Endian.little).toString();
            modeValue = buffer.getUint8(5);
          } else {
            print('Insufficient data for battery');
          }
          break;

        default:
          print('Unknown identifier: $identifier. Raw data: $data');
      }

      if (modeValue != null) {
        print("Current mode (log): $modeValue");

        // Forzar SOS si mode es 4
        if (modeValue == 4) {
          print("Mode 4 detected: Forcing SOS activation.");
          startFlashing();
        }
      }

      LatLng nextCoordinate = getNextPathCoordinate();

      lastGeneratedJson = {
        "stick_code": widget.user.stickCode,
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

      print("Generated JSON: ${jsonEncode(lastGeneratedJson)}");
      sendSensorData();
    });
  }

  void sendSensorData() async {
    if (lastGeneratedJson == null) {
      print("No data available to send.");
      return;
    }

    const String apiUrl = "https://7mn42nacfa.execute-api.eu-central-1.amazonaws.com/test/sensor-data";

    try {
      final user = await SessionManager.getUserSession();
      if (user == null) {
        print("Error: Unauthenticated user.");
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
                    child: const Text('Search Bluetooth Devices'),
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
                          title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                          subtitle: Text('ID: ${device.id}\nRSSI: ${device.rssi}'),
                          onTap: () {
                            setStateModal(() {
                              _statusMessage = "Selected device: ${device.name.isNotEmpty ? device.name : device.id}";
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
              if (value == 'Sign out') {
                _logout();
              } else if (value == 'Bluetooth') {
                _openBluetoothModal();
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Sign out', 'Bluetooth'}.map((String choice) {
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
            ],
          ),
        ),
      ),
    );
  }
}
