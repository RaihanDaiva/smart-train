import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/train.dart';
import '../models/palang.dart';
import '../models/camera.dart';

class ApiService {
  final String baseUrl;
  ApiService({required this.baseUrl});

  Future<List<Train>> fetchTrain() async {
    final resp = await http.get(Uri.parse('$baseUrl/train/latest'));
    if (resp.statusCode == 200) {
      final jsonObj = jsonDecode(resp.body);
      // Jika respons adalah objek, bungkus ke List
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

  // ...existing code...
  Future<List<Palang>> fetchPalang() async {
    final resp = await http.get(Uri.parse('$baseUrl/palang'));
    if (resp.statusCode == 200) {
      final List jsonList = jsonDecode(resp.body);
      return jsonList.map((e) => Palang.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load palang');
    }
  }

  Future<List<Camera>> fetchCamera() async {
    final resp = await http.get(Uri.parse('$baseUrl/camera'));
    if (resp.statusCode == 200) {
      final List jsonList = jsonDecode(resp.body);
      return jsonList.map((e) => Camera.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load camera');
    }
  }

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
