import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stick_app/services/cognito_manager.dart';
import 'carrier_screen.dart';
import 'supervisor_screen.dart';
import 'package:stick_app/services/session_manager.dart';

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
  late final CognitoManager _cognitoManager;
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final List<DiscoveredDevice> _devicesList = [];
  bool _isScanning = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _cognitoManager = CognitoManager();
    _cognitoManager.init();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  void _signIn() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      final user = await _cognitoManager.signIn(email, password);
      final userType = user.claims['custom:Type'] ?? 'Carrier';

      // Guardar sesión del usuario
      await SessionManager.saveUserSession(userType);

      if (userType == 'Carrier') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CarrierScreen()),
        );
      } else if (userType == 'Supervisor') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SupervisorScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tipo de usuario desconocido')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _scanForDevices() async {
    await _requestPermissions();

    setState(() {
      _devicesList.clear();
      _isScanning = true;
      _statusMessage = "Buscando dispositivos BLE...";
    });

    final scanStream = _ble.scanForDevices(withServices: []); // Sin filtros para detectar todos los dispositivos
    final subscription = scanStream.listen((device) {
      setState(() {
        if (!_devicesList.any((d) => d.id == device.id)) {
          _devicesList.add(device);
        }
      });
      print(
          "Dispositivo encontrado: ID=${device.id}, Nombre=${device.name}, RSSI=${device.rssi}, Manufacturer Data=${device.manufacturerData}, Service UUIDs=${device.serviceData.keys}");
    }, onError: (error) {
      setState(() {
        _statusMessage = "Error durante el escaneo: $error";
        _isScanning = false;
      });
    });

    // Detener el escaneo después de 30 segundos
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
            onPressed: _signIn,
            child: const Text('Sign In'),
          ),
          const SizedBox(height: 20),
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
                      'ID: ${device.id}\nRSSI: ${device.rssi}\nManufacturer Data: ${device.manufacturerData}\nService UUIDs: ${device.serviceData.keys.join(", ")}'),
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Seleccionaste el dispositivo: ${device.name.isNotEmpty ? device.name : device.id}')),
                    );
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
