import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../services/api_service.dart';
import '../models/train.dart';
import '../models/palang.dart';
import '../models/camera.dart';
import '../widgets/profile_menu.dart';
import '../widgets/filter_button.dart';
import '../widgets/mjpeg_widget.dart'; // ← TAMBAHKAN INI

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

enum TimeFilter { oneMinute, fiveMinutes, tenMinutes, thirtyMinutes }

class _HomeState extends State<Home> {
  // Otomatis dari .env (auto-detect IP laptop)
  final api = ApiService(
    baseUrl: dotenv.env['API_BASE_URL'] ?? "http://192.168.1.41:4000",
  );

  // // Manual hardcode (untuk testing jika .env bermasalah)
  // final api = ApiService(baseUrl: "http://192.168.1.42:4000");

  String? titikKereta;
  String? ipCamera;
  Timer? _timer;
  MqttServerClient? mqtt;

  double? speedSegmen;
  Timer? _realtimeTimer;
  int? idSegmen;

  // ========== STATE UNTUK CAMERA STREAM ==========
  bool isStreamActive = false; // Track apakah user sudah tap untuk lihat stream

  List<Train> trains = [];
  List<Palang> palangs = [];
  List<Camera> cameras = [];
  bool isLoading = true;
  String? errorMessage;

  // Data untuk grafik kecepatan kereta (line chart)
  // HISTORY
  TimeFilter selectedFilter = TimeFilter.fiveMinutes;
  List<FlSpot> historySpeedData = [];
  List<String> historyTimestamps = [];

  String get filterQuery {
    switch (selectedFilter) {
      case TimeFilter.oneMinute:
        return "1m";
      case TimeFilter.fiveMinutes:
        return "5m";
      case TimeFilter.tenMinutes:
        return "10m";
      case TimeFilter.thirtyMinutes:
        return "30m";
    }
  }

  // REALTIME
  List<FlSpot> realtimeSpeedData = [];
  List<String> realtimeTimestamps = [];

  int maxSpeedPoints = 10;

  // PageController untuk carousel grafik
  PageController _chartPageController = PageController();
  int _currentChartIndex = 0;

  @override
  void initState() {
    super.initState();
    connectMQTT();
    fetchData();

    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => loadSpeedHistory(),
    );

