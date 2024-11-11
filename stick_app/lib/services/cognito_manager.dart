import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:stick_app/config/config.dart';

class CognitoServiceException implements Exception {
  final String message;
  CognitoServiceException(this.message);
}

class User {
  String username;
  bool userConfirmed;
  bool sessionValid;
  String? userSub;
  Map<String, dynamic> claims;
  String userType; // Nuevo campo para tipo de usuario
  String? stickCode; // Nuevo campo para el stick code

  User(this.username, this.userConfirmed, this.sessionValid, this.userSub,
      this.claims, this.userType, this.stickCode);
}

class CognitoManager {
  late final CognitoUserPool userPool;

  CognitoManager();

  Future<void> init() async {
    final config = await loadConfig();
    userPool = CognitoUserPool(config.userPoolID, config.clientID);
  }

  // Modificación de la función signUp para incluir tipo de usuario y stick code
  Future<User> signUp(
      String email, String password, String userType, String stickCode) async {
    final userAttributes = [
      AttributeArg(name: 'email', value: email),
      AttributeArg(name: 'custom:StickCode', value: stickCode), // Stick code
      AttributeArg(name: 'custom:Type', value: userType), // Tipo de usuario

    ];

    try {
      final result = await userPool.signUp(email, password,
          userAttributes: userAttributes);
      return User(
          email,
          result.userConfirmed ?? false,
          false,
          result.userSub,
          {},
          userType, // Almacenamos el tipo de usuario
          stickCode); // Almacenamos el stick code
    } catch (e) {
      throw CognitoServiceException(e.toString());
    }
  }

  Future<bool> confirmUser(String email, String confirmationCode) async {
    final cognitoUser = CognitoUser(email, userPool);
    try {
      return await cognitoUser.confirmRegistration(confirmationCode);
    } catch (e) {
      throw CognitoServiceException(e.toString());
    }
  }

  Future<User> signIn(String email, String password) async {
    final cognitoUser = CognitoUser(email, userPool);
    final authDetails =
        AuthenticationDetails(username: email, password: password);

    try {
      final session = await cognitoUser.authenticateUser(authDetails);
      if (session == null) {
        throw CognitoClientException("session not found");
      }
      var claims = <String, dynamic>{};
      claims.addAll(session.idToken.payload);
      claims.addAll(session.accessToken.payload);

      // Obtener el tipo de usuario y el stick code desde los atributos personalizados
      String userType = claims['custom:Type'] ?? 'Carrier'; // Por defecto Carrier
      String? stickCode = claims['custom:StickCode'];

      return User(
          email,
          true,
          session.isValid(),
          session.idToken.getSub() ?? "",
          claims,
          userType, // Añadir el tipo de usuario al objeto User
          stickCode); // Añadir el stick code al objeto User
    } catch (e) {
      throw CognitoServiceException(e.toString());
    }
  }
}
