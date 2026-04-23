class AccountModel {
  AccountModel({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;
  final String icon;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
      };

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: (map['icon'] as String?) ?? '💳',
    );
  }
}
