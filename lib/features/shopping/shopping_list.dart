import 'shopping_item.dart';

class ShoppingList {
  ShoppingList({
    required this.id,
    required this.name,
    List<ShoppingItem>? items,
    DateTime? createdAt,
  })  : items = items ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  List<ShoppingItem> items;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return ShoppingList(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unbenannte Liste',
      items: rawItems is List
          ? rawItems
          .whereType<Map>()
          .map(
            (item) => ShoppingItem.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList()
          : [],
      createdAt:
      DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}