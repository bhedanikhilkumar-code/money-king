class BudgetModel {
  BudgetModel({
    required this.categoryId,
    required this.limit,
    required this.month,
  });

  final String categoryId;
  final double limit;
  final String month;

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'limit': limit,
        'month': month,
      };

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      categoryId: map['categoryId'] as String,
      limit: (map['limit'] as num).toDouble(),
      month: map['month'] as String,
    );
  }
}
