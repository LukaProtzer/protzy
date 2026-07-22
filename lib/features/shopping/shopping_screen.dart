import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/shopping_categories.dart';
import 'shopping_item.dart';
import 'shopping_service.dart';
import 'widgets/frequent_items.dart';
import 'widgets/section_title.dart';
import 'widgets/shopping_tile.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final ShoppingService _service = ShoppingService();
  final TextEditingController _searchController = TextEditingController();

  List<ShoppingItem> items = [];
  String search = "";

  @override
  void initState() {
    super.initState();
    _loadItems();
    _searchController.addListener(() {
      setState(() => search = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    items = await _service.loadItems();
    if (mounted) setState(() {});
  }

  Future<void> _saveItems() async => _service.saveItems(items);

  String _generateId() {
    final random = Random();
    return '${DateTime.now().millisecondsSinceEpoch}${random.nextInt(999999)}';
  }

  void _sortItems() {
    items.sort((a, b) {
      if (a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  void _showAddDialog([String initial = ""]) {
    final controller = TextEditingController(text: initial);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Artikel hinzufügen"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "z.B. Milch",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Abbrechen"),
          ),
          FilledButton(
            onPressed: () => _addItem(controller.text),
            child: const Text("Speichern"),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;

    setState(() {
      items.add(
        ShoppingItem(
          id: _generateId(),
          name: value,
        ),
      );
      _sortItems();
    });

    await _saveItems();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleFavorite(int index) async {
    setState(() {
      items[index].favorite = !items[index].favorite;
      _sortItems();
    });
    await _saveItems();
  }

  Future<void> _toggleItem(int index, bool value) async {
    setState(() {
      items[index].done = value;
      if (value) {
        items[index].purchaseCount++;
        items[index].lastPurchased = DateTime.now();
      }
    });
    await _saveItems();
  }

  Future<void> _deleteItem(int index) async {
    setState(() => items.removeAt(index));
    await _saveItems();
  }

  @override
  Widget build(BuildContext context) {
    _sortItems();

    final filtered = items
        .where((e) => e.name.toLowerCase().contains(search))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Einkaufsliste")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text("Artikel"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: "Artikel suchen...",
            ),
          ),
          const SectionTitle(title: "⭐ Häufig gekauft"),
          FrequentItems(
            items: items,
            onTap: (name) => _showAddDialog(name),
          ),
          const SectionTitle(title: "🗂 Kategorien"),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ShoppingCategories.categories
                .map((e) => Chip(label: Text(e)))
                .toList(),
          ),
          const SectionTitle(title: "🛒 Einkaufsliste"),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text("Noch keine Artikel vorhanden.")),
            ),
          ...List.generate(filtered.length, (i) {
            final item = filtered[i];
            final original = items.indexOf(item);
            return ShoppingTile(
              item: item,
              onChanged: (v) => _toggleItem(original, v ?? false),
              onDelete: () => _deleteItem(original),
              onFavorite: () => _toggleFavorite(original),
            );
          }),
        ],
      ),
    );
  }
}

