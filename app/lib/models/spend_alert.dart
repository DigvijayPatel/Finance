class SpendAlert {
  final String id;
  final String? categoryId;
  final DateTime month;
  final String type; // 'warning' | 'exceeded'
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const SpendAlert({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  bool get isExceeded => type == 'exceeded';

  factory SpendAlert.fromMap(Map<String, dynamic> map) => SpendAlert(
        id: map['id'] as String,
        categoryId: map['category_id'] as String?,
        month: DateTime.parse(map['month'] as String),
        type: map['type'] as String,
        message: (map['message'] as String?) ?? '',
        isRead: (map['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}
