import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  final FlutterSecureStorage secureStorage;

  Map<String, dynamic>? user;
  bool _loading = false;

  AuthProvider({required this.api, FlutterSecureStorage? storage})
      : secureStorage = storage ?? const FlutterSecureStorage();

  bool get isAuthenticated => user != null;
  bool get loading => _loading;

  // ============================================================
  // INIT — Cek sesi pengguna
  // ============================================================
  Future<void> init() async {
    final userId = await secureStorage.read(key: "user_id");

    if (userId != null) {
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
      // Login API -> dapat info user & token
      final data = await api.login(email, password);

      // Simpan usernya
      user = {
        "id": data["id"],
        "name": data["name"],
        "email": data["email"],
      };

      // Simpan ID user ke secure storage
      await secureStorage.write(
        key: "user_id",
        value: data["id"].toString(),
      );

      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      notifyListeners();
      rethrow; // lempar error ke UI
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

      // otomatis login setelah register
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

    await secureStorage.delete(key: "user_id");

    notifyListeners();
  }
}
