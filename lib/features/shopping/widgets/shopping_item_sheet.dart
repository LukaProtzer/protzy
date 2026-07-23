import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../default_product_suggestions.dart';
import '../product_suggestion.dart';
import '../shopping_item.dart';

class ShoppingItemSheetResult {
  const ShoppingItemSheetResult({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.note,
  });

  final String name;
  final double quantity;
  final String unit;
  final String category;
  final String note;
}

Future<ShoppingItemSheetResult?> showShoppingItemSheet({
  required BuildContext context,
  required String listName,
  required List<String> categories,
  ShoppingItem? item,
  String initialName = '',
  String? initialCategory,
}) {
  return showModalBottomSheet<ShoppingItemSheetResult>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _ShoppingItemSheet(
        listName: listName,
        categories: categories,
        item: item,
        initialName: initialName,
        initialCategory: initialCategory,
      );
    },
  );
}

class _ShoppingItemSheet extends StatefulWidget {
  const _ShoppingItemSheet({
    required this.listName,
    required this.categories,
    required this.item,
    required this.initialName,
    required this.initialCategory,
  });

  final String listName;
  final List<String> categories;
  final ShoppingItem? item;
  final String initialName;
  final String? initialCategory;

  @override
  State<_ShoppingItemSheet> createState() =>
      _ShoppingItemSheetState();
}

class _ShoppingItemSheetState extends State<_ShoppingItemSheet> {
  static const List<String> _allUnits = [
    'Stk.',
    'g',
    'kg',
    'ml',
    'l',
    'Packung',
    'Beutel',
    'Glas',
    'Dose',
    'Flasche',
    'Kiste',
    'Karton',
    'Bund',
    'Rolle',
    'Tray',
  ];

  late final TextEditingController _searchController;
  late final TextEditingController _quantityController;
  late final TextEditingController _noteController;

  late String? _selectedProductName;
  late String _unit;
  late String _category;
  late bool _showDetails;
  late bool _showAllUnits;
  late bool _showNote;

  bool get _isEditing => widget.item != null;

  String get _currentProductName {
    final selectedName = _selectedProductName?.trim();

    if (selectedName != null && selectedName.isNotEmpty) {
      return selectedName;
    }

    return _searchController.text.trim();
  }

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _searchController = TextEditingController(
      text: item?.name ?? widget.initialName,
    );
    _quantityController = TextEditingController(
      text: _formatQuantity(item?.quantity ?? 1),
    );
    _noteController = TextEditingController(
      text: item?.note ?? '',
    );