    _timer = Timer.periodic(const Duration(seconds: 2), (_) => fetchData());
    _realtimeTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => loadRealtimeChart(),
    );
  }

  Future<void> connectMQTT() async {
    mqtt = MqttServerClient(
      '9e108cb03c734f0394b0f0b49508ec1e.s1.eu.hivemq.cloud',
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
    );

    mqtt!
      ..port = 8883
      ..secure = true
      ..keepAlivePeriod = 20
      ..logging(on: false);

    mqtt!.connectionMessage = MqttConnectMessage()
        .authenticateAs("Device02", "Device02")
        .withClientIdentifier(mqtt!.clientIdentifier!)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    try {
      await mqtt!.connect();
      if (mqtt!.connectionStatus!.state != MqttConnectionState.connected) {
        debugPrint("❌ MQTT gagal connect");
        return;
      }
      debugPrint("✅ MQTT Connected");
    } catch (e) {
      debugPrint("❌ MQTT ERROR: $e");
      mqtt!.disconnect();
      return;
    }

    // ===== SUBSCRIBE =====
    mqtt!.subscribe("smartTrain/speedometer", MqttQos.atMostOnce);
    mqtt!.subscribe("smartTrain/location", MqttQos.atMostOnce);
    mqtt!.subscribe("smartTrain/camera/ip", MqttQos.atMostOnce);

    // ===== LISTENER =====
    mqtt!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final msg = messages.first;
      final topic = msg.topic;
      final rec = msg.payload as MqttPublishMessage;

      final payload = MqttPublishPayload.bytesToStringAsString(
        rec.payload.message,
      );

      debugPrint("📥 MQTT [$topic] : $payload");

      try {
        final data = jsonDecode(payload);

        // ================= SPEED (REALTIME ONLY) =================
        if (topic == "smartTrain/speedometer") {
          double? newSpeed;

          if (data.containsKey("kecepatan_S")) {
            newSpeed = double.tryParse(data["kecepatan_S"].toString());
          } else if (data.containsKey("kecepatan_s")) {
            newSpeed = double.tryParse(data["kecepatan_s"].toString());
          } else if (data["tipe"] == "segmen") {
            newSpeed = double.tryParse(data["kecepatan"].toString());
          }

          if (newSpeed != null && mounted) {
            setState(() {
              speedSegmen = newSpeed; // ⬅️ hanya ini
            });
          }
        }

        // ================= LOCATION =================
        if (topic == "smartTrain/location" && data["titik"] != null) {
          if (mounted) {
            setState(() {
              titikKereta = data["titik"];
            });
          }
        }

        // ================= IP CAMERA =================
        if (topic == "smartTrain/camera/ip" && data["ip"] != null) {
          if (mounted) {
            setState(() {
              ipCamera = data["ip"].toString();
            });
          }
        }
      } catch (e) {
        debugPrint("❌ MQTT JSON error: $e");
      }
    });
  }

  Future<void> loadSpeedHistory() async {
    final data = await api.fetchSpeedHistory(filter: filterQuery);

    List<FlSpot> spots = [];
    List<String> timestamps = [];

    for (int i = 0; i < data.length; i++) {
      final speed = double.tryParse(data[i]["speed"].toString()) ?? 0;
      spots.add(FlSpot(i.toDouble(), speed));
      timestamps.add(data[i]["created_at"]);
    }

    if (!mounted) return;

    setState(() {
      historySpeedData = spots;
      historyTimestamps = timestamps;
    });
  }

  Future<void> loadRealtimeChart() async {
    final data = await api.fetchRealtimeSpeed();

    List<FlSpot> spots = [];
    realtimeTimestamps.clear();

    for (int i = 0; i < data.length; i++) {
      final speed = double.tryParse(data[i]['speed'].toString()) ?? 0;
      spots.add(FlSpot(i.toDouble(), speed));
      realtimeTimestamps.add(data[i]['created_at']);
    }

    setState(() {
      realtimeSpeedData = spots;
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
    _chartPageController.dispose();
    _realtimeTimer?.cancel();
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

                      // ========== CAMERA PREVIEW POV ==========
                      _buildCameraPreview(),

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
                  ipCamera ?? 'offline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ipCamera != null ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== CAROUSEL GRAFIK ==========
  Widget _buildChartCarousel() {
    final List<Map<String, dynamic>> charts = [
      {
        'title': 'Kecepatan Kereta Rata-rata',
        'action': SpeedFilterButton(
          selectedFilter: selectedFilter,
          onChanged: (filter) {
            setState(() => selectedFilter = filter);
            loadSpeedHistory();
          },
        ),
        'widget': _buildLineChart(
          data: historySpeedData,
          timestamps: historyTimestamps,
        ),
      },
      {
        'title': 'Kecepatan Kereta Realtime',
        'action': null, // ❌ TIDAK ADA FILTER
        'widget': _buildLineChart(
          data: realtimeSpeedData,
          timestamps: realtimeTimestamps,
        ),
      },
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

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (charts[_currentChartIndex]['action'] != null)
                charts[_currentChartIndex]['action'],
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

  // ========== BAR CHART (untuk data kategorikal) ==========
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

  // ========== CHART CARD WRAPPER (untuk single chart tanpa carousel) ==========
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

  // ========== LINE CHART (untuk trend/kecepatan) ==========
  Widget _buildLineChart({
    required List<FlSpot> data,
    required List<String> timestamps,
  }) {
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
        maxY: data.isEmpty
            ? 100
            : data.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 10,
        lineTouchData: LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (data.length / 6).clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                int index = value.toInt();

                if (index < 0 || index >= timestamps.length) {
                  return const SizedBox.shrink();
                }

                final dt = DateTime.parse(
                  timestamps[index].replaceAll(" ", "T"),
                );

                final label =
                    "${dt.day}/${_monthName(dt.month)}/${dt.year}\n"
                    "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";

                return Text(label, style: const TextStyle(fontSize: 7));
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
            spots: data.isEmpty ? [FlSpot(0, 0)] : data,
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

  // ========== CAMERA PREVIEW / POV ==========
  Widget _buildCameraPreview() {
    // Cek apakah kamera aktif dan ada IP
    bool isCameraActive =
        cameras.isNotEmpty && cameras[0].status.toLowerCase() == "aktif";

    bool hasIpAddress =
        ipCamera != null && ipCamera!.isNotEmpty && ipCamera != 'offline';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.camera_alt, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Live Camera Feed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCameraActive && hasIpAddress
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCameraActive && hasIpAddress ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCameraActive && hasIpAddress
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Camera Feed Container
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildCameraContent(isCameraActive, hasIpAddress),
            ),
          ),

          // IP Address Info
          if (hasIpAddress)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'IP: $ipCamera',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Website Viewing Info (SELALU MUNCUL)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'To view the feed in the Website or other devices, you must unsee the current feed',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraContent(bool isCameraActive, bool hasIpAddress) {
    // Jika kamera tidak aktif atau tidak ada IP
    if (!isCameraActive || !hasIpAddress) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 60,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              !isCameraActive ? 'Kamera Tidak Aktif' : 'Menunggu IP Address...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final String streamUrl = 'http://$ipCamera/stream';

    // ========== WRAPPER DENGAN TAP GESTURE ==========
    return GestureDetector(
      onTap: () {
        setState(() {
          isStreamActive = !isStreamActive; // Toggle stream
        });
        debugPrint("🎥 Stream ${isStreamActive ? 'STARTED' : 'STOPPED'}");
      },
      child: Stack(
        children: [
          // ========== VIDEO STREAM ATAU PLACEHOLDER ==========
          if (isStreamActive)
            MjpegWidget(
              key: ValueKey(streamUrl),
              stream: streamUrl,
              fit: BoxFit.cover,
            )
          else
            // Placeholder ketika belum tap
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 80,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Camera Ready',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // ========== TEXT OVERLAY (TAP TO SEE / UNSEE) ==========
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isStreamActive ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isStreamActive ? 'Tap to Unsee' : 'Tap to See',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
