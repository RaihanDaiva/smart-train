class Camera {
  final String id;
  final String status;
  Camera({required this.id, required this.status});

  factory Camera.fromJson(Map<String, dynamic> j) => Camera(
        id: j['id'].toString(),
        status: j['status']?.toString() ?? '',
      );
}