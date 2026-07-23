import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/shopping_categories.dart';
import 'shopping_item.dart';
import 'shopping_list.dart';
import 'shopping_service.dart';

class ShoppingListModeScreen extends StatefulWidget {
  const ShoppingListModeScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  final String listId;
  final String listName;

  @override
  State<ShoppingListModeScreen> createState() =>
      _ShoppingListModeScreenState();
}

class _ShoppingListModeScreenState extends State<ShoppingListModeScreen> {
  final ShoppingService _service = ShoppingService();

  List<ShoppingItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final lists = await _service.loadLists();

    final selectedList = lists.where(
          (list) => list.id == widget.listId,
    );

    if (!mounted) return;

    setState(() {
      _items = selectedList.isEmpty
          ? []
          : List<ShoppingItem>.from(selectedList.first.items);
      _sortItems();
      _isLoading = false;
    });
  }

  Future<void> _saveItems() async {
    final lists = await _service.loadLists();

    final index = lists.indexWhere(
          (list) => list.id == widget.listId,
    );

    if (index == -1) return;

    lists[index].items = List<ShoppingItem>.from(_items);
    await _service.saveLists(lists);
  }

  String _generateId() {
    final random = math.Random();

    return '${DateTime.now().millisecondsSinceEpoch}'
        '${random.nextInt(999999)}';
  }

  List<String> get _categories {
    final categories = <String>[
      ...ShoppingCategories.categories,
      ..._items.map((item) => item.category),
      'Sonstiges',
    ];

    return {
      for (final category in categories)
        if (category.trim().isNotEmpty) category.trim(),
    }.toList();
  }

  int _categoryIndex(String category) {
    final index = _categories.indexOf(category);

    return index == -1 ? _categories.length : index;
  }

  void _sortItems() {
    _items.sort((a, b) {
      final categoryComparison =
      _categoryIndex(a.category).compareTo(_categoryIndex(b.category));

      if (categoryComparison != 0) {
        return categoryComparison;
      }

      if (a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toString().replaceAll('.', ',');
  }

  Future<void> _toggleItem(ShoppingItem item, bool value) async {
    final wasDone = item.done;

    setState(() {
      item.done = value;

      if (value && !wasDone) {
        item.purchaseCount++;
        item.lastPurchased = DateTime.now();
      }
    });

    await _saveItems();

    if (!mounted || !value || wasDone) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} liegt jetzt im Einkaufswagen'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () {
            _toggleItem(item, false);
          },
        ),
      ),
    );
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Artikel löschen?'),
          content: Text('${item.name} wird aus der Liste entfernt.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      _items.remove(item);
    });

    await _saveItems();
  }

  void _showItemSheet([ShoppingItem? item]) {
    var name = item?.name ?? '';
    var quantity = _formatQuantity(item?.quantity ?? 1);
    var unit = item?.unit ?? 'Stk.';
    var category = item?.category ?? 'Sonstiges';
    var note = item?.note ?? '';

    final isNewItem = item == null;

    const units = [
      'Stk.',
      'g',
      'kg',
      'ml',
      'l',
      'Packung',
      'Dose',
      'Flasche',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outline,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isNewItem
                                    ? 'Artikel hinzufügen'
                                    : 'Artikel bearbeiten',
                                style:
                                Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                              },
                              icon: const Icon(Icons.close),
                              tooltip: 'Schließen',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: ValueKey(
                            isNewItem ? 'new-item-name' : 'edit-item-name',
                          ),
                          initialValue: name,
                          autofocus: isNewItem,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Artikel',
                            hintText: 'z. B. Milch',
                          ),
                          onChanged: (value) {
                            name = value;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: ValueKey(
                                  isNewItem
                                      ? 'new-item-quantity'
                                      : 'edit-item-quantity',
                                ),
                                initialValue: quantity,
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Menge',
                                ),
                                onChanged: (value) {
                                  quantity = value;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: unit,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Einheit',
                                ),
                                items: units.map((value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;

                                  setSheetState(() {
                                    unit = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kategorie',
                          ),
                          items: _categories.map((value) {
                            return DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            setSheetState(() {
                              category = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: ValueKey(
                            isNewItem ? 'new-item-note' : 'edit-item-note',
                          ),
                          initialValue: note,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notiz',
                            hintText: 'z. B. laktosefrei',
                          ),
                          onChanged: (value) {
                            note = value;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              final cleanedName = name.trim();
                              final parsedQuantity = double.tryParse(
                                quantity.trim().replaceAll(',', '.'),
                              );

                              if (cleanedName.isEmpty ||
                                  parsedQuantity == null ||
                                  parsedQuantity <= 0) {
                                return;
                              }

                              setState(() {
                                if (isNewItem) {
                                  _items.add(
                                    ShoppingItem(
                                      id: _generateId(),
                                      name: cleanedName,
                                      quantity: parsedQuantity,
                                      unit: unit,
                                      category: category,
                                      note: note.trim(),
                                    ),
                                  );
                                } else {
                                  item.name = cleanedName;
                                  item.quantity = parsedQuantity;
                                  item.unit = unit;
                                  item.category = category;
                                  item.note = note.trim();
                                }

                                _sortItems();
                              });

                              await _saveItems();

                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                            child: const Text('Speichern'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildGroupedItems(List<ShoppingItem> shoppingItems) {
    final groupedItems = <String, List<ShoppingItem>>{};

    for (final item in shoppingItems) {
      groupedItems.putIfAbsent(item.category, () => []);
      groupedItems[item.category]!.add(item);
    }

    final categories = groupedItems.keys.toList()
      ..sort((a, b) => _categoryIndex(a).compareTo(_categoryIndex(b)));

    return categories.expand((category) {
      final categoryItems = groupedItems[category]!;

      return [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(
            category,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...categoryItems.map((item) {
          final textStyle = TextStyle(
            fontWeight: FontWeight.w600,
            decoration:
            item.done ? TextDecoration.lineThrough : TextDecoration.none,
          );

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ListTile(
              onTap: () => _showItemSheet(item),
              leading: Checkbox(
                value: item.done,
                onChanged: (value) => _toggleItem(item, value ?? false),
              ),
              title: Text(
                item.name,
                style: textStyle,
              ),
              subtitle: Text(
                item.note.trim().isEmpty
                    ? '${_formatQuantity(item.quantity)} ${item.unit}'
                    : '${_formatQuantity(item.quantity)} ${item.unit}'
                    ' • ${item.note}',
                style: TextStyle(
                  decoration: item.done
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              trailing: PopupMenuButton<_ItemAction>(
                tooltip: 'Optionen',
                onSelected: (action) {
                  if (action == _ItemAction.edit) {
                    _showItemSheet(item);
                  } else {
                    _deleteItem(item);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ItemAction.edit,
                    child: Text('Bearbeiten'),
                  ),
                  PopupMenuItem(
                    value: _ItemAction.delete,
                    child: Text('Löschen'),
                  ),
                ],
              ),
            ),
          );
        }),
      ];
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final openItems = _items.where((item) => !item.done).toList();
    final basketItems = _items.where((item) => item.done).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Artikel'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadItems,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            Text(
              '${openItems.length} offene '
                  '${openItems.length == 1 ? 'Sache' : 'Sachen'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tippe auf einen Artikel zum Bearbeiten.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (openItems.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Alles auf der Liste erledigt! 🎉',
                        style: TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._buildGroupedItems(openItems),
            if (basketItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                child: ExpansionTile(
                  initiallyExpanded: true,
                  leading: const Icon(Icons.shopping_cart),
                  title: Text(
                    'Im Einkaufswagen (${basketItems.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Haken entfernen, um Artikel zurückzulegen',
                  ),
                  childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: _buildGroupedItems(basketItems),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ItemAction {
  edit,
  delete,
}