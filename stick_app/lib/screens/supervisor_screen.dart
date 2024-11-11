import 'package:flutter/material.dart';
import 'start_screen.dart';

class SupervisorScreen extends StatelessWidget {
  const SupervisorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor'),
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
              return {'Logs', 'Cerrar sesión'}.map((String choice) {
                return PopupMenuItem<String>(value: choice, child: Text(choice));
              }).toList();
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Aquí va el mapa para el Supervisor', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
