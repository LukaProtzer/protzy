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
    builder: (sheetContext) {
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
  State<_ShoppingItemSheet> createState() => _ShoppingItemSheetState();
}

class _ShoppingItemSheetState extends State<_ShoppingItemSheet> {
  static const List<String> _units = [
    'Stk.',
    'g',
    'kg',
    'ml',
    'l',
    'Packung',
    'Dose',
    'Flasche',
  ];

  late String _query;
  late String? _selectedProductName;
  late String _quantity;
  late String _unit;
  late String _category;
  late String _note;
  late bool _showDetails;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _query = item?.name ?? widget.initialName;
    _selectedProductName = item?.name;
    _quantity = _formatQuantity(item?.quantity ?? 1);
    _unit = item?.unit ?? 'Stk.';
    _category = item?.category ??
        widget.initialCategory ??
        'Sonstiges';
    _note = item?.note ?? '';
    _showDetails = _isEditing;
  }

  List<ProductSuggestion> get _matchingSuggestions {
    final normalizedQuery = _query.trim().toLowerCase();

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

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toString().replaceAll('.', ',');
  }

  void _continueWithCurrentQuery() {
    final cleanedQuery = _query.trim();

    if (cleanedQuery.isEmpty) {
      return;
    }

    final exactSuggestion = _suggestionForName(cleanedQuery);

    setState(() {
      _selectedProductName = cleanedQuery;

      if (exactSuggestion != null) {
        _category = exactSuggestion.category;
      }

      _showDetails = true;
    });
  }

  void _selectSuggestion(ProductSuggestion suggestion) {
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedProductName = suggestion.name;
      _query = suggestion.name;
      _category = suggestion.category;
      _showDetails = true;
    });
  }

  void _save() {
    final cleanedName =
    (_selectedProductName ?? _query).trim();

    final parsedQuantity = double.tryParse(
      _quantity.trim().replaceAll(',', '.'),
    );

    if (cleanedName.isEmpty ||
        parsedQuantity == null ||
        parsedQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte gib einen gültigen Namen und eine Menge größer als 0 ein.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      ShoppingItemSheetResult(
        name: cleanedName,
        quantity: parsedQuantity,
        unit: _unit,
        category: _category,
        note: _note.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                _buildDragHandle(context),
                const SizedBox(height: 20),
                _buildHeader(context),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(
                      Icons.list_alt,
                      size: 18,
                    ),
                    label: Text(
                      'Liste: ${widget.listName}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_showDetails)
                  _buildDetailsStep(context)
                else
                  _buildSearchStep(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _isEditing
                ? 'Artikel bearbeiten'
                : _showDetails
                ? 'Details festlegen'
                : 'Artikel hinzufügen',
            style: Theme.of(context).textTheme.headlineSmall,
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
    );
  }

  Widget _buildSearchStep(BuildContext context) {
    final suggestions = _matchingSuggestions;

    return Column(
      children: [
        TextFormField(
          key: const ValueKey('product-search'),
          initialValue: _query,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Artikel suchen',
            hintText: 'z. B. Milch',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _query = value;
            });
          },
          onFieldSubmitted: (_) {
            _continueWithCurrentQuery();
          },
        ),
        const SizedBox(height: 18),
        if (_query.trim().isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Gib einen Artikelnamen ein, um passende Produkte zu sehen.',
              textAlign: TextAlign.center,
            ),
          )
        else if (suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Kein passendes Produkt gefunden.\n'
                  'Du kannst „${_query.trim()}“ trotzdem hinzufügen.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Passende Produkte',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: suggestions.map((suggestion) {
                return OutlinedButton(
                  onPressed: () {
                    _selectSuggestion(suggestion);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        suggestion.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        suggestion.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
            onPressed: _query.trim().isEmpty
                ? null
                : _continueWithCurrentQuery,
            child: const Text('Weiter'),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep(BuildContext context) {
    final productName = _selectedProductName ?? _query;

    return Column(
      children: [
        Row(
          children: [
            Text(
              _suggestionForName(productName)?.emoji ?? '🛒',
              style: const TextStyle(fontSize: 38),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                productName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('quantity'),
                initialValue: _quantity,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Menge',
                ),
                onChanged: (value) {
                  _quantity = value;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _unit,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Einheit',
                ),
                items: _units.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _unit = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _category,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Kategorie',
          ),
          items: widget.categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _category = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('note'),
          initialValue: _note,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notiz',
            hintText: 'z. B. laktosefrei',
          ),
          onChanged: (value) {
            _note = value;
          },
        ),
        if (!_isEditing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showDetails = false;
                _selectedProductName = null;
              });
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text(
              'Anderen Artikel wählen',
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _save,
            child: const Text('Speichern'),
          ),
        ),
      ],
    );
  }
}
