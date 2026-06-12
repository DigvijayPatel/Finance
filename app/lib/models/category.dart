import 'dart:ui';

class Category {
  final String id;
  final String name;
  final String colorHex;

  const Category({required this.id, required this.name, required this.colorHex});

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        name: map['name'] as String,
        colorHex: (map['color'] as String?) ?? '#6b7280',
      );

  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16) ?? 0x6b7280;
    return Color(0xff000000 | value);
  }
}
