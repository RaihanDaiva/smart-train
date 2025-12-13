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
import '../widgets/profile_menu.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Kampus
  final api = ApiService(baseUrl: "http://192.168.128.142:4000");

  // Rumah
  // final api = ApiService(baseUrl: "http://192.168.1.75:4000");
  List<String> speedTimestamps = [];

  String? titikKereta;
  String? ipCamera;
  Timer? _timer;
  MqttServerClient? mqtt;

  double? speedSegmen;
  int? idSegmen;

  List<Train> trains = [];
  List<Palang> palangs = [];
  List<Camera> cameras = [];
  bool isLoading = true;
  String? errorMessage;

  // Data untuk grafik kecepatan kereta (line chart)
  List<FlSpot> speedData = [];
  int maxSpeedPoints = 10;

  // PageController untuk carousel grafik
  PageController _chartPageController = PageController();
  int _currentChartIndex = 0;

  @override
  void initState() {
    super.initState();
    connectMQTT();
    fetchData();
    loadSpeedHistory();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => fetchData());
  }

  Future<void> connectMQTT() async {
    mqtt = MqttServerClient(
      '9e108cb03c734f0394b0f0b49508ec1e.s1.eu.hivemq.cloud',
      '',
    );

    mqtt!.port = 8883;
    mqtt!.secure = true;
    mqtt!.logging(on: true);
    mqtt!.keepAlivePeriod = 20;

    mqtt!.connectionMessage = MqttConnectMessage()
        .authenticateAs("Device02", "Device02")
        .withClientIdentifier(
          "flutter_client_${DateTime.now().millisecondsSinceEpoch}",
        )
        .startClean();

    try {
      await mqtt!.connect();
      print("✅ MQTT Connected!");
    } catch (e) {
      print("❌ MQTT ERROR: $e");
      return;
    }

    if (mqtt!.connectionStatus!.state != MqttConnectionState.connected) {
      print("❌ MQTT tidak terkoneksi!");
      return;
    }

    mqtt!.subscribe("smartTrain/speedometer", MqttQos.atMostOnce);
    print("✅ Subscribe ke topic: smartTrain/speedometer");

    mqtt!.subscribe("smartTrain/location", MqttQos.atMostOnce);
    print("✅ Subscribe ke topic: smartTrain/location");

    mqtt!.subscribe("smartTrain/camera/ip", MqttQos.atMostOnce);
    print("✅ Subscribe ke topic: smartTrain/camera/ip");

    mqtt!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final MqttReceivedMessage<MqttMessage> msg = messages[0];
      final topic = msg.topic; // <-- ambil nama topic
      final rec = msg.payload as MqttPublishMessage;

      final payload = MqttPublishPayload.bytesToStringAsString(
        rec.payload.message,
      );

      print("📥 MQTT MSG [$topic] : $payload");

      try {
        final data = jsonDecode(payload);

        // ========= TOPIC: smartTrain/speedometer =========
        if (topic == "smartTrain/speedometer") {
          double? newSpeed;

          if (data.containsKey("kecepatan_S")) {
            newSpeed = double.tryParse(data["kecepatan_S"].toString());
            idSegmen = data["id"];
          } else if (data.containsKey("kecepatan_s")) {
            newSpeed = double.tryParse(data["kecepatan_s"].toString());
            idSegmen = data["id"];
          } else if (data.containsKey("tipe") && data["tipe"] == "segmen") {
            newSpeed = double.tryParse(data["kecepatan"].toString());
            idSegmen = data["id"];
          }

          if (newSpeed != null) {
            setState(() {
              speedSegmen = newSpeed!;

              speedData.add(FlSpot(speedData.length.toDouble(), newSpeed));

              if (speedData.length > maxSpeedPoints) {
                speedData.removeAt(0);
                speedData = speedData
                    .asMap()
                    .entries
                    .map((e) => FlSpot(e.key.toDouble(), e.value.y))
                    .toList();
              }
            });
          }
        }

        // ========= TOPIC: smartTrain/location =========
        if (topic == "smartTrain/location") {
          if (data.containsKey("titik")) {
            setState(() {
              titikKereta = data["titik"]; // simpan titik dari MQTT
            });
            print("📍 Titik Kereta: $titikKereta");
          }
        }

        // ==========================
        // TOPIC IP CAMERA
        // ==========================
        if (topic == "smartTrain/camera/ip") {
          if (data.containsKey("ip")) {
            setState(() {
              ipCamera = data["ip"].toString();
            });

            print("📷 IP Camera Updated: $ipCamera");
          }
        }
      } catch (e) {
        print("❌ JSON Decode error: $e");
      }
    });
  }

  Future<void> loadSpeedHistory() async {
    try {
      final data = await api.fetchSpeedHistory();

      List<FlSpot> spots = [];
      speedTimestamps.clear();

      for (int i = 0; i < data.length; i++) {
        final speed = double.tryParse(data[i]["speed"].toString()) ?? 0;

        // Tambah titik grafik
        spots.add(FlSpot(i.toDouble(), speed));

        // Simpan timestamp
        speedTimestamps.add(data[i]["created_at"].toString());
      }

      setState(() {
        speedData = spots; // ✔ spots sekarang benar terisi
      });
    } catch (e) {
      print("❌ Gagal load speed history: $e");
    }
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
    _chartPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Header
        Container(
          height: 360,
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
                ],
              ),
            ],
          ),
        ),

        // Content
        Container(
          height: double.infinity,
          child: Positioned.fill(
            top: 120,
            child: Builder(
              builder: (_) {
                if (errorMessage != null) {
                  return Center(child: Text("Error: $errorMessage"));
                }

                return Container(
                  transform: Matrix4.translationValues(0, 150, 0),
                  child: ListView(
                    padding: const EdgeInsets.only(top: 0, bottom: 0),
                    children: [
                      // Card Kecepatan Kereta
                      _buildSpeedCard(),

                      // ========== GRAFIK CAROUSEL (1 CARD DENGAN SWIPE) ==========
                      _buildChartCarousel(),

                      // Card Keberadaan Kereta
                      _buildLocationCard(),

                      _buildIpCamCard(),

                      // Card Status Palang & Camera
                      Row(children: [_buildPalangCard(), _buildCameraCard()]),
                      SizedBox(height: 160),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          const Icon(Icons.train, color: Colors.red, size: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kecepatan Kereta',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                Text(
                  speedSegmen != null
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
    );
  }

  Widget _buildLocationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          const Icon(Icons.location_on, color: Colors.red, size: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keberadaan Kereta',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                Text(
                  titikKereta != null ? titikKereta! : 'Menunggu data...',
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
    );
  }

  Widget _buildIpCamCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          const Icon(Icons.videocam, color: Colors.red, size: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IP Camera',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                Text(
                  ipCamera ?? 'Menunggu data...',
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
    );
  }

  Widget _buildChartCard({required String title, required Widget child}) {
    return Container(
      height: 350,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Colors.black),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  // ========== CAROUSEL GRAFIK ==========
  Widget _buildChartCarousel() {
    final List<Map<String, dynamic>> charts = [
      {
        'title': 'Kendaraan Pelanggar',
        'widget': _buildBarChart([5, 8, 14, 7, 9, 6, 12, 15, 11, 4]),
      },
      {
        'title': 'Kendaraan Melintas',
        'widget': _buildBarChart([7, 12, 6, 13, 8, 10, 15, 11, 9, 5]),
      },
      {'title': 'Kecepatan Kereta', 'widget': _buildLineChart()},
    ];

    return Container(
      height: 380,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        children: [
          // Header dengan tombol navigasi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tombol Previous
              IconButton(
                onPressed: _currentChartIndex > 0
                    ? () {
                        _chartPageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: _currentChartIndex > 0 ? Colors.red : Colors.grey,
                  size: 20,
                ),
              ),

              // Title Chart
              Expanded(
                child: Text(
                  charts[_currentChartIndex]['title'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Tombol Next
              IconButton(
                onPressed: _currentChartIndex < charts.length - 1
                    ? () {
                        _chartPageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: _currentChartIndex < charts.length - 1
                      ? Colors.red
                      : Colors.grey,
                  size: 20,
                ),
              ),
            ],
          ),
          // Chart PageView
          Expanded(
            child: PageView.builder(
              controller: _chartPageController,
              onPageChanged: (index) {
                setState(() {
                  _currentChartIndex = index;
                });
              },
              itemCount: charts.length,
              itemBuilder: (context, index) {
                return charts[index]['widget'];
              },
            ),
          ),

          // Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              charts.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                width: _currentChartIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentChartIndex == index
                      ? Colors.red
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<int> data) {
    return BarChart(
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
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i].toDouble(),
                width: 18,
                color: Colors.teal,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLineChart() {
    String _monthName(int month) {
      const months = [
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "10",
        "11",
        "12",
      ];
      return months[month - 1];
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: speedData.isEmpty
            ? 100
            : speedData.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 10,
        lineTouchData: LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (speedData.length / 6).clamp(
                1,
                double.infinity,
              ), // biar tidak terlalu rapat
              getTitlesWidget: (value, meta) {
                int index = value.toInt();

                if (index < 0 || index >= speedTimestamps.length) {
                  return const SizedBox.shrink();
                }

                // format yyyy-MM-dd HH:mm:ss dari API
                final dt = DateTime.parse(
                  speedTimestamps[index].replaceAll(" ", "T"),
                );

                // Format: 25 Nov 2025
                final label =
                    "${dt.day}/${_monthName(dt.month)}/${dt.year}\n"
                    "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";

                return Transform.rotate(
                  angle: 0, // rotasi sekitar -40 derajat
                  child: Text(label, style: const TextStyle(fontSize: 7)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        lineBarsData: [
          LineChartBarData(
            spots: speedData.isEmpty ? [FlSpot(0, 0)] : speedData,
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.red.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPalangCard() {
    return Expanded(
      child: Container(
        height: 150,
        margin: const EdgeInsets.only(left: 20, right: 10, top: 10, bottom: 10),
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
                  const Icon(Icons.no_crash, color: Colors.red, size: 60),
                  const SizedBox(height: 8),
                  const Text(
                    "Palang",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    palangs[0].status,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: palangs[0].status.toLowerCase() == "terbuka"
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCameraCard() {
    return Expanded(
      child: Container(
        height: 150,
        margin: const EdgeInsets.only(left: 10, right: 20, top: 10, bottom: 10),
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
                  const Icon(Icons.videocam, color: Colors.red, size: 60),
                  const SizedBox(height: 8),
                  const Text(
                    "Camera",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    cameras[0].status,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: cameras[0].status.toLowerCase() == "aktif"
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
