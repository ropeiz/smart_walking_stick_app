import 'package:flutter/material.dart';

class SupervisorScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Supervisor"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (choice) {
              if (choice == 'Cerrar sesión') {
                Navigator.pop(context);
              } else if (choice == 'Log') {
                // Navegar a la pantalla del log de notificaciones
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LogScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return ['Cerrar sesión', 'Log'].map((String choice) {
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
        child: Text("Mapa con ubicación del bastón vinculado"),
      ),
    );
  }
}

class LogScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Log de Notificaciones")),
      body: Center(
        child: Text("Aquí se muestran las últimas notificaciones"),
      ),
    );
  }
}
