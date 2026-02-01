import 'dart:io';

void main() async {
  print('Mendeteksi IP Address laptop...');

  String? ipAddress;
  String? interfaceName;

  try {
    // Mendapatkan semua network interfaces
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );

    // List untuk menyimpan kandidat IP
    List<Map<String, String>> candidates = [];

    // Prioritas: WiFi (192.168.x.x) > Ethernet > lainnya
    for (var interface in interfaces) {
      final name = interface.name.toLowerCase();

      // Skip loopback dan virtual interfaces
      if (name.contains('lo') ||
          name.contains('vmware') ||
          name.contains('virtualbox') ||
          name.contains('docker') ||
          name.contains('vethernet')) {
        continue;
      }

      for (var addr in interface.addresses) {
        final ip = addr.address;

        // Hanya ambil IP private
        if (ip.startsWith('192.168.') ||
            ip.startsWith('10.') ||
            ip.startsWith('172.')) {
          candidates.add({'ip': ip, 'name': interface.name, 'type': name});

          print('Ditemukan: $ip pada ${interface.name}');
        }
      }
    }

    if (candidates.isEmpty) {
      print('Tidak dapat menemukan IP address');
      print('Pastikan laptop terhubung ke WiFi/Ethernet');
      exit(1);
    }

    // Prioritas 1: WiFi adapter dengan IP 192.168.x.x
    for (var candidate in candidates) {
      if (candidate['type']!.contains('wi-fi') ||
          candidate['type']!.contains('wlan') ||
          candidate['type']!.contains('wireless')) {
        if (candidate['ip']!.startsWith('192.168.')) {
          ipAddress = candidate['ip'];
          interfaceName = candidate['name'];
          print('IP WiFi terdeteksi: $ipAddress ($interfaceName)');
          break;
        }
      }
    }

    // Prioritas 2: Ethernet dengan IP 192.168.x.x
    if (ipAddress == null) {
      for (var candidate in candidates) {
        if (candidate['type']!.contains('ethernet') ||
            candidate['type']!.contains('eth')) {
          if (candidate['ip']!.startsWith('192.168.')) {
            ipAddress = candidate['ip'];
            interfaceName = candidate['name'];
            print('IP Ethernet terdeteksi: $ipAddress ($interfaceName)');
            break;
          }
        }
      }
    }

    // Prioritas 3: Ambil 192.168.x.x manapun
    if (ipAddress == null) {
      for (var candidate in candidates) {
        if (candidate['ip']!.startsWith('192.168.')) {
          ipAddress = candidate['ip'];
          interfaceName = candidate['name'];
          print('IP terdeteksi: $ipAddress ($interfaceName)');
          break;
        }
      }
    }

    // Prioritas 4: Ambil IP private lainnya (10.x atau 172.x)
    if (ipAddress == null) {
      ipAddress = candidates.first['ip'];
      interfaceName = candidates.first['name'];
      print('IP terdeteksi: $ipAddress ($interfaceName)');
    }

    // Buat/Update file .env
    final envFile = File('.env');
    final baseUrl = 'http://$ipAddress:4000';

    await envFile.writeAsString('API_BASE_URL=$baseUrl\n');

    print('File .env berhasil dibuat');
    print('API_BASE_URL=$baseUrl');
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}
