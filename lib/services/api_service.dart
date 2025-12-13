import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/train.dart';
import '../models/palang.dart';
import '../models/camera.dart';

class ApiService {
  final String baseUrl;
  ApiService({required this.baseUrl});

  // ====================================================
  // 🔐 AUTHENTICATION
  // ====================================================

  // ====================================================
  // 🟩 REGISTER user baru
  // ====================================================
  Future<bool> register(String name, String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/register');
    final resp = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"name": name, "email": email, "password": password}),
    );

    return resp.statusCode == 200;
  }

  // ====================================================
  // 🔐 LOGIN (mengembalikan data user, bukan token)
  // ====================================================
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (resp.statusCode != 200) {
      throw Exception("Login gagal");
    }

    final data = jsonDecode(resp.body);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", data["accessToken"]);

    // return token agar AuthProvider bisa memproses
    return data;
  }

  // ---------------- Get User Login (/auth/me) ----------------
  // ====================================================
  // 👤 GET USER BY ID (sesuai backend Node.js)
  // ====================================================
  Future<Map<String, dynamic>> getUserById(String id) async {
    final url = Uri.parse('$baseUrl/auth/user/$id');
    final resp = await http.get(url);

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    } else {
      throw Exception('User not found');
    }
  }

  // ---------------- Logout ----------------
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
  }

  // ====================================================
  // 🟦 TRAIN
  // ====================================================
  Future<List<Train>> fetchTrain() async {
    final resp = await http.get(Uri.parse('$baseUrl/train/latest'));
    if (resp.statusCode == 200) {
      final jsonObj = jsonDecode(resp.body);
      return [Train.fromJson(jsonObj)];
    } else {
      throw Exception('Failed to load train');
    }
  }

  Future<Train> createTrain(String speed) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/train/latest'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'speed': speed}),
    );
    if (resp.statusCode == 201) {
      return Train.fromJson(jsonDecode(resp.body));
    } else {
      throw Exception('Create failed');
    }
  }

  Future<List<Map<String, dynamic>>> fetchSpeedHistory() async {
    final resp = await http.get(Uri.parse('$baseUrl/train/history'))  ;

    if (resp.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(resp.body));
    } else {
      throw Exception('Gagal mengambil data sejarah kecepatan');
    }
  }

  // ====================================================
  // 🟧 PALANG
  // ====================================================
  Future<List<Palang>> fetchPalang() async {
    final resp = await http.get(Uri.parse('$baseUrl/palang'));
    if (resp.statusCode == 200) {
      final List jsonList = jsonDecode(resp.body);
      return jsonList.map((e) => Palang.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load palang');
    }
  }

  // ====================================================
  // 🟪 CAMERA
  // ====================================================
  Future<List<Camera>> fetchCamera() async {
    final resp = await http.get(Uri.parse('$baseUrl/camera'));
    if (resp.statusCode == 200) {
      final List jsonList = jsonDecode(resp.body);
      return jsonList.map((e) => Camera.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load camera');
    }
  }

  // Generic POST
  Future<void> postData(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse("$baseUrl$endpoint");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception("Gagal POST: ${res.body}");
    }
  }
}
