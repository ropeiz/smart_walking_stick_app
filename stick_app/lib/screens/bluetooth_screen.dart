import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

class BluetoothScreen extends StatefulWidget {
  @override
  _BluetoothScreenState createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final List<DiscoveredDevice> _devicesList = [];
  bool _isScanning = false;
  String _statusMessage = "";
  String _receivedData = ""; // Para mostrar los datos decodificados

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

    // Detenemos el escaneo después de 10 segundos
    await Future.delayed(const Duration(seconds: 10));
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

          // Suscribirse si la característica es notificable
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
      ),
    );
  }
}
