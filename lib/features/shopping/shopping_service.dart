import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'shopping_item.dart';
import 'shopping_list.dart';

class ShoppingService {
  static const String storageKey = 'shopping_items';
  static const String listsStorageKey = 'shopping_lists';
  static const String defaultListId = 'default-shopping-list';

  Future<List<ShoppingList>> loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLists = prefs.getString(listsStorageKey);

    if (storedLists != null && storedLists.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedLists);

        if (decoded is List) {
          final lists = decoded
              .whereType<Map>()
              .map(
                (list) => ShoppingList.fromJson(
              Map<String, dynamic>.from(list),
            ),
          )
              .where((list) => list.id.isNotEmpty)
              .toList();

          if (lists.isNotEmpty) {
            return lists;
          }
        }
      } catch (_) {
        // Fällt auf die bisherige Einkaufsliste zurück.
      }
    }

    final legacyItems = await _loadLegacyItems(prefs);

    final migratedLists = [
      ShoppingList(
        id: defaultListId,
        name: 'Meine Einkaufsliste',
        items: legacyItems,
      ),
    ];

    await saveLists(migratedLists);

    return migratedLists;
  }

  Future<List<ShoppingItem>> _loadLegacyItems(
      SharedPreferences prefs,
      ) async {
    final storedItems = prefs.getString(storageKey);

    if (storedItems == null || storedItems.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(storedItems);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => ShoppingItem.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLists(List<ShoppingList> lists) async {
    final prefs = await SharedPreferences.getInstance();

    final storedLists = jsonEncode(
      lists.map((list) => list.toJson()).toList(),
    );

    await prefs.setString(listsStorageKey, storedLists);
  }

  Future<List<ShoppingItem>> loadItems() async {
    final lists = await loadLists();

    if (lists.isEmpty) {
      return [];
    }

    return List<ShoppingItem>.from(lists.first.items);
  }

  Future<void> saveItems(List<ShoppingItem> items) async {
    final lists = await loadLists();

    if (lists.isEmpty) {
      lists.add(
        ShoppingList(
          id: defaultListId,
          name: 'Meine Einkaufsliste',
          items: List<ShoppingItem>.from(items),
        ),
      );
    } else {
      lists.first.items = List<ShoppingItem>.from(items);
    }

    await saveLists(lists);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(storageKey);
    await prefs.remove(listsStorageKey);
  }
}