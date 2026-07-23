class ShoppingItem {
  ShoppingItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unit = 'Stk.',
    this.category = 'Sonstiges',
    this.favorite = false,
    this.done = false,
    this.purchaseCount = 0,
    this.note = '',
    DateTime? createdAt,
    this.lastPurchased,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;

  String name;
  double quantity;
  String unit;
  String category;
  String note;

  bool favorite;
  bool done;
  int purchaseCount;

  final DateTime createdAt;
  DateTime? lastPurchased;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'favorite': favorite,
      'done': done,
      'purchaseCount': purchaseCount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'lastPurchased': lastPurchased?.toIso8601String(),
    };
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final quantity = json['quantity'];

    return ShoppingItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: quantity is num
          ? quantity.toDouble()
          : double.tryParse(quantity?.toString() ?? '') ?? 1,
      unit: json['unit']?.toString() ?? 'Stk.',
      category: json['category']?.toString().trim().isNotEmpty == true
          ? json['category'].toString()
          : 'Sonstiges',
      favorite: json['favorite'] == true,
      done: json['done'] == true,
      purchaseCount: json['purchaseCount'] is num
          ? (json['purchaseCount'] as num).toInt()
          : int.tryParse(json['purchaseCount']?.toString() ?? '') ?? 0,
      note: json['note']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      lastPurchased:
      DateTime.tryParse(json['lastPurchased']?.toString() ?? ''),
    );
  }
}