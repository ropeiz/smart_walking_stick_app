import 'package:flutter/material.dart';
import 'start_screen.dart';

class CarrierScreen extends StatelessWidget {
  const CarrierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrier'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Cerrar sesión') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const StartScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Cerrar sesión'}.map((String choice) {
                return PopupMenuItem<String>(value: choice, child: Text(choice));
              }).toList();
            },
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Acción SOS
          },
          style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red, // Cambié 'primary' por 'backgroundColor'
          minimumSize: const Size(200, 200)),
          child: const Text('SOS', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