    _selectedProductName = item?.name;
    _unit = item?.unit ?? 'Stk.';
    _category = item?.category ??
        widget.initialCategory ??
        'Sonstiges';
    _showDetails = _isEditing;
    _showAllUnits = false;
    _showNote = (item?.note.trim().isNotEmpty ?? false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<ProductSuggestion> get _matchingSuggestions {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return [];
    }

    final startsWithMatches = defaultProductSuggestions
        .where(
          (suggestion) => suggestion.name
          .toLowerCase()
          .startsWith(query),
    )
        .toList();

    final containsMatches = defaultProductSuggestions
        .where(
          (suggestion) =>
      !suggestion.name.toLowerCase().startsWith(query) &&
          suggestion.name.toLowerCase().contains(query),
    )
        .toList();

    return [
      ...startsWithMatches,
      ...containsMatches,
    ].take(8).toList();
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

  List<String> get _recommendedUnits {
    final product = _currentProductName.toLowerCase();
    final category = _category.toLowerCase();

    if (product.contains('milchpulver') ||
        product.contains('mehl') ||
        product.contains('zucker') ||
        product.contains('reis') ||
        product.contains('nudel') ||
        product.contains('kaffee') ||
        product.contains('salz') ||
        product.contains('gewürz')) {
      return ['g', 'kg', 'Packung', 'Beutel', 'Dose'];
    }

    if (product.contains('milch') ||
        product.contains('saft') ||
        product.contains('wasser') ||
        product.contains('öl') ||
        product.contains('essig') ||
        category.contains('getränke')) {
      return ['ml', 'l', 'Flasche', 'Packung', 'Kiste'];
    }

    if (product.contains('joghurt') ||
        product.contains('quark') ||
        product.contains('sahne') ||
        product.contains('aufstrich')) {
      return ['g', 'kg', 'Becher', 'Packung', 'Glas']
          .where(_allUnits.contains)
          .toList();
    }

    if (category.contains('obst') ||
        category.contains('gemüse')) {
      return ['Stk.', 'g', 'kg', 'Bund', 'Beutel'];
    }

    if (category.contains('haushalt') ||
        category.contains('drogerie')) {
      return ['Stk.', 'Packung', 'Flasche', 'Rolle', 'Karton'];
    }

    return ['Stk.', 'Packung', 'g', 'kg', 'Flasche'];
  }

  List<String> get _visibleUnits {
    final units = <String>{
      ..._recommendedUnits,
      _unit,
    }.where(_allUnits.contains).toList();

    if (_showAllUnits) {
      return _allUnits;
    }

    return units.take(5).toList();
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toString().replaceAll('.', ',');
  }

  void _selectSuggestion(ProductSuggestion suggestion) {
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedProductName = suggestion.name;
      _searchController.text = suggestion.name;
      _category = suggestion.category;
      _showDetails = true;
      _showAllUnits = false;

      final recommended = _recommendedUnits;
      if (!_recommendedUnits.contains(_unit) && recommended.isNotEmpty) {
        _unit = recommended.first;
      }
    });
  }

  void _continueWithCurrentQuery() {
    final name = _searchController.text.trim();

    if (name.isEmpty) {
      return;
    }

    final suggestion = _suggestionForName(name);

    FocusScope.of(context).unfocus();

    setState(() {
      _selectedProductName = name;

      if (suggestion != null) {
        _category = suggestion.category;
      }

      _showDetails = true;
      _showAllUnits = false;
    });
  }

  void _goBackToSearch() {
    FocusScope.of(context).unfocus();

    setState(() {
      _showDetails = false;
      _selectedProductName = null;
    });
  }

  void _changeQuantity(double amount) {
    final currentValue = double.tryParse(
      _quantityController.text
          .trim()
          .replaceAll(',', '.'),
    ) ??
        1;

    final nextValue = math.max(
      0.1,
      currentValue + amount,
    );

    _quantityController.text = _formatQuantity(nextValue);
    _quantityController.selection = TextSelection.collapsed(
      offset: _quantityController.text.length,
    );

    setState(() {});
  }

  void _save() {
    final name = _currentProductName;
    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );

    if (name.isEmpty || quantity == null || quantity <= 0) {
      final messenger = ScaffoldMessenger.of(context);

      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Bitte prüfe Artikelname und Menge.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }

    Navigator.of(context).pop(
      ShoppingItemSheetResult(
        name: name,
        quantity: quantity,
        unit: _unit,
        category: _category,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final availableHeight = math.max(
      360.0,
      mediaQuery.size.height -
          mediaQuery.viewInsets.bottom -
          mediaQuery.padding.top -
          16,
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
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTopArea(context),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _showDetails
                      ? _buildDetailsStep(context)
                      : _buildSearchStep(context),
                ),
              ),
              if (_showDetails) _buildBottomAction(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopArea(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        12,
        14,
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (_showDetails && !_isEditing)
                IconButton.filledTonal(
                  onPressed: _goBackToSearch,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Zurück',
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _isEditing
                        ? Icons.edit_outlined
                        : Icons.add_shopping_cart,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing
                          ? 'Artikel bearbeiten'
                          : _showDetails
                          ? 'Fast geschafft'
                          : 'Artikel hinzufügen',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _showDetails
                          ? 'Menge kurz prüfen und speichern'
                          : 'Suchen oder frei eingeben',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close),
                tooltip: 'Schließen',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildListBadge(context),
        ],
      ),
    );
  }

  Widget _buildListBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.list_alt,
              size: 19,
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.listName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Zielliste',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final suggestions = _matchingSuggestions;

    return ListView(
      key: const ValueKey('search-step'),
      padding: const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        28,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'z. B. Milch, Tomaten, Waschmittel',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedProductName = null;
                  });
                },
                icon: const Icon(Icons.close),
              ),
              border: InputBorder.none,
              filled: false,
            ),
            onChanged: (_) {
              setState(() {
                _selectedProductName = null;
              });
            },
            onSubmitted: (_) {
              _continueWithCurrentQuery();
            },
          ),
        ),
        const SizedBox(height: 20),
        if (_searchController.text.trim().isEmpty)
          _buildSearchHint(context)
        else if (suggestions.isEmpty)
          _buildCustomProductCard(context)
        else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Passende Artikel',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${suggestions.length} Treffer',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...suggestions.map(
                  (suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSuggestionTile(
                  context,
                  suggestion,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildCustomProductCard(context),
          ],
      ],
    );
  }

  Widget _buildSearchHint(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Text(
                '🛒',
                style: TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Was brauchst du?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Suchen, auswählen und direkt zur Liste hinzufügen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(
      BuildContext context,
      ProductSuggestion suggestion,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.7,
      ),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          _selectSuggestion(suggestion);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    suggestion.emoji,
                    style: const TextStyle(fontSize: 27),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      suggestion.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomProductCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = _searchController.text.trim();

    return Material(
      color: colorScheme.tertiaryContainer.withValues(
        alpha: 0.45,
      ),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: name.isEmpty ? null : _continueWithCurrentQuery,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.edit_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty
                          ? 'Eigenen Artikel eingeben'
                          : '„$name“ verwenden',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Auch ohne passenden Vorschlag hinzufügen',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsStep(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final productName = _currentProductName;
    final suggestion = _suggestionForName(productName);

    return ListView(
      key: const ValueKey('details-step'),
      padding: const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        24,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(
              alpha: 0.32,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    suggestion?.emoji ?? '🛒',
                    style: const TextStyle(fontSize: 29),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildQuantityCard(context),
        const SizedBox(height: 14),
        _buildCategoryCard(context),
        const SizedBox(height: 14),
        _buildNoteCard(context),
      ],
    );
  }

  Widget _buildQuantityCard(BuildContext context) {
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
          Text(
            'Menge',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () {
                    _changeQuantity(-1);
                  },
                  icon: const Icon(Icons.remove),
                  tooltip: 'Weniger',
                ),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    textAlign: TextAlign.center,
                    keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: '1',
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {
                    _changeQuantity(1);
                  },
                  icon: const Icon(Icons.add),
                  tooltip: 'Mehr',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _visibleUnits.map((unit) {
              return ChoiceChip(
                label: Text(unit),
                selected: _unit == unit,
                onSelected: (_) {
                  setState(() {
                    _unit = unit;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllUnits = !_showAllUnits;
                });
              },
              icon: Icon(
                _showAllUnits
                    ? Icons.expand_less
                    : Icons.expand_more,
              ),
              label: Text(
                _showAllUnits
                    ? 'Weniger Einheiten'
                    : 'Weitere Einheiten',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.category_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Kategorie',
                border: InputBorder.none,
              ),
              items: widget.categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(
                    category,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _category = value;
                  _showAllUnits = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 180),
      crossFadeState: _showNote
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            setState(() {
              _showNote = true;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.notes_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notiz hinzufügen',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'optional, z. B. laktosefrei',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.add),
              ],
            ),
          ),
        ),
      ),
      secondChild: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              autofocus: false,
              decoration: InputDecoration(
                labelText: 'Notiz',
                hintText: 'z. B. laktosefrei',
                prefixIcon: const Icon(Icons.notes_outlined),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_noteController.text.trim().isEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showNote = false;
                    });
                  },
                  child: const Text('Schließen'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        16,
      ),
      child: Container(
        padding: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(
                alpha: 0.45,
              ),
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(
              _isEditing
                  ? 'Änderungen speichern'
                  : 'Zur Liste hinzufügen',
            ),
          ),
        ),
      ),
    );
  }
}
