class ShoppingItem {
  ShoppingItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unit = "Stk.",
    this.category = "Sonstiges",
    this.favorite = false,
    this.done = false,
    this.purchaseCount = 0,
    this.note = "",
    DateTime? createdAt,
    this.lastPurchased,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;

  String name;
  double quantity; // <- vorher int
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
      "id": id,
      "name": name,
      "quantity": quantity,
      "unit": unit,
      "category": category,
      "favorite": favorite,
      "done": done,
      "purchaseCount": purchaseCount,
      "note": note,
      "createdAt": createdAt.toIso8601String(),
      "lastPurchased": lastPurchased?.toIso8601String(),
    };
  }

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json["id"] ?? "",
      name: json["name"] ?? "",
      quantity: (json["quantity"] ?? 1).toDouble(),
      unit: json["unit"] ?? "Stk.",
      category: json["category"] ?? "Sonstiges",
      favorite: json["favorite"] ?? false,
      done: json["done"] ?? false,
      purchaseCount: json["purchaseCount"] ?? 0,
      note: json["note"] ?? "",
      createdAt: json["createdAt"] != null
          ? DateTime.parse(json["createdAt"])
          : DateTime.now(),
      lastPurchased: json["lastPurchased"] != null
          ? DateTime.parse(json["lastPurchased"])
          : null,
    );
  }
}