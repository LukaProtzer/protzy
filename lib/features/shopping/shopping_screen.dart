import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/shopping_categories.dart';
import 'default_product_suggestions.dart';
import 'shopping_history_entry.dart';
import 'shopping_history_screen.dart';
import 'shopping_item.dart';
import 'shopping_list.dart';
import 'shopping_lists_screen.dart';
import 'shopping_service.dart';
import 'widgets/frequent_items.dart';
import 'widgets/section_title.dart';
import 'widgets/shopping_item_sheet.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({
    super.key,
    this.refreshToken = 0,
  });

  final int refreshToken;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final ShoppingService _service = ShoppingService();
  final TextEditingController _searchController = TextEditingController();

  List<ShoppingList> _lists = [];

  String? _selectedTargetListId;
  String _search = '';
  String? _selectedCategory;

  bool _isLoading = true;
  bool _isSaving = false;

  ShoppingList? get _selectedTargetList {
    final selectedId = _selectedTargetListId;

    if (selectedId == null) {
      return null;
    }

    for (final list in _lists) {
      if (list.id == selectedId) {
        return list;
      }
    }

    return null;
  }

  List<_ShoppingEntry> get _allEntries {
    return [
      for (final list in _lists)
        for (final item in list.items)
          _ShoppingEntry(
            list: list,
            item: item,
          ),
    ];
  }

  List<ShoppingItem> get _allItems {
    return [
      for (final list in _lists) ...list.items,
    ];
  }

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_handleSearchChanged);
    _loadLists();
  }

  @override
  void didUpdateWidget(covariant ShoppingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadLists(
        preferredTargetListId: _selectedTargetListId,
      );
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();

    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) return;

    setState(() {
      _search = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _loadLists({
    String? preferredTargetListId,
  }) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final loadedLists = await _service.loadLists();

    if (!mounted) return;

    String? nextTargetListId =
        preferredTargetListId ?? _selectedTargetListId;

    final targetStillExists = loadedLists.any(
          (list) => list.id == nextTargetListId,
    );

    if (!targetStillExists) {
      nextTargetListId =
      loadedLists.isEmpty ? null : loadedLists.first.id;
    }

    setState(() {
      _lists = loadedLists;
      _selectedTargetListId = nextTargetListId;
      _selectedCategory = null;
      _isLoading = false;
    });
  }

  void _selectTargetList(String? listId) {
    if (listId == null || listId == _selectedTargetListId) {
      return;
    }

    final exists = _lists.any(
          (list) => list.id == listId,
    );

    if (!exists) {
      return;
    }

    setState(() {
      _selectedTargetListId = listId;
    });
  }

  Future<void> _saveLists() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _service.saveLists(_lists);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openListManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ShoppingListsScreen(),
      ),
    );

    if (!mounted) return;

    await _loadLists(
      preferredTargetListId: _selectedTargetListId,
    );
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ShoppingHistoryScreen(),
      ),
    );

    if (!mounted) return;

    await _loadLists(
      preferredTargetListId: _selectedTargetListId,
    );
  }

  String _generateId() {
    final random = math.Random();

    return '${DateTime.now().millisecondsSinceEpoch}'
        '${random.nextInt(999999)}';
  }

  List<String> get _categories {
    final categories = <String>[
      ...ShoppingCategories.categories,
      ..._allItems.map((item) => item.category),
      ...defaultProductSuggestions.map(
            (suggestion) => suggestion.category,
      ),
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

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toString().replaceAll('.', ',');
  }

  String _emojiForItem(ShoppingItem item) {
    final normalizedName = item.name.trim().toLowerCase();

    for (final suggestion in defaultProductSuggestions) {
      if (suggestion.name.toLowerCase() == normalizedName) {
        return suggestion.emoji;
      }
    }

    return '🛒';
  }

  void _showShortMessage(
      String message, {
        SnackBarAction? action,
      }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          action: action,
        ),
      );
  }

  Future<void> _showNewItemDialog({
    String initialName = '',
  }) async {
    final targetList = _selectedTargetList;

    if (targetList == null) {
      _showShortMessage(
        'Erstelle zuerst eine Einkaufsliste.',
      );
      return;
    }

    final result = await showShoppingItemSheet(
      context: context,
      listName: targetList.name,
      categories: _categories,
      initialName: initialName,
      initialCategory: _selectedCategory,
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      targetList.items.add(
        ShoppingItem(
          id: _generateId(),
          name: result.name,
          quantity: result.quantity,
          unit: result.unit,
          category: result.category,
          note: result.note,
        ),
      );
    });

    await _saveLists();
  }

  Future<void> _showEditItemDialog(
      _ShoppingEntry entry,
      ) async {
    final result = await showShoppingItemSheet(
      context: context,
      listName: entry.list.name,
      categories: _categories,
      item: entry.item,
      initialCategory: entry.item.category,
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      entry.item.name = result.name;
      entry.item.quantity = result.quantity;
      entry.item.unit = result.unit;
      entry.item.category = result.category;
      entry.item.note = result.note;
    });

    await _saveLists();
  }

  Future<void> _toggleFavorite(
      _ShoppingEntry entry,
      ) async {
    setState(() {
      entry.item.favorite = !entry.item.favorite;
    });

    await _saveLists();
  }

  Future<void> _moveToCart(
      _ShoppingEntry entry,
      ) async {
    if (entry.item.done) {
      return;
    }

    setState(() {
      entry.item.done = true;
      entry.item.purchaseCount++;
      entry.item.lastPurchased = DateTime.now();
    });

    await _saveLists();

    if (!mounted) return;

    _showShortMessage(
      '${entry.item.name} liegt jetzt im Einkaufswagen.',
      action: SnackBarAction(
        label: 'Rückgängig',
        onPressed: () {
          _restoreFromCart(entry);
        },
      ),
    );
  }

  Future<void> _restoreFromCart(
      _ShoppingEntry entry,
      ) async {
    final itemStillExists = entry.list.items.any(
          (item) => item.id == entry.item.id,
    );

    if (!itemStillExists) {
      return;
    }

    setState(() {
      entry.item.done = false;

      if (entry.item.purchaseCount > 0) {
        entry.item.purchaseCount--;
      }

      entry.item.lastPurchased = null;
    });

    await _saveLists();
  }

  Future<void> _toggleItem(
      _ShoppingEntry entry,
      bool value,
      ) async {
    if (value) {
      await _moveToCart(entry);
    } else {
      await _restoreFromCart(entry);
    }
  }

  Future<void> _deleteItem(
      _ShoppingEntry entry,
      ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Artikel löschen?'),
          content: Text(
            '„${entry.item.name}“ wird aus '
                '„${entry.list.name}“ entfernt.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      entry.list.items.removeWhere(
            (item) => item.id == entry.item.id,
      );
    });

    await _saveLists();
  }

  Future<void> _finishShopping(
      List<_ShoppingEntry> cartEntries,
      ) async {
    if (cartEntries.isEmpty || _isSaving) {
      return;
    }

    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Einkauf abschließen?'),
          content: Text(
            '${cartEntries.length} Artikel werden aus dem '
                'Einkaufswagen entfernt und dauerhaft in der '
                'Einkaufshistorie gespeichert.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.check),
              label: const Text('Abschließen'),
            ),
          ],
        );
      },
    );

    if (shouldFinish != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final completedAt = DateTime.now();

    final sourceLists = <String, ShoppingList>{};

    for (final entry in cartEntries) {
      sourceLists[entry.list.id] = entry.list;
    }

    final historyEntry = ShoppingHistoryEntry(
      id: _generateId(),
      completedAt: completedAt,
      items: cartEntries
          .map(
            (entry) => ShoppingHistoryItem.fromShoppingItem(
          item: entry.item,
          sourceListId: entry.list.id,
          sourceListName: entry.list.name,
          purchasedAt:
          entry.item.lastPurchased ?? completedAt,
        ),
      )
          .toList(),
      sourceListIds: sourceLists.keys.toList(),
      sourceListNames: sourceLists.values
          .map((list) => list.name)
          .toList(),
    );

    final cartItemIds = cartEntries
        .map((entry) => entry.item.id)
        .toSet();

    try {
      await _service.addHistoryEntry(historyEntry);

      for (final list in _lists) {
        list.items.removeWhere(
              (item) => cartItemIds.contains(item.id),
        );
      }

      await _service.saveLists(_lists);

      if (!mounted) return;

      setState(() {});

      _showShortMessage(
        'Einkauf gespeichert und abgeschlossen.',
        action: SnackBarAction(
          label: 'Historie',
          onPressed: _openHistory,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      _showShortMessage(
        'Der Einkauf konnte nicht abgeschlossen werden.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<_ShoppingEntry> _filteredEntries() {
    final entries = _allEntries.where((entry) {
      final matchesSearch = entry.item.name
          .toLowerCase()
          .contains(_search);

      final matchesCategory =
          _selectedCategory == null ||
              entry.item.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    entries.sort((a, b) {
      final categoryComparison = _categoryIndex(
        a.item.category,
      ).compareTo(
        _categoryIndex(b.item.category),
      );

      if (categoryComparison != 0) {
        return categoryComparison;
      }

      if (a.item.favorite != b.item.favorite) {
        return a.item.favorite ? -1 : 1;
      }

      final nameComparison = a.item.name
          .toLowerCase()
          .compareTo(
        b.item.name.toLowerCase(),
      );

      if (nameComparison != 0) {
        return nameComparison;
      }

      return a.list.name
          .toLowerCase()
          .compareTo(
        b.list.name.toLowerCase(),
      );
    });

    return entries;
  }

  List<Widget> _buildGroupedEntries(
      BuildContext context,
      List<_ShoppingEntry> entries,
      ) {
    final groupedEntries =
    <String, List<_ShoppingEntry>>{};

    for (final entry in entries) {
      groupedEntries.putIfAbsent(
        entry.item.category,
            () => [],
      );

      groupedEntries[entry.item.category]!.add(entry);
    }

    final visibleCategories =
    groupedEntries.keys.toList()
      ..sort(
            (a, b) => _categoryIndex(a).compareTo(
          _categoryIndex(b),
        ),
      );

    return visibleCategories.expand((category) {
      final categoryEntries = groupedEntries[category]!;

      return [
        Padding(
          padding: const EdgeInsets.only(
            top: 12,
            bottom: 4,
          ),
          child: Text(
            category,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...categoryEntries.map(
              (entry) => _buildEntryCard(
            context,
            entry,
          ),
        ),
      ];
    }).toList();
  }

  Widget _buildEntryCard(
      BuildContext context,
      _ShoppingEntry entry,
      ) {
    final item = entry.item;

    final titleStyle = TextStyle(
      fontWeight:
      item.favorite ? FontWeight.bold : FontWeight.w600,
      decoration: item.done
          ? TextDecoration.lineThrough
          : TextDecoration.none,
    );

    final subtitleStyle = TextStyle(
      decoration: item.done
          ? TextDecoration.lineThrough
          : TextDecoration.none,
    );

    final quantityText =
        '${_formatQuantity(item.quantity)} ${item.unit}';

    final detailsText = item.note.trim().isEmpty
        ? quantityText
        : '$quantityText • ${item.note}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        onTap: () {
          _showEditItemDialog(entry);
        },
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _emojiForItem(item),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 4),
            Checkbox(
              value: item.done,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize:
              MaterialTapTargetSize.shrinkWrap,
              onChanged: (value) {
                _toggleItem(
                  entry,
                  value ?? false,
                );
              },
            ),
          ],
        ),
        title: Text(
          item.name,
          style: titleStyle,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detailsText,
              style: subtitleStyle,
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(
                  Icons.list_alt,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<_ItemAction>(
          tooltip: 'Optionen',
          onSelected: (action) {
            if (action == _ItemAction.favorite) {
              _toggleFavorite(entry);
            } else if (action == _ItemAction.edit) {
              _showEditItemDialog(entry);
            } else if (action == _ItemAction.delete) {
              _deleteItem(entry);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ItemAction.favorite,
              child: Row(
                children: [
                  Icon(
                    item.favorite
                        ? Icons.star
                        : Icons.star_border,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.favorite
                        ? 'Favorit entfernen'
                        : 'Als Favorit markieren',
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: _ItemAction.edit,
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 12),
                  Text('Bearbeiten'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: _ItemAction.delete,
              child: Row(
                children: [
                  Icon(Icons.delete_outline),
                  SizedBox(width: 12),
                  Text('Löschen'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard({
    required int cartCount,
    required int totalCount,
  }) {
    final progress =
    totalCount == 0 ? 0.0 : cartCount / totalCount;

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$cartCount von $totalCount Artikeln '
                        'im Einkaufswagen',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).round()} %',
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetListSelector() {
    if (_lists.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(
            Icons.playlist_add,
          ),
          title: const Text(
            'Noch keine Einkaufsliste',
          ),
          subtitle: const Text(
            'Erstelle zuerst eine Liste.',
          ),
          trailing: FilledButton(
            onPressed: _openListManagement,
            child: const Text('Erstellen'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          8,
          8,
        ),
        child: Row(
          children: [
            const Icon(Icons.playlist_add),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedTargetListId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Neue Artikel hinzufügen zu',
                  border: InputBorder.none,
                ),
                items: _lists.map((list) {
                  final openItems = list.items
                      .where((item) => !item.done)
                      .length;

                  return DropdownMenuItem(
                    value: list.id,
                    child: Text(
                      '${list.name} ($openItems offen)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _selectTargetList,
              ),
            ),
            IconButton(
              onPressed: _openListManagement,
              icon: const Icon(
                Icons.settings_outlined,
              ),
              tooltip: 'Einkaufslisten verwalten',
            ),
            IconButton(
              onPressed: () {
                _loadLists(
                  preferredTargetListId:
                  _selectedTargetListId,
                );
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Neu laden',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSection(
      BuildContext context,
      List<_ShoppingEntry> visibleCartEntries,
      List<_ShoppingEntry> allCartEntries,
      ) {
    if (allCartEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.shopping_cart),
        title: Text(
          'Im Einkaufswagen (${allCartEntries.length})',
        ),
        subtitle: visibleCartEntries.length == allCartEntries.length
            ? const Text(
          'Artikel können zurückgelegt oder '
              'gemeinsam abgeschlossen werden.',
        )
            : Text(
          '${visibleCartEntries.length} von '
              '${allCartEntries.length} Artikeln sichtbar',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        children: [
          if (visibleCartEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Der Einkaufswagen enthält Artikel, '
                    'die nicht zum aktuellen Filter passen.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._buildGroupedEntries(
              context,
              visibleCartEntries,
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                _finishShopping(allCartEntries);
              },
              icon: const Icon(Icons.done_all),
              label: Text(
                'Einkauf abschließen '
                    '(${allCartEntries.length})',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredEntries();

    final openEntries = filteredEntries
        .where((entry) => !entry.item.done)
        .toList();

    final visibleCartEntries = filteredEntries
        .where((entry) => entry.item.done)
        .toList();

    final allCartEntries = _allEntries
        .where((entry) => entry.item.done)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkauf'),
        actions: [
          IconButton(
            onPressed: _openHistory,
            icon: const Icon(Icons.history),
            tooltip: 'Einkaufshistorie',
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: _selectedTargetList == null
            ? null
            : _showNewItemDialog,
        icon: const Icon(Icons.add),
        label: const Text('Artikel'),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: () => _loadLists(
          preferredTargetListId:
          _selectedTargetListId,
        ),
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            180,
          ),
          children: [
            _buildTargetListSelector(),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              enabled: _lists.isNotEmpty,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText:
                'In allen Listen suchen...',
              ),
            ),
            const SectionTitle(
              title: '⭐ Häufig gekauft',
            ),
            FrequentItems(
              items: _allItems,
              onTap: (name) {
                _showNewItemDialog(
                  initialName: name,
                );
              },
            ),
            const SectionTitle(
              title: '🗂 Kategorien',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Alle'),
                  selected:
                  _selectedCategory == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                ),
                ..._categories.map(
                      (category) => ChoiceChip(
                    label: Text(category),
                    selected:
                    _selectedCategory ==
                        category,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory =
                        selected
                            ? category
                            : null;
                      });
                    },
                  ),
                ),
              ],
            ),
            _buildProgressCard(
              cartCount: allCartEntries.length,
              totalCount: _allEntries.length,
            ),
            SectionTitle(
              title:
              '🛒 Noch zu kaufen (${openEntries.length})',
            ),
            if (_lists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Erstelle zuerst eine '
                        'Einkaufsliste.',
                  ),
                ),
              )
            else if (openEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Keine offenen Artikel mehr. 🎉',
                  ),
                ),
              )
            else
              ..._buildGroupedEntries(
                context,
                openEntries,
              ),
            _buildCartSection(
              context,
              visibleCartEntries,
              allCartEntries,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingEntry {
  const _ShoppingEntry({
    required this.list,
    required this.item,
  });

  final ShoppingList list;
  final ShoppingItem item;
}

enum _ItemAction {
  favorite,
  edit,
  delete,
}
