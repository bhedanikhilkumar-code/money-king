enum TransactionType { income, expense, transfer }

class TransactionEntry {
  TransactionEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.transferAccountId,
    required this.note,
    required this.date,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String categoryId;
  final String accountId;
  final String? transferAccountId;
  final String note;
  final DateTime date;

  bool get isTransfer => type == TransactionType.transfer;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'accountId': accountId,
        'transferAccountId': transferAccountId,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory TransactionEntry.fromMap(Map<String, dynamic> map) {
    return TransactionEntry(
      id: map['id'] as String,
      type: TransactionType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      amount: (map['amount'] as num).toDouble(),
      categoryId: (map['categoryId'] as String?) ?? 'transfer',
      accountId: map['accountId'] as String,
      transferAccountId: map['transferAccountId'] as String?,
      note: (map['note'] as String?) ?? '',
      date: DateTime.parse(map['date'] as String),
    );
  }
}
