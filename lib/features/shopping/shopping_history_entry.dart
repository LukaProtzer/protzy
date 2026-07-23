import 'shopping_item.dart';

class ShoppingHistoryEntry {
  ShoppingHistoryEntry({
    required this.id,
    required this.completedAt,
    required List<ShoppingHistoryItem> items,
    List<String>? sourceListIds,
    List<String>? sourceListNames,
    this.totalAmount,
    this.storeName,
    this.note = '',
  })  : items = List<ShoppingHistoryItem>.unmodifiable(items),
        sourceListIds = List<String>.unmodifiable(
          sourceListIds ?? const [],
        ),
        sourceListNames = List<String>.unmodifiable(
          sourceListNames ?? const [],
        );

  final String id;
  final DateTime completedAt;
  final List<ShoppingHistoryItem> items;
  final List<String> sourceListIds;
  final List<String> sourceListNames;
  final double? totalAmount;
  final String? storeName;
  final String note;

  int get itemCount => items.length;

  double get totalQuantity {
    return items.fold<double>(
      0,
          (sum, item) => sum + item.quantity,
    );
  }

  bool get hasTotalAmount => totalAmount != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'completedAt': completedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'sourceListIds': sourceListIds,
      'sourceListNames': sourceListNames,
      'totalAmount': totalAmount,
      'storeName': storeName,
      'note': note,
    };
  }

  factory ShoppingHistoryEntry.fromJson(
      Map<String, dynamic> json,
      ) {
    final decodedItems = json['items'];
    final decodedSourceListIds = json['sourceListIds'];
    final decodedSourceListNames = json['sourceListNames'];
    final rawTotalAmount = json['totalAmount'];

    return ShoppingHistoryEntry(
      id: json['id']?.toString() ?? '',
      completedAt: DateTime.tryParse(
        json['completedAt']?.toString() ?? '',
      ) ??
          DateTime.now(),
      items: decodedItems is List
          ? decodedItems
          .whereType<Map>()
          .map(
            (item) => ShoppingHistoryItem.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList()
          : const [],
      sourceListIds: decodedSourceListIds is List
          ? decodedSourceListIds
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList()
          : const [],
      sourceListNames: decodedSourceListNames is List
          ? decodedSourceListNames
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList()
          : const [],
      totalAmount: rawTotalAmount is num
          ? rawTotalAmount.toDouble()
          : double.tryParse(
        rawTotalAmount?.toString() ?? '',
      ),
      storeName:
      json['storeName']?.toString().trim().isNotEmpty == true
          ? json['storeName'].toString().trim()
          : null,
      note: json['note']?.toString() ?? '',
    );
  }

  ShoppingHistoryEntry copyWith({
    String? id,
    DateTime? completedAt,
    List<ShoppingHistoryItem>? items,
    List<String>? sourceListIds,
    List<String>? sourceListNames,
    double? totalAmount,
    bool clearTotalAmount = false,
    String? storeName,
    bool clearStoreName = false,
    String? note,
  }) {
    return ShoppingHistoryEntry(
      id: id ?? this.id,
      completedAt: completedAt ?? this.completedAt,
      items: items ?? this.items,
      sourceListIds: sourceListIds ?? this.sourceListIds,
      sourceListNames: sourceListNames ?? this.sourceListNames,
      totalAmount:
      clearTotalAmount ? null : totalAmount ?? this.totalAmount,
      storeName:
      clearStoreName ? null : storeName ?? this.storeName,
      note: note ?? this.note,
    );
  }
}

