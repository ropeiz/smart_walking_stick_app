import 'package:flutter/material.dart';
import 'dart:async';

class CarrierScreen extends StatefulWidget {
  @override
  _CarrierScreenState createState() => _CarrierScreenState();
}

class _CarrierScreenState extends State<CarrierScreen> {
  bool isSOSActive = false;
  bool showOkButton = false;
  Color sosColor = Colors.red;
  Timer? _timer;
  Timer? _holdTimer;
  bool isHolding = false;

  void _toggleSOS() {
    setState(() {
      isSOSActive = true;
      showOkButton = true;
      _startSOSAlert();
    });
  }

  void _startSOSAlert() {
    _timer = Timer.periodic(Duration(milliseconds: 250), (timer) {
      setState(() {
        sosColor = sosColor == Colors.red ? Colors.white : Colors.red;
      });
    });
  }

  void _stopSOS() {
    _timer?.cancel();
    setState(() {
      isSOSActive = false;
      showOkButton = false;
      sosColor = Colors.red;
    });
  }

  // Función para iniciar la pulsación prolongada en el botón OK
  void _startHoldTimer() {
    setState(() {
      isHolding = true;
    });
    _holdTimer = Timer(Duration(seconds: 5), () {
      if (isHolding) {
        _stopSOS(); // Ejecuta la acción después de los 5 segundos
      }
    });
  }

  // Función para cancelar la pulsación prolongada si se suelta antes
  void _cancelHoldTimer() {
    setState(() {
      isHolding = false;
    });
    _holdTimer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Portador"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (choice) {
              if (choice == 'Cerrar sesión') {
                Navigator.pop(context);
              }
            },
            itemBuilder: (BuildContext context) {
              return ['Cerrar sesión'].map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Botón SOS grande
            SizedBox(
              width: 300,  // Ancho del botón SOS
              height: 150,  // Alto del botón SOS
              child: ElevatedButton(
                onPressed: _toggleSOS,
                child: Text('SOS', style: TextStyle(fontSize: 36)), // Tamaño de texto grande
                style: ElevatedButton.styleFrom(
                  backgroundColor: sosColor,
                ),
              ),
            ),
            SizedBox(height: 50), // Espaciado entre botones

            // Botón OK grande que requiere pulsación prolongada
            if (showOkButton)
              SizedBox(
                width: 200,  // Ancho del botón OK
                height: 100,  // Alto del botón OK
                child: GestureDetector(
                  onLongPressStart: (_) => _startHoldTimer(),
                  onLongPressEnd: (_) => _cancelHoldTimer(),
                  child: ElevatedButton(
                    onPressed: () {}, // Sin acción de clic
                    child: Text('OK', style: TextStyle(fontSize: 30)), // Texto grande
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
