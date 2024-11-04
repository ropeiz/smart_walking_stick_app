import 'package:flutter/material.dart';
import 'carrier_screen.dart';
import 'supervisor_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String caneCode = '';
  bool isCarrier = false;
  bool isSupervisor = false;

  void _login() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (isCarrier) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CarrierScreen()),
        );
      } else if (isSupervisor) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SupervisorScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(labelText: 'Código de bastón'),
                onSaved: (value) => caneCode = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Introduce el código de bastón';
                  }
                  return null;
                },
              ),
              CheckboxListTile(
                title: Text("Portador"),
                value: isCarrier,
                onChanged: (value) {
                  setState(() {
                    isCarrier = value!;
                    isSupervisor = !value;
                  });
                },
              ),
              CheckboxListTile(
                title: Text("Supervisor"),
                value: isSupervisor,
                onChanged: (value) {
                  setState(() {
                    isSupervisor = value!;
                    isCarrier = !value;
                  });
                },
              ),
              ElevatedButton(
                onPressed: _login,
                child: Text("Iniciar Sesión"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
