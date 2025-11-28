import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/palang.dart';
import '../models/camera.dart';

class Devices extends StatefulWidget {
  const Devices({super.key});

  @override
  State<Devices> createState() => _DevicesState();
}

class _DevicesState extends State<Devices> {
  final api = ApiService(baseUrl: "http://192.168.1.224:4000");

  bool palangOn = false;
  bool cameraOn = false;

  Timer? _timer;
  bool isLoading = true;
  String? errorMsg;

  // 🛡️ Prevent multiple simultaneous requests
  bool _isPalangUpdating = false;
  bool _isCameraUpdating = false;

  @override
  void initState() {
    super.initState();
    fetchData();

    _timer = Timer.periodic(const Duration(seconds: 2), (_) => fetchData());
  }

  Future<void> fetchData() async {
    try {
      final palangData = await api.fetchPalang();
      final cameraData = await api.fetchCamera();

      if (!mounted) return;

      setState(() {
        // Hanya update jika tidak sedang melakukan manual update
        if (!_isPalangUpdating) {
          palangOn = palangData.isNotEmpty 
              ? palangData[0].status == "Terbuka" 
              : false;
        }

        if (!_isCameraUpdating) {
          cameraOn = cameraData.isNotEmpty 
              ? cameraData[0].status == "Aktif" 
              : false;
        }

        isLoading = false;
        errorMsg = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMsg = "Gagal memuat data: $e";
        isLoading = false;
      });
    }
  }

  Future<void> updatePalang(bool value) async {
    // Prevent multiple calls
    if (_isPalangUpdating) {
      print("⚠️ Palang update already in progress");
      return;
    }

    _isPalangUpdating = true;

    // Update UI immediately for responsiveness
    setState(() => palangOn = value);

    try {
      await api.postData(
        "/palang/update",
        {"status": value ? "Terbuka" : "Tertutup"}
      );
      print("✅ Palang updated: ${value ? 'Terbuka' : 'Tertutup'}");
    } catch (e) {
      print("❌ Error Palang: $e");
      // Revert state if failed
      if (mounted) {
        setState(() => palangOn = !value);
      }
    } finally {
      // Release lock after 1 second
      await Future.delayed(const Duration(milliseconds: 1000));
      _isPalangUpdating = false;
    }
  }

  Future<void> updateCamera(bool value) async {
    // Prevent multiple calls
    if (_isCameraUpdating) {
      print("⚠️ Camera update already in progress");
      return;
    }

    _isCameraUpdating = true;

    // Update UI immediately for responsiveness
    setState(() => cameraOn = value);

    try {
      await api.postData(
        "/camera/update",
        {"status": value ? "Aktif" : "Non Aktif"}
      );
      print("✅ Camera updated: ${value ? 'Aktif' : 'Non Aktif'}");
    } catch (e) {
      print("❌ Error Camera: $e");
      // Revert state if failed
      if (mounted) {
        setState(() => cameraOn = !value);
      }
    } finally {
      // Release lock after 1 second
      await Future.delayed(const Duration(milliseconds: 1000));
      _isCameraUpdating = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMsg != null) {
      return Center(
        child: Text(
          errorMsg!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        // HEADER
        Container(
          height: 110,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEB2525), Color(0xFF991b1b)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Container(
            margin: const EdgeInsets.only(top: 50, bottom: 20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Devices",
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
          ),
        ),

        const SizedBox(height: 5),

        Expanded(
          child: ListView(
            children: [
              deviceCard(
                title: "Palang",
                icon: Icons.no_crash_outlined,
                isOn: palangOn,
                onToggle: updatePalang,
                isUpdating: _isPalangUpdating,
              ),
              deviceCard(
                title: "Camera",
                icon: Icons.videocam_rounded,
                isOn: cameraOn,
                onToggle: updateCamera,
                isUpdating: _isCameraUpdating,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget deviceCard({
    required String title,
    required IconData icon,
    required bool isOn,
    required Function(bool) onToggle,
    bool isUpdating = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(14),
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
          Icon(icon, color: Colors.red, size: 44),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isUpdating)
                  const Text(
                    "Updating...",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: isOn,
            activeColor: Colors.white,
            activeTrackColor: Colors.red,
            onChanged: isUpdating ? null : onToggle, // Disable saat updating
          ),
        ],
      ),
    );
  }
}