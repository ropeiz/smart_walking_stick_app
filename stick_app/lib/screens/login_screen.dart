import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(child: LoginForm()),
    );
  }
}

class LoginForm extends StatefulWidget {
  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final List<DiscoveredDevice> _devicesList = [];
  bool _isScanning = false;
  String _statusMessage = "";
  String _receivedData = ""; // Para mostrar los datos decodificados

  @override
  void initState() {
    super.initState();
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

  void _scanForDevices() async {
    await _requestPermissions();

    setState(() {
      _devicesList.clear();
      _isScanning = true;
      _statusMessage = "Buscando dispositivos BLE...";
    });

    // Escaneo sin filtros
    final scanStream = _ble.scanForDevices(withServices: []);

    final subscription = scanStream.listen((device) {
      print("Dispositivo detectado: ${device.name} (${device.id})");

      // Guarda cualquier dispositivo encontrado
      setState(() {
        if (!_devicesList.any((d) => d.id == device.id)) {
          _devicesList.add(device);
        }
      });
    }, onError: (error) {
      setState(() {
        _statusMessage = "Error durante el escaneo: $error";
        _isScanning = false;
      });
    });

    // Detenemos el escaneo después de 30 segundos
    await Future.delayed(const Duration(seconds: 30));
    await subscription.cancel();

    setState(() {
      _isScanning = false;
      if (_devicesList.isEmpty) {
        _statusMessage = "No se encontraron dispositivos.";
      } else {
        _statusMessage = "Dispositivos encontrados:";
      }
    });
  }

  void _connectToDevice(DiscoveredDevice device) async {
    try {
      // Muestra un mensaje mientras se conecta
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conectando al dispositivo...')),
      );

      final connection = _ble.connectToDevice(
        id: device.id,
        servicesWithCharacteristicsToDiscover: {}, // Descubrir todas las características
      );

      connection.listen(
        (connectionState) {
          print('Estado de conexión: $connectionState');
          if (connectionState.connectionState == DeviceConnectionState.connected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Conexión establecida')),
            );

            // Llama a la función para leer datos
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
      // Descubre servicios y características
      final discoveredServices = await _ble.discoverServices(deviceId);
      for (var service in discoveredServices) {
        print('Servicio encontrado: ${service.serviceId}');
        for (var characteristic in service.characteristics) {
          print('  Característica: ${characteristic.characteristicId}');

          // Crear un QualifiedCharacteristic para esta característica
          final qualifiedCharacteristic = QualifiedCharacteristic(
            deviceId: deviceId,
            serviceId: service.serviceId,
            characteristicId: characteristic.characteristicId,
          );

          // Leer los datos directamente si la característica es legible
          if (characteristic.isReadable) {
            final value = await _ble.readCharacteristic(qualifiedCharacteristic);
            print('Datos leídos de ${characteristic.characteristicId}: $value');
          }

          // Suscribirse si la característica es notificable
          if (characteristic.isNotifiable) {
            _ble.subscribeToCharacteristic(qualifiedCharacteristic).listen(
              (data) {
                // Decodifica los datos recibidos
                if (data.length >= 12) {
                  final x = _decodeFloat32(data.sublist(0, 4));
                  final y = _decodeFloat32(data.sublist(4, 8));
                  final z = _decodeFloat32(data.sublist(8, 12));

                  setState(() {
                    _receivedData = "Acelerómetro:\nX=$x\nY=$y\nZ=$z";
                  });
                } else {
                  setState(() {
                    _receivedData = "Datos insuficientes recibidos: $data";
                  });
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

  double _decodeFloat32(List<int> bytes) {
    final buffer = Uint8List.fromList(bytes).buffer.asByteData();
    return buffer.getFloat32(0, Endian.little);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          ElevatedButton(
            onPressed: _isScanning ? null : _scanForDevices,
            child: const Text('Scan Bluetooth Devices'),
          ),
          const SizedBox(height: 10),
          if (_isScanning) const CircularProgressIndicator(),
          if (_statusMessage.isNotEmpty) Text(_statusMessage),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _devicesList.length,
              itemBuilder: (context, index) {
                final device = _devicesList[index];
                return ListTile(
                  title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                  subtitle: Text(
                    'ID: ${device.id}\nRSSI: ${device.rssi}',
                  ),
                  onTap: () {
                    // Muestra un mensaje al seleccionar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Seleccionaste el dispositivo: ${device.name.isNotEmpty ? device.name : device.id}')),
                    );

                    // Llama a _connectToDevice sin await
                    _connectToDevice(device);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          if (_receivedData.isNotEmpty) Text(_receivedData, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
