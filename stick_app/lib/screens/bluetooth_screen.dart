import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothScreen extends StatefulWidget {
  @override
  _BluetoothScreenState createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final List<DiscoveredDevice> _devicesList = [];
  bool _isScanning = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
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
    setState(() {
      _devicesList.clear();
      _isScanning = true;
      _statusMessage = "Buscando dispositivos BLE...";
    });

    // Escaneo con filtro de nombre
    final scanStream = _ble.scanForDevices(withServices: []);

    final subscription = scanStream.listen((device) {
      // Filtrar solo dispositivos que contengan "IoT" en el nombre
      if (device.name.contains("IoT")) {
        print("Dispositivo detectado: ${device.name} (${device.id})");

        setState(() {
          if (!_devicesList.any((d) => d.id == device.id)) {
            _devicesList.add(device);
          }
        });
      }
    }, onError: (error) {
      setState(() {
        _statusMessage = "Error durante el escaneo: $error";
        _isScanning = false;
      });
    });

    // Detenemos el escaneo después de 5 segundos
    await Future.delayed(const Duration(seconds: 5));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conectando al dispositivo ${device.name}...')),
      );

      final connection = _ble.connectToDevice(
        id: device.id,
        servicesWithCharacteristicsToDiscover: {},
      );

      connection.listen(
        (connectionState) async {
          print('Estado de conexión: $connectionState');

          if (connectionState.connectionState == DeviceConnectionState.connected) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Conexión establecida con ${device.name}')),
            );

            // Llama a la función para leer datos
            await _discoverAndReadCharacteristics(device.id);
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

  Future<void> _discoverAndReadCharacteristics(String deviceId) async {
    try {
      final discoveredServices = await _ble.discoverServices(deviceId);
      for (var service in discoveredServices) {
        for (var characteristic in service.characteristics) {
          final qualifiedCharacteristic = QualifiedCharacteristic(
            deviceId: deviceId,
            serviceId: service.serviceId,
            characteristicId: characteristic.characteristicId,
          );

          // Suscribirse si la característica es notificable
          if (characteristic.isNotifiable) {
            _ble.subscribeToCharacteristic(qualifiedCharacteristic).listen(
              (data) {
                print('Datos recibidos de ${qualifiedCharacteristic.characteristicId}: $data');
              },
              onError: (error) {
                print('Error al recibir datos: $error');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
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
                    subtitle: Text('ID: ${device.id}\nRSSI: ${device.rssi}'),
                    onTap: () => _connectToDevice(device),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
