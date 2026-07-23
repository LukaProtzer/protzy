import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'shopping_history_entry.dart';
import 'shopping_item.dart';
import 'shopping_list.dart';

class ShoppingService {
  static const String storageKey = 'shopping_items';
  static const String listsStorageKey = 'shopping_lists';
  static const String historyStorageKey = 'shopping_history';
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

    await prefs.setString(
      listsStorageKey,
      storedLists,
    );
  }

  Future<List<ShoppingItem>> loadItems() async {
    final lists = await loadLists();

    if (lists.isEmpty) {
      return [];
    }

    return List<ShoppingItem>.from(
      lists.first.items,
    );
  }

  Future<void> saveItems(
      List<ShoppingItem> items,
      ) async {
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
      lists.first.items =
      List<ShoppingItem>.from(items);
    }

    await saveLists(lists);
  }

  Future<List<ShoppingHistoryEntry>>
  loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHistory =
    prefs.getString(historyStorageKey);

    if (storedHistory == null ||
        storedHistory.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(storedHistory);

      if (decoded is! List) {
        return [];
      }

      final entries = decoded
          .whereType<Map>()
          .map(
            (entry) =>
            ShoppingHistoryEntry.fromJson(
              Map<String, dynamic>.from(entry),
            ),
      )
          .where(
            (entry) =>
        entry.id.isNotEmpty &&
            entry.items.isNotEmpty,
      )
          .toList();

      entries.sort(
            (a, b) => b.completedAt.compareTo(
          a.completedAt,
        ),
      );

      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(
      List<ShoppingHistoryEntry> history,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    final sortedHistory =
    List<ShoppingHistoryEntry>.from(history)
      ..sort(
            (a, b) => b.completedAt.compareTo(
          a.completedAt,
        ),
      );

    final storedHistory = jsonEncode(
      sortedHistory
          .map((entry) => entry.toJson())
          .toList(),
    );

    await prefs.setString(
      historyStorageKey,
      storedHistory,
    );
  }

  Future<void> addHistoryEntry(
      ShoppingHistoryEntry entry,
      ) async {
    final history = await loadHistory();

    history.removeWhere(
          (existingEntry) =>
      existingEntry.id == entry.id,
    );

    history.insert(0, entry);

    await saveHistory(history);
  }

  Future<void> deleteHistoryEntry(
      String entryId,
      ) async {
    final history = await loadHistory();

    history.removeWhere(
          (entry) => entry.id == entryId,
    );

    await saveHistory(history);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(historyStorageKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(storageKey);
    await prefs.remove(listsStorageKey);
    await prefs.remove(historyStorageKey);
  }
}
