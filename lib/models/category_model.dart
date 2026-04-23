class CategoryModel {
  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.colorValue,
  });

  final String id;
  final String name;
  final String type;
  final String icon;
  final int colorValue;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'colorValue': colorValue,
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      icon: (map['icon'] as String?) ?? '💸',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF6C63FF,
    );
  }
}