class ShoppingHistoryItem {
  const ShoppingHistoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.sourceListId,
    required this.sourceListName,
    this.note = '',
    this.favorite = false,
    this.purchaseCount = 0,
    this.purchasedAt,
    this.unitPrice,
    this.totalPrice,
    this.storeName,
  });

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final String note;
  final bool favorite;
  final int purchaseCount;
  final String sourceListId;
  final String sourceListName;
  final DateTime? purchasedAt;
  final double? unitPrice;
  final double? totalPrice;
  final String? storeName;

  factory ShoppingHistoryItem.fromShoppingItem({
    required ShoppingItem item,
    required String sourceListId,
    required String sourceListName,
    DateTime? purchasedAt,
    double? unitPrice,
    double? totalPrice,
    String? storeName,
  }) {
    return ShoppingHistoryItem(
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      category: item.category,
      note: item.note,
      favorite: item.favorite,
      purchaseCount: item.purchaseCount,
      sourceListId: sourceListId,
      sourceListName: sourceListName,
      purchasedAt:
      purchasedAt ?? item.lastPurchased ?? DateTime.now(),
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      storeName: storeName,
    );
  }

  ShoppingItem toShoppingItem({
    required String newId,
    bool favorite = false,
  }) {
    return ShoppingItem(
      id: newId,
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
      note: note,
      favorite: favorite,
      done: false,
      purchaseCount: purchaseCount,
      createdAt: DateTime.now(),
      lastPurchased: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'note': note,
      'favorite': favorite,
      'purchaseCount': purchaseCount,
      'sourceListId': sourceListId,
      'sourceListName': sourceListName,
      'purchasedAt': purchasedAt?.toIso8601String(),
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'storeName': storeName,
    };
  }

  factory ShoppingHistoryItem.fromJson(
      Map<String, dynamic> json,
      ) {
    final rawQuantity = json['quantity'];
    final rawPurchaseCount = json['purchaseCount'];
    final rawUnitPrice = json['unitPrice'];
    final rawTotalPrice = json['totalPrice'];

    return ShoppingHistoryItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: rawQuantity is num
          ? rawQuantity.toDouble()
          : double.tryParse(
        rawQuantity?.toString() ?? '',
      ) ??
          1,
      unit: json['unit']?.toString().trim().isNotEmpty == true
          ? json['unit'].toString()
          : 'Stk.',
      category:
      json['category']?.toString().trim().isNotEmpty == true
          ? json['category'].toString()
          : 'Sonstiges',
      note: json['note']?.toString() ?? '',
      favorite: json['favorite'] == true,
      purchaseCount: rawPurchaseCount is num
          ? rawPurchaseCount.toInt()
          : int.tryParse(
        rawPurchaseCount?.toString() ?? '',
      ) ??
          0,
      sourceListId:
      json['sourceListId']?.toString() ?? '',
      sourceListName:
      json['sourceListName']?.toString() ?? '',
      purchasedAt: DateTime.tryParse(
        json['purchasedAt']?.toString() ?? '',
      ),
      unitPrice: rawUnitPrice is num
          ? rawUnitPrice.toDouble()
          : double.tryParse(
        rawUnitPrice?.toString() ?? '',
      ),
      totalPrice: rawTotalPrice is num
          ? rawTotalPrice.toDouble()
          : double.tryParse(
        rawTotalPrice?.toString() ?? '',
      ),
      storeName:
      json['storeName']?.toString().trim().isNotEmpty == true
          ? json['storeName'].toString().trim()
          : null,
    );
  }

  ShoppingHistoryItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    String? note,
    bool? favorite,
    int? purchaseCount,
    String? sourceListId,
    String? sourceListName,
    DateTime? purchasedAt,
    bool clearPurchasedAt = false,
    double? unitPrice,
    bool clearUnitPrice = false,
    double? totalPrice,
    bool clearTotalPrice = false,
    String? storeName,
    bool clearStoreName = false,
  }) {
    return ShoppingHistoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      note: note ?? this.note,
      favorite: favorite ?? this.favorite,
      purchaseCount: purchaseCount ?? this.purchaseCount,
      sourceListId: sourceListId ?? this.sourceListId,
      sourceListName: sourceListName ?? this.sourceListName,
      purchasedAt:
      clearPurchasedAt ? null : purchasedAt ?? this.purchasedAt,
      unitPrice:
      clearUnitPrice ? null : unitPrice ?? this.unitPrice,
      totalPrice:
      clearTotalPrice ? null : totalPrice ?? this.totalPrice,
      storeName:
      clearStoreName ? null : storeName ?? this.storeName,
    );
  }
}
