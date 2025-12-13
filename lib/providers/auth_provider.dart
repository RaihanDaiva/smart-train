import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  final FlutterSecureStorage secureStorage;

  Map<String, dynamic>? user;
  String? token;
  bool _loading = false;

  AuthProvider({required this.api, FlutterSecureStorage? storage})
      : secureStorage = storage ?? const FlutterSecureStorage();

  bool get isAuthenticated => user != null;
  bool get loading => _loading;

  // ============================================================
  // INIT — Cek sesi pengguna
  // ============================================================
  Future<void> init() async {
    token = await secureStorage.read(key: "token");
    final userId = await secureStorage.read(key: "user_id");

    if (token != null && userId != null) {
      try {
        user = await api.getUserById(userId);
      } catch (e) {
        await logout();
      }
    }

    notifyListeners();
  }

  // ============================================================
  // LOGIN
  // ============================================================
  Future<void> login(String email, String password) async {
    _loading = true;
    notifyListeners();

    try {
      final data = await api.login(email, password);
      print(data);


      // Sesuai API kamu
      token = data["accessToken"];
      final u = data["user"];

      user = {
        "id": u["id"],
        "name": u["name"],
        "email": u["email"],
      };

      await secureStorage.write(key: "token", value: token);
      await secureStorage.write(key: "user_id", value: u["id"].toString());

      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
    
  }

  // ============================================================
  // REGISTER
  // ============================================================
  Future<void> register(String name, String email, String password) async {
    _loading = true;
    notifyListeners();

    try {
      await api.register(name, email, password);
      await login(email, password);

      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  Future<void> logout() async {
    user = null;
    token = null;

    await secureStorage.delete(key: "token");
    await secureStorage.delete(key: "user_id");

    notifyListeners();
  }
}
