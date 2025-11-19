class Palang {
  final String id;
  final String status;
  Palang({required this.id, required this.status});

  factory Palang.fromJson(Map<String, dynamic> j) => Palang(
        id: j['id'].toString(),
        status: j['status']?.toString() ?? '',
      );
}