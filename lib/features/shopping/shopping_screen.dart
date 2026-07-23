import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/shopping_categories.dart';
import 'default_product_suggestions.dart';
import 'product_suggestion.dart';
import 'shopping_item.dart';
import 'shopping_list.dart';
import 'shopping_lists_screen.dart';
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

  List<ShoppingList> _lists = [];
  List<ShoppingItem> _items = [];

  String? _selectedListId;
  String _search = '';
  String? _selectedCategory;

  bool _isLoading = true;
  bool _isSaving = false;

  ShoppingList? get _selectedList {
    final selectedListId = _selectedListId;

    if (selectedListId == null) {
      return null;
    }

    for (final list in _lists) {
      if (list.id == selectedListId) {
        return list;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_handleSearchChanged);
    _loadLists();
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
    String? preferredListId,
  }) async {
    setState(() {
      _isLoading = true;
    });

    final loadedLists = await _service.loadLists();

    if (!mounted) return;

    String? nextListId = preferredListId ?? _selectedListId;

    final containsSelectedList = loadedLists.any(
          (list) => list.id == nextListId,
    );

    if (!containsSelectedList) {
      nextListId = loadedLists.isEmpty ? null : loadedLists.first.id;
    }

    final selectedList = loadedLists
        .where((list) => list.id == nextListId)
        .cast<ShoppingList?>()
        .firstOrNull;

    setState(() {
      _lists = loadedLists;
      _selectedListId = nextListId;
      _items = selectedList == null
          ? []
          : List<ShoppingItem>.from(selectedList.items);
      _selectedCategory = null;
      _sortItems();
      _isLoading = false;
    });
  }

  Future<void> _selectList(String? listId) async {
    if (listId == null || listId == _selectedListId) {
      return;
    }

    final list = _lists.where((entry) => entry.id == listId).firstOrNull;

    if (list == null) {
      return;
    }

    setState(() {
      _selectedListId = list.id;
      _items = List<ShoppingItem>.from(list.items);
      _selectedCategory = null;
      _sortItems();
    });
  }

  Future<void> _saveItems() async {
    final selectedListId = _selectedListId;

    if (selectedListId == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final lists = await _service.loadLists();
      final index = lists.indexWhere(
            (list) => list.id == selectedListId,
      );

      if (index == -1) {
        return;
      }

      lists[index].items = List<ShoppingItem>.from(_items);
      await _service.saveLists(lists);

      if (!mounted) return;

      setState(() {
        _lists = lists;
      });
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
      preferredListId: _selectedListId,
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
      ..._items.map((item) => item.category),
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

  void _sortItems() {
    _items.sort((a, b) {
      final categoryComparison = _categoryIndex(
        a.category,
      ).compareTo(
        _categoryIndex(b.category),
      );

      if (categoryComparison != 0) {
        return categoryComparison;
      }

      if (a.favorite != b.favorite) {
        return a.favorite ? -1 : 1;
      }

      return a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      );
    });
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toString().replaceAll('.', ',');
  }

  List<ProductSuggestion> _matchingSuggestions(String query) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return [];
    }

    return defaultProductSuggestions
        .where(
          (suggestion) => suggestion.name
          .toLowerCase()
          .contains(normalizedQuery),
    )
        .take(6)
        .toList();
  }

  ProductSuggestion? _suggestionForName(String name) {
    final normalizedName = name.trim().toLowerCase();

    for (final suggestion in defaultProductSuggestions) {
      if (suggestion.name.toLowerCase() == normalizedName) {
        return suggestion;
      }
    }

    return null;
  }

  void _showItemDialog({
    String initialName = '',
    ShoppingItem? item,
  }) {
    if (_selectedList == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erstelle zuerst eine Einkaufsliste.',
          ),
        ),
      );
      return;
    }

    var query = item?.name ?? initialName;
    var selectedProduct = item?.name;
    var dialogCategory =
        item?.category ?? _selectedCategory ?? 'Sonstiges';
    var dialogUnit = item?.unit ?? 'Stk.';
    var quantity = _formatQuantity(item?.quantity ?? 1);
    var note = item?.note ?? '';

    final isEditing = item != null;
    var showDetails = isEditing;

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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final suggestions = _matchingSuggestions(query);
            final mediaQuery = MediaQuery.of(context);

            final availableHeight = math.max(
              300.0,
              mediaQuery.size.height -
                  mediaQuery.viewInsets.bottom -
                  mediaQuery.padding.top -
                  24,
            );

            return Padding(
              padding: EdgeInsets.only(
                bottom: mediaQuery.viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: availableHeight,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .outline,
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isEditing
                                    ? 'Artikel bearbeiten'
                                    : showDetails
                                    ? 'Details festlegen'
                                    : 'Artikel hinzufügen',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
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
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            avatar: const Icon(
                              Icons.list_alt,
                              size: 18,
                            ),
                            label: Text(
                              'Liste: ${_selectedList!.name}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!showDetails) ...[
                          TextFormField(
                            key: const ValueKey(
                              'product-search',
                            ),
                            initialValue: query,
                            autofocus: true,
                            textCapitalization:
                            TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Artikel suchen',
                              hintText: 'z. B. Milch',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                query = value;
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                          if (query.trim().isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 24,
                              ),
                              child: Text(
                                'Gib einen Artikelnamen ein, '
                                    'um passende Produkte zu sehen.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          else if (suggestions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                              ),
                              child: Text(
                                'Kein passendes Produkt gefunden.\n'
                                    'Du kannst „${query.trim()}“ '
                                    'trotzdem hinzufügen.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          else ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Passende Produkte',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics:
                                const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.45,
                                children:
                                suggestions.map((suggestion) {
                                  return OutlinedButton(
                                    onPressed: () {
                                      FocusScope.of(
                                        sheetContext,
                                      ).unfocus();

                                      setSheetState(() {
                                        selectedProduct =
                                            suggestion.name;
                                        query = suggestion.name;
                                        dialogCategory =
                                            suggestion.category;
                                        showDetails = true;
                                      });
                                    },
                                    style:
                                    OutlinedButton.styleFrom(
                                      padding:
                                      const EdgeInsets.all(10),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          suggestion.emoji,
                                          style: const TextStyle(
                                            fontSize: 28,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          suggestion.name,
                                          textAlign:
                                          TextAlign.center,
                                          maxLines: 2,
                                          overflow:
                                          TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: query.trim().isEmpty
                                  ? null
                                  : () {
                                FocusScope.of(
                                  sheetContext,
                                ).unfocus();

                                final exactSuggestion =
                                _suggestionForName(
                                  query,
                                );

                                setSheetState(() {
                                  selectedProduct =
                                      query.trim();

                                  if (exactSuggestion !=
                                      null) {
                                    dialogCategory =
                                        exactSuggestion
                                            .category;
                                  }

                                  showDetails = true;
                                });
                              },
                              child: const Text('Weiter'),
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Text(
                                _suggestionForName(
                                  selectedProduct ?? query,
                                )?.emoji ??
                                    '🛒',
                                style: const TextStyle(
                                  fontSize: 38,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedProduct ?? query,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: const ValueKey(
                                    'quantity',
                                  ),
                                  initialValue: quantity,
                                  keyboardType:
                                  const TextInputType
                                      .numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration:
                                  const InputDecoration(
                                    labelText: 'Menge',
                                  ),
                                  onChanged: (value) {
                                    quantity = value;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child:
                                DropdownButtonFormField<
                                    String>(
                                  initialValue: dialogUnit,
                                  isExpanded: true,
                                  decoration:
                                  const InputDecoration(
                                    labelText: 'Einheit',
                                  ),
                                  items: units.map((unit) {
                                    return DropdownMenuItem(
                                      value: unit,
                                      child: Text(unit),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value == null) return;

                                    setSheetState(() {
                                      dialogUnit = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: dialogCategory,
                            isExpanded: true,
                            decoration:
                            const InputDecoration(
                              labelText: 'Kategorie',
                            ),
                            items: _categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;

                              setSheetState(() {
                                dialogCategory = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('note'),
                            initialValue: note,
                            textCapitalization:
                            TextCapitalization.sentences,
                            maxLines: 2,
                            decoration:
                            const InputDecoration(
                              labelText: 'Notiz',
                              hintText: 'z. B. laktosefrei',
                            ),
                            onChanged: (value) {
                              note = value;
                            },
                          ),
                          if (!isEditing) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                setSheetState(() {
                                  showDetails = false;
                                  selectedProduct = null;
                                });
                              },
                              icon: const Icon(
                                Icons.arrow_back,
                              ),
                              label: const Text(
                                'Anderen Artikel wählen',
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () async {
                                final wasSaved =
                                await _saveItem(
                                  item: item,
                                  name:
                                  selectedProduct ?? query,
                                  quantity: quantity,
                                  unit: dialogUnit,
                                  category: dialogCategory,
                                  note: note,
                                );

                                if (wasSaved &&
                                    sheetContext.mounted) {
                                  Navigator.of(
                                    sheetContext,
                                  ).pop();
                                }
                              },
                              child: const Text('Speichern'),
                            ),
                          ),
                        ],
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

  Future<bool> _saveItem({
    required ShoppingItem? item,
    required String name,
    required String quantity,
    required String unit,
    required String category,
    required String note,
  }) async {
    final cleanedName = name.trim();
    final parsedQuantity = double.tryParse(
      quantity.trim().replaceAll(',', '.'),
    ) ??
        1;

    if (cleanedName.isEmpty || parsedQuantity <= 0) {
      return false;
    }

    setState(() {
      if (item == null) {
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
    return true;
  }

  Future<void> _toggleFavorite(int index) async {
    setState(() {
      _items[index].favorite =
      !_items[index].favorite;
      _sortItems();
    });

    await _saveItems();
  }

  Future<void> _toggleItem(
      int index,
      bool value,
      ) async {
    final wasDone = _items[index].done;

    setState(() {
      _items[index].done = value;

      if (value && !wasDone) {
        _items[index].purchaseCount++;
        _items[index].lastPurchased = DateTime.now();
      }
    });

    await _saveItems();
  }

  Future<void> _deleteItem(int index) async {
    setState(() {
      _items.removeAt(index);
    });

    await _saveItems();
  }

  List<Widget> _buildGroupedItems(
      BuildContext context,
      List<ShoppingItem> shoppingItems,
      ) {
    final groupedItems =
    <String, List<ShoppingItem>>{};

    for (final item in shoppingItems) {
      groupedItems.putIfAbsent(
        item.category,
            () => [],
      );
      groupedItems[item.category]!.add(item);
    }

    final visibleCategories =
    groupedItems.keys.toList()
      ..sort(
            (a, b) => _categoryIndex(a).compareTo(
          _categoryIndex(b),
        ),
      );

    return visibleCategories.expand((category) {
      final categoryItems = groupedItems[category]!;

      return [
        Padding(
          padding: const EdgeInsets.only(
            top: 12,
            bottom: 4,
          ),
          child: Text(
            category,
            style:
            Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...categoryItems.map((item) {
          final index = _items.indexOf(item);

          return ShoppingTile(
            item: item,
            onChanged: (value) {
              _toggleItem(
                index,
                value ?? false,
              );
            },
            onDelete: () => _deleteItem(index),
            onFavorite: () => _toggleFavorite(index),
            onTap: () => _showItemDialog(item: item),
          );
        }),
      ];
    }).toList();
  }

  Widget _buildProgressCard({
    required int completedCount,
    required int totalCount,
  }) {
    final progress =
    totalCount == 0 ? 0.0 : completedCount / totalCount;

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
                    '$completedCount von $totalCount '
                        'Artikeln erledigt',
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
              borderRadius:
              BorderRadius.circular(20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSelector() {
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
            const Icon(Icons.list_alt),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedListId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Einkaufsliste',
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
                onChanged: _selectList,
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
              onPressed: () => _loadLists(
                preferredListId: _selectedListId,
              ),
              icon: const Icon(Icons.refresh),
              tooltip: 'Neu laden',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) {
      final matchesSearch =
      item.name.toLowerCase().contains(_search);

      final matchesCategory =
          _selectedCategory == null ||
              item.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    final openItems = filteredItems
        .where((item) => !item.done)
        .toList();

    final completedItems = filteredItems
        .where((item) => item.done)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkauf'),
        actions: [
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
        onPressed: _selectedList == null
            ? null
            : () => _showItemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Artikel'),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: () => _loadLists(
          preferredListId: _selectedListId,
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
            _buildListSelector(),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              enabled: _selectedList != null,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Artikel suchen...',
              ),
            ),
            const SectionTitle(
              title: '⭐ Häufig gekauft',
            ),
            FrequentItems(
              items: _items,
              onTap: (name) {
                _showItemDialog(
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
              completedCount:
              completedItems.length,
              totalCount:
              filteredItems.length,
            ),
            SectionTitle(
              title:
              '🛒 Noch zu kaufen (${openItems.length})',
            ),
            if (_selectedList == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Erstelle zuerst eine '
                        'Einkaufsliste.',
                  ),
                ),
              )
            else if (openItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Alles erledigt – '
                        'die Liste ist leer. 🎉',
                  ),
                ),
              )
            else
              ..._buildGroupedItems(
                context,
                openItems,
              ),
            if (completedItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: ExpansionTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                  ),
                  title: Text(
                    'Erledigt '
                        '(${completedItems.length})',
                  ),
                  subtitle: const Text(
                    'Antippen, um gekaufte '
                        'Artikel zu sehen',
                  ),
                  childrenPadding:
                  const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    12,
                  ),
                  children: _buildGroupedItems(
                    context,
                    completedItems,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension _IterableFirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;

    if (!iterator.moveNext()) {
      return null;
    }

    return iterator.current;
  }
}
