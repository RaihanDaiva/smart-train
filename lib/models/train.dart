class Train {
  final int id;
  final int speed;
  Train({required this.id, required this.speed});

  factory Train.fromJson(Map<String, dynamic> j) => Train(
        id: j['id'] is int
            ? j['id'] as int
            : int.tryParse(j['id']?.toString() ?? '') ?? 0,
        speed:j['speed'] is int
            ? j['speed'] as int
            : int.tryParse(j['speed']?.toString() ?? '') ?? 0
      );
}