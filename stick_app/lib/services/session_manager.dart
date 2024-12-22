import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Para manejar JSON
import 'package:stick_app/services/cognito_manager.dart'; // Importar User

class SessionManager {
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUserRole = 'userRole';
  static const String _keyUserData = 'userData';

static Future<void> saveUserSession(User user) async {
  final prefs = await SharedPreferences.getInstance();
  final userData = {
    'username': user.username,
    'userConfirmed': user.userConfirmed,
    'sessionValid': user.sessionValid,
    'userSub': user.userSub,
    'claims': user.claims,
    'userType': user.userType,
    'stickCode': user.stickCode,
    'jwtToken': user.jwtToken,
  };
  await prefs.setBool(_keyIsLoggedIn, true);
  await prefs.setString(_keyUserRole, user.userType); // Rol del usuario
  await prefs.setString(_keyUserData, jsonEncode(userData)); // Datos completos del usuario
}

static Future<User?> getUserSession() async {
  final prefs = await SharedPreferences.getInstance();
  final userDataString = prefs.getString(_keyUserData);
  if (userDataString != null) {
    final userData = jsonDecode(userDataString) as Map<String, dynamic>;
    return User(
      userData['username'],
      userData['userConfirmed'],
      userData['sessionValid'],
      userData['userSub'],
      userData['claims'] ?? {},
      userData['userType'],
      userData['stickCode'],
      userData['jwtToken'],
    );
  }
  return null; // Si no hay datos de usuario almacenados
}

  static Future<void> clearUserSession() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }
}
