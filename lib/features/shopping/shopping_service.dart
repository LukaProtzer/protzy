import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'shopping_item.dart';

class ShoppingService {
  static const String storageKey = "shopping_items";

  Future<List<ShoppingItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();

    final json = prefs.getString(storageKey);

    if (json == null) {
      return [];
    }

    final decoded = jsonDecode(json) as List;

    return decoded
        .map((e) => ShoppingItem.fromJson(e))
        .toList();
  }

  Future<void> saveItems(List<ShoppingItem> items) async {
    final prefs = await SharedPreferences.getInstance();

    final json = jsonEncode(
      items.map((e) => e.toJson()).toList(),
    );

    await prefs.setString(storageKey, json);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(storageKey);
  }
}