import 'package:flutter/material.dart';
import '../pages/home.dart'; // pastikan path ini sesuai dengan file enum TimeFilter Anda

class SpeedFilterButton extends StatelessWidget {
  final TimeFilter selectedFilter;
  final ValueChanged<TimeFilter> onChanged;

  const SpeedFilterButton({
    super.key,
    required this.selectedFilter,
    required this.onChanged,
  });

  String _label(TimeFilter filter) {
    switch (filter) {
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

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TimeFilter>(
      tooltip: "Filter waktu",
      // HAPUS bagian 'icon: ...'
      // GANTI dengan 'child: ...' untuk membuat tampilan kotak kustom
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade400), // Garis pinggir kotak
          borderRadius: BorderRadius.circular(8), // Sudut melengkung
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Agar lebar menyesuaikan konten
          children: [
            // Menampilkan teks filter saat ini (misal: 5m)
            Text(
              _label(selectedFilter),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            // Icon dropdown di sampingnya
            const Icon(Icons.arrow_drop_down, color: Colors.black54),
          ],
        ),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => TimeFilter.values
          .map(
            (f) => PopupMenuItem(
              value: f,
              child: Row(
                children: [
                  // Menandai mana yang sedang dipilih di dalam list menu
                  if (f == selectedFilter)
                    const Icon(Icons.check, size: 16, color: Colors.red)
                  else
                    const SizedBox(width: 16), // Placeholder biar rapi
                  const SizedBox(width: 8),
                  Text(_label(f)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}