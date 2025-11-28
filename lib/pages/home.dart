import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
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
  final api = ApiService(baseUrl: 'http://192.168.1.224:4000');
  Timer? _timer;

  // MQTT Client
  MqttServerClient? mqtt;

  // Speed Realtime dari MQTT
  double? speedSegmen;
  int? idSegmen;

  List<Train> trains = [];
  List<Palang> palangs = [];
  List<Camera> cameras = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    connectMQTT();
    fetchData();

    // Auto refresh setiap 2 detik
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => fetchData());
  }

  // =============================
  // 🔴 CONNECT MQTT
  // =============================
  Future<void> connectMQTT() async {
    mqtt = MqttServerClient(
        '9e108cb03c734f0394b0f0b49508ec1e.s1.eu.hivemq.cloud', '');
    
    mqtt!.port = 8883;
    mqtt!.secure = true;
    mqtt!.logging(on: true); // AKTIFKAN LOGGING UNTUK DEBUG
    mqtt!.keepAlivePeriod = 20;

    // Auth
    mqtt!.connectionMessage = MqttConnectMessage()
        .authenticateAs("Device02", "Device02")
        .withClientIdentifier(
            "flutter_client_${DateTime.now().millisecondsSinceEpoch}")
        .startClean();

    try {
      await mqtt!.connect();
      print("✅ MQTT Connected!");
    } catch (e) {
      print("❌ MQTT ERROR: $e");
      return;
    }

    // Pastikan koneksi berhasil
    if (mqtt!.connectionStatus!.state != MqttConnectionState.connected) {
      print("❌ MQTT tidak terkoneksi!");
      return;
    }

    mqtt!.subscribe("esp32/kecepatan", MqttQos.atMostOnce);
    print("✅ Subscribe ke topic: esp32/kecepatan");

    // Listen message
    mqtt!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final MqttReceivedMessage<MqttMessage> msg = messages[0];
      final MqttPublishMessage rec = msg.payload as MqttPublishMessage;

      final payload =
          MqttPublishPayload.bytesToStringAsString(rec.payload.message);

      print("📥 MQTT MSG RAW: $payload");

      try {
        final data = jsonDecode(payload);
        print("📦 MQTT DATA PARSED: $data");
        print("🔍 Keys dalam data: ${data.keys.toList()}");

        // CEK SEMUA KEMUNGKINAN KEY
        // 1. Cek kecepatan_S (huruf besar)
        if (data.containsKey("kecepatan_S")) {
          print("✅ Found kecepatan_S");
          setState(() {
            speedSegmen = double.tryParse(data["kecepatan_S"].toString());
            idSegmen = data["id"];
          });
          print("💾 Speed updated: $speedSegmen, ID: $idSegmen");
        }
        // 2. Cek kecepatan_s (huruf kecil)
        else if (data.containsKey("kecepatan_s")) {
          print("✅ Found kecepatan_s");
          setState(() {
            speedSegmen = double.tryParse(data["kecepatan_s"].toString());
            idSegmen = data["id"];
          });
          print("💾 Speed updated: $speedSegmen, ID: $idSegmen");
        }
        // 3. Cek format lama (tipe + kecepatan)
        else if (data.containsKey("tipe") && data["tipe"] == "segmen") {
          print("✅ Found format lama (tipe=segmen)");
          setState(() {
            speedSegmen = double.tryParse(data["kecepatan"].toString());
            idSegmen = data["id"];
          });
          print("💾 Speed updated: $speedSegmen, ID: $idSegmen");
        }
        // 4. Log jika tidak ada yang cocok
        else {
          print("⚠️ Data tidak cocok dengan format yang diharapkan");
          print("⚠️ Data yang diterima: $data");
        }
      } catch (e) {
        print("❌ JSON Decode error: $e");
        print("❌ Payload mentah: $payload");
      }
    });
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
    mqtt?.disconnect();
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
                    // Card kereta - DIGANTI DENGAN DATA MQTT REALTIME
                    Container(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kecepatan Kereta',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                // TAMPILKAN DATA MQTT REALTIME
                                Text(
                                  speedSegmen != null
                                      // ? '${speedSegmen!.toStringAsFixed(3)} cm/s (Segmen $idSegmen)'
                                      ? '${speedSegmen!.toStringAsFixed(3)} cm/s'
                                      : 'Menunggu data...',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Card Grafik
                    Container(
                      height: 350,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      padding: const EdgeInsets.all(20),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title dan Dropdown Dummy
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                "Kendaraan Pelanggar",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.black,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Grafik Dummy
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: 20,
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      getTitlesWidget: (value, meta) => Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),

                                // === Dummy Data ===
                                barGroups: List.generate(10, (i) {
                                  final dummy = [
                                    5,
                                    8,
                                    14,
                                    7,
                                    9,
                                    6,
                                    12,
                                    15,
                                    11,
                                    4,
                                  ];
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: dummy[i].toDouble(),
                                        width: 18,
                                        color: Colors.teal,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
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
                            child: palangs.isEmpty
                                ? const Center(child: Text("No Palang Data"))
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.no_crash,
                                        color: Colors.red,
                                        size: 60,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Palang",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      // STATUS OTOMATIS
                                      Text(
                                        palangs[0].status,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              palangs[0].status.toLowerCase() ==
                                                      "terbuka"
                                                  ? Colors.green
                                                  : Colors.red,
                                        ),
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
                            child: cameras.isEmpty
                                ? const Center(child: Text("No Camera Data"))
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.videocam,
                                        color: Colors.red,
                                        size: 60,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Camera",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      // STATUS OTOMATIS
                                      Text(
                                        cameras[0].status,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              cameras[0].status.toLowerCase() ==
                                                      "aktif"
                                                  ? Colors.green
                                                  : Colors.red,
                                        ),
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