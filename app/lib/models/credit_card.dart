class CreditCard {
  final String id;
  final String name;
  final String last4;
  final double? creditLimit;
  final int statementDay;
  final int graceDays;

  const CreditCard({
    required this.id,
    required this.name,
    required this.last4,
    required this.creditLimit,
    required this.statementDay,
    required this.graceDays,
  });

  factory CreditCard.fromMap(Map<String, dynamic> map) => CreditCard(
        id: map['id'] as String,
        name: map['name'] as String,
        last4: (map['last4'] as String?) ?? '',
        creditLimit: (map['credit_limit'] as num?)?.toDouble(),
        statementDay: map['statement_day'] as int,
        graceDays: (map['grace_days'] as int?) ?? 18,
      );
}
