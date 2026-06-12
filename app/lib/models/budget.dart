class Budget {
  final String id;

  /// `null` means the overall monthly budget.
  final String? categoryId;
  final DateTime month;
  final double amount;

  const Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.amount,
  });

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        id: map['id'] as String,
        categoryId: map['category_id'] as String?,
        month: DateTime.parse(map['month'] as String),
        amount: (map['amount'] as num).toDouble(),
      );
}
