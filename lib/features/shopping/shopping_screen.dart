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
  final TextEditingController _searchController =
  TextEditingController();

  List<ShoppingList> _lists = [];

  String? _selectedTargetListId;
  String _search = '';
  String? _selectedCategory;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _showAllCategories = false;

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

  List<_ShoppingEntry> get _allCartEntries {
    return _allEntries
        .where((entry) => entry.item.done)
        .toList();
  }

  List<_ShoppingEntry> get _allOpenEntries {
    return _allEntries
        .where((entry) => !entry.item.done)
        .toList();
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

  List<String> get _visibleCategories {
    if (_showAllCategories) {
      return _categories;
    }

    return _categories.take(6).toList();
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
                'Historie gespeichert.',
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
      sourceListNames:
      sourceLists.values.map((list) => list.name).toList(),
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
          .compareTo(b.item.name.toLowerCase());

      if (nameComparison != 0) {
        return nameComparison;
      }

      return a.list.name
          .toLowerCase()
          .compareTo(b.list.name.toLowerCase());
    });

    return entries;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkauf'),
        actions: [
          IconButton(
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
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
            8,
            16,
            160,
          ),
          children: [
            _buildHeroCard(context),
            const SizedBox(height: 14),
            _buildSearchField(context),
            const SizedBox(height: 18),
            _buildQuickArea(context),
            const SizedBox(height: 18),
            _buildCategoryArea(context),
            const SizedBox(height: 22),
            _buildSectionHeader(
              context,
              title: 'Noch zu kaufen',
              count: openEntries.length,
              icon: Icons.shopping_basket_outlined,
            ),
            const SizedBox(height: 10),
            if (_lists.isEmpty)
              _buildEmptyState(
                context,
                icon: Icons.playlist_add,
                title: 'Noch keine Einkaufsliste',
                text:
                'Erstelle zuerst eine Liste und füge Artikel hinzu.',
                buttonText: 'Liste erstellen',
                onPressed: _openListManagement,
              )
            else if (openEntries.isEmpty)
              _buildEmptyState(
                context,
                icon: Icons.check_circle_outline,
                title: 'Alles erledigt',
                text:
                'Aktuell sind keine offenen Artikel vorhanden.',
              )
            else
              ..._buildGroupedEntries(
                context,
                openEntries,
              ),
            if (_allCartEntries.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildCartSection(
                context,
                visibleCartEntries,
                _allCartEntries,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final targetList = _selectedTargetList;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  Icons.playlist_add,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Neue Artikel gehen zu',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      targetList?.name ?? 'Keine Liste',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                enabled: _lists.isNotEmpty,
                tooltip: 'Zielliste auswählen',
                onSelected: (listId) {
                  setState(() {
                    _selectedTargetListId = listId;
                  });
                },
                itemBuilder: (context) {
                  return _lists.map((list) {
                    return PopupMenuItem(
                      value: list.id,
                      child: Row(
                        children: [
                          if (list.id == _selectedTargetListId)
                            const Icon(Icons.check),
                          if (list.id == _selectedTargetListId)
                            const SizedBox(width: 8),
                          Expanded(
                            child: Text(list.name),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.expand_more,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _openListManagement,
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Listen verwalten',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatPill(
                  context,
                  icon: Icons.shopping_basket_outlined,
                  value: '${_allOpenEntries.length}',
                  label: 'offen',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatPill(
                  context,
                  icon: Icons.shopping_cart_outlined,
                  value: '${_allCartEntries.length}',
                  label: 'im Wagen',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatPill(
                  context,
                  icon: Icons.list_alt,
                  value: '${_lists.length}',
                  label: 'Listen',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _selectedTargetList == null
                  ? null
                  : _showNewItemDialog,
              icon: const Icon(Icons.add),
              label: const Text('Artikel hinzufügen'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
      BuildContext context, {
        required IconData icon,
        required String value,
        required String label,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: _searchController,
        enabled: _lists.isNotEmpty,
        decoration: InputDecoration(
          hintText: 'In allen Listen suchen',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _searchController.clear();
            },
            icon: const Icon(Icons.close),
          ),
          border: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }

  Widget _buildQuickArea(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Häufig gekauft',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FrequentItems(
            items: _allItems,
            onTap: (name) {
              _showNewItemDialog(
                initialName: name,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryArea(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kategorien',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllCategories =
                    !_showAllCategories;
                  });
                },
                child: Text(
                  _showAllCategories
                      ? 'Weniger'
                      : 'Alle anzeigen',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Alle'),
                selected: _selectedCategory == null,
                onSelected: (_) {
                  setState(() {
                    _selectedCategory = null;
                  });
                },
              ),
              ..._visibleCategories.map(
                    (category) => ChoiceChip(
                  label: Text(category),
                  selected:
                  _selectedCategory == category,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory =
                      selected ? category : null;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, {
        required String title,
        required int count,
        required IconData icon,
      }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
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
            bottom: 6,
          ),
          child: Text(
            category,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final quantityText =
        '${_formatQuantity(item.quantity)} ${item.unit}';

    final detailsText = item.note.trim().isEmpty
        ? quantityText
        : '$quantityText • ${item.note}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            _showEditItemDialog(entry);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              12,
              8,
              12,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _emojiForItem(item),
                      style: const TextStyle(fontSize: 25),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w800,
                                decoration: item.done
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                          if (item.favorite)
                            const Icon(
                              Icons.star,
                              size: 18,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detailsText,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(
                          color:
                          colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.list_alt,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              entry.list.name,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: item.done,
                  onChanged: (value) {
                    _toggleItem(
                      entry,
                      value ?? false,
                    );
                  },
                ),
                PopupMenuButton<_ItemAction>(
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartSection(
      BuildContext context,
      List<_ShoppingEntry> visibleCartEntries,
      List<_ShoppingEntry> allCartEntries,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.shopping_cart),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Im Einkaufswagen',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${allCartEntries.length} Artikel bereit',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visibleCartEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
              ),
              child: Text(
                'Die Artikel im Einkaufswagen passen nicht '
                    'zum aktuellen Filter.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._buildGroupedEntries(
              context,
              visibleCartEntries,
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 54,
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

  Widget _buildEmptyState(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String text,
        String? buttonText,
        VoidCallback? onPressed,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 44,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ],
        ],
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
