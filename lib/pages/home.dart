import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/train.dart';
import '../models/palang.dart';
import '../models/camera.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final api = ApiService(baseUrl: 'http://192.168.69.226:3000');
  Timer? _timer;

  List<Train> trains = [];
  List<Palang> palangs = [];
  List<Camera> cameras = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchData();

    // Auto refresh setiap 2 detik
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => fetchData());
  }

  Future<void> fetchData() async {
    try {
      final trainData = await api.fetchTrain();
      final palangData = await api.fetchPalang();
      final cameraData = await api.fetchCamera();
      if (!mounted) return;

      setState(() {
        trains = trainData;
        palangs = palangData;
        cameras = cameraData;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 🔴 Background AppBar besar
        Container(
          height: 350,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEB2525), Color(0xFF991b1b)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Home',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 🟢 Konten List Data API (TIDAK KEDIP!)
        Container(
          // color: const Color.fromARGB(255, 54, 73, 244),
          height: double.infinity,

          child: Positioned.fill(
            top: 120,
            child: Builder(
              builder: (_) {
                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (errorMessage != null) {
                  return Center(child: Text("Error: $errorMessage"));
                }

                if (trains.isEmpty) {
                  return const Center(child: Text("Tidak ada data"));
                }

                return ListView(
                  padding: const EdgeInsets.only(top: 150, bottom: 0),
                  children: [
                    // Card kereta
                    ...trains.map(
                      (p) => Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.train,
                              color: Colors.red,
                              size: 60,
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kecepatan Kereta',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${p.speed} km/jam',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Card Grafik
                    Container(
                      height: 350,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    // Card status palang dan camera
                    Row(
                      children: [
                        // Card Palang
                        Expanded(
                          child: Container(
                            height: 150,
                            margin: const EdgeInsets.only(
                              left: 20,
                              right: 10,
                              top: 10,
                              bottom: 10,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Card Camera
                        Expanded(
                          child: Container(
                            height: 150,
                            margin: const EdgeInsets.only(
                              left: 10,
                              right: 20,
                              top: 10,
                              bottom: 10,
                            ),

                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
