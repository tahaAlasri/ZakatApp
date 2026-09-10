class FavoriteItem {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'calculator', 'record', 'article'
  final String route;
  final String imagePath;
  final DateTime createdAt;

  FavoriteItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.route,
    required this.imagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'type': type,
      'route': route,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FavoriteItem.fromMap(Map<dynamic, dynamic> map) {
    return FavoriteItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      route: map['route']?.toString() ?? '',
      imagePath: map['imagePath']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
