class Expense {
  final String id;
  final String? categoryId;
  final String? cardId;
  final double amount;
  final String note;
  final String paymentMethod;
  final DateTime spentAt;

  const Expense({
    required this.id,
    required this.categoryId,
    required this.cardId,
    required this.amount,
    required this.note,
    required this.paymentMethod,
    required this.spentAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as String,
        categoryId: map['category_id'] as String?,
        cardId: map['card_id'] as String?,
        amount: (map['amount'] as num).toDouble(),
        note: (map['note'] as String?) ?? '',
        paymentMethod: (map['payment_method'] as String?) ?? 'other',
        spentAt: DateTime.parse(map['spent_at'] as String),
      );
}

const paymentMethods = ['upi', 'card', 'cash', 'netbanking', 'other'];

String paymentMethodLabel(String method) => switch (method) {
      'upi' => 'UPI',
      'card' => 'Card',
      'cash' => 'Cash',
      'netbanking' => 'Net banking',
      _ => 'Other',
    };
