class Train {
  final int id;
  final double speed;

  Train({required this.id, required this.speed});

  factory Train.fromJson(Map<String, dynamic> j) {
    final rawSpeed = j['speed'];

    double parsedSpeed;

    if (rawSpeed is int) {
      parsedSpeed = rawSpeed.toDouble(); // KONVERSI int → double
    } else if (rawSpeed is double) {
      parsedSpeed = rawSpeed; // sudah double
    } else {
      parsedSpeed = double.tryParse(rawSpeed.toString()) ?? 0.0;
    }

    return Train(
      id: j['id'] is int
          ? j['id']
          : int.tryParse(j['id']?.toString() ?? '') ?? 0,

      speed: parsedSpeed,
    );
  }
}
