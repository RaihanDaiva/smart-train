import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/train.dart';

class ApiService {
  final String baseUrl;
  ApiService({required this.baseUrl});

  Future<List<Train>> fetchTrain() async {
    final resp = await http.get(Uri.parse('$baseUrl/train_speed'));
    if (resp.statusCode == 200) {
      final List jsonList = jsonDecode(resp.body);
      return jsonList.map((e) => Train.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load train');
    }
  }

  Future<Train> createTrain(String speed) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/train_speed'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'speed': speed}),
    );
    if (resp.statusCode == 201) {
      return Train.fromJson(jsonDecode(resp.body));
    } else {
      throw Exception('Create failed');
    }
  }
}
