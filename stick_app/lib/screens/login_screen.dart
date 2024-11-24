import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

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
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

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

    _scanSubscription = _ble.scanForDevices(withServices: []).listen((device) {
      print("Dispositivo detectado: ${device.name} (${device.id})");

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

    // Detener el escaneo automáticamente después de 30 segundos
    Future.delayed(const Duration(seconds: 30), () {
      _stopScanning();
    });
  }

  void _stopScanning() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
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
    if (_isScanning) {
      _stopScanning();
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conectando al dispositivo...')),
      );

      final connection = _ble.connectToDevice(
        id: device.id,
        servicesWithCharacteristicsToDiscover: {},
      );

      connection.listen(
        (connectionState) {
          print('Estado de conexión: $connectionState');
          if (connectionState.connectionState == DeviceConnectionState.connected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Conexión establecida')),
            );

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
        print('Servicio encontrado: ${service.serviceId}');
        for (var characteristic in service.characteristics) {
          print('  Característica: ${characteristic.characteristicId}');

          final qualifiedCharacteristic = QualifiedCharacteristic(
            deviceId: deviceId,
            serviceId: service.serviceId,
            characteristicId: characteristic.characteristicId,
          );

          if (characteristic.isReadable) {
            final value = await _ble.readCharacteristic(qualifiedCharacteristic);
            print('Datos leídos de ${characteristic.characteristicId}: $value');
          }

          if (characteristic.isNotifiable) {
            _ble.subscribeToCharacteristic(qualifiedCharacteristic).listen(
              (data) {
                print('Datos recibidos de ${characteristic.characteristicId}: $data');
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Seleccionaste el dispositivo: ${device.name.isNotEmpty ? device.name : device.id}')),
                    );

                    _connectToDevice(device);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
