import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'default_product_suggestions.dart';
import 'shopping_history_entry.dart';
import 'shopping_service.dart';

class ShoppingHistoryScreen extends StatefulWidget {
  const ShoppingHistoryScreen({super.key});

  @override
  State<ShoppingHistoryScreen> createState() =>
      _ShoppingHistoryScreenState();
}

class _ShoppingHistoryScreenState
    extends State<ShoppingHistoryScreen> {
  final ShoppingService _service = ShoppingService();

  List<ShoppingHistoryEntry> _history = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    final history = await _service.loadHistory();

    if (!mounted) return;

    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  String _generateId() {
    final random = math.Random();

    return '${DateTime.now().millisecondsSinceEpoch}'
        '${random.nextInt(999999)}';
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    const weekdays = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];

    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];

    return '${weekdays[local.weekday - 1]}, '
        '${local.day}. ${months[local.month - 1]} '
        '${local.year}';
  }

  String _formatTime(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute Uhr';
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }

    return quantity.toString().replaceAll('.', ',');
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  String _emojiForItem(ShoppingHistoryItem item) {
    final normalizedName = item.name.trim().toLowerCase();

    for (final suggestion in defaultProductSuggestions) {
      if (suggestion.name.toLowerCase() == normalizedName) {
        return suggestion.emoji;
      }
    }

    return '🛒';
  }

  Future<void> _deleteEntry(
      ShoppingHistoryEntry entry,
      ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Einkauf löschen?'),
          content: Text(
            'Der Einkauf vom ${_formatDate(entry.completedAt)} '
                'wird dauerhaft entfernt.',
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
      _history.removeWhere(
            (historyEntry) => historyEntry.id == entry.id,
      );
    });

    await _service.deleteHistoryEntry(entry.id);
  }

  Future<void> _clearHistory() async {
    if (_history.isEmpty) {
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Historie leeren?'),
          content: const Text(
            'Alle abgeschlossenen Einkäufe werden dauerhaft gelöscht.',
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
              child: const Text('Alles löschen'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true || !mounted) {
      return;
    }

    setState(() {
      _history = [];
    });

    await _service.clearHistory();
  }

  Future<void> _addEntryToList(
      ShoppingHistoryEntry entry,
      ) async {
    final lists = await _service.loadLists();

    if (!mounted) return;

    if (lists.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Erstelle zuerst eine Einkaufsliste.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }

    String selectedListId = lists.first.id;

    final result =
    await showModalBottomSheet<_HistoryRestoreResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
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
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                            colorScheme.primaryContainer,
                            borderRadius:
                            BorderRadius.circular(17),
                          ),
                          child: const Icon(
                            Icons.playlist_add,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Einkauf erneut hinzufügen',
                                style: theme
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${entry.itemCount} Artikel '
                                    'werden wieder geöffnet.',
                                style: theme
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color: colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme
                            .surfaceContainerHighest,
                        borderRadius:
                        BorderRadius.circular(22),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedListId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Einkaufsliste',
                          border: InputBorder.none,
                        ),
                        items: lists.map((list) {
                          return DropdownMenuItem(
                            value: list.id,
                            child: Text(
                              list.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setSheetState(() {
                            selectedListId = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop(
                            _HistoryRestoreResult(
                              listId: selectedListId,
                            ),
                          );
                        },
                        icon: const Icon(Icons.playlist_add),
                        label: const Text(
                          'Alle Artikel hinzufügen',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final targetListIndex = lists.indexWhere(
          (list) => list.id == result.listId,
    );

    if (targetListIndex == -1) {
      return;
    }

    final targetList = lists[targetListIndex];

    setState(() {
      _isSaving = true;
    });

    for (final historyItem in entry.items) {
      targetList.items.add(
        historyItem.toShoppingItem(
          newId: _generateId(),
          favorite: historyItem.favorite,
        ),
      );
    }

    await _service.saveLists(lists);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${entry.itemCount} Artikel wurden zu '
                '„${targetList.name}“ hinzugefügt.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _showEntryDetails(
      ShoppingHistoryEntry entry,
      ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;

        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    20,
                    12,
                    14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color:
                          colorScheme.primaryContainer,
                          borderRadius:
                          BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(entry.completedAt),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_formatTime(entry.completedAt)} '
                                  '• ${entry.itemCount} Artikel',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      20,
                    ),
                    children: [
                      _buildSummaryCard(
                        sheetContext,
                        entry,
                      ),
                      const SizedBox(height: 16),
                      ..._buildGroupedHistoryItems(
                        sheetContext,
                        entry.items,
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(
                    20,
                    10,
                    20,
                    16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _addEntryToList(entry);
                      },
                      icon: const Icon(Icons.playlist_add),
                      label: const Text(
                        'Einkauf erneut hinzufügen',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
      BuildContext context,
      ShoppingHistoryEntry entry,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryStat(
                  context,
                  icon: Icons.shopping_basket_outlined,
                  value: '${entry.itemCount}',
                  label: 'Artikel',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryStat(
                  context,
                  icon: Icons.list_alt,
                  value:
                  '${entry.sourceListNames.length}',
                  label: 'Listen',
                ),
              ),
              if (entry.hasTotalAmount) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryStat(
                    context,
                    icon: Icons.euro,
                    value: _formatCurrency(
                      entry.totalAmount!,
                    ),
                    label: 'Gesamt',
                  ),
                ),
              ],
            ],
          ),
          if (entry.sourceListNames.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.list_alt,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.sourceListNames.join(', '),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (entry.storeName != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.store_outlined,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(entry.storeName!),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStat(
      BuildContext context, {
        required IconData icon,
        required String value,
        required String label,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
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

  List<Widget> _buildGroupedHistoryItems(
      BuildContext context,
      List<ShoppingHistoryItem> items,
      ) {
    final groupedItems =
    <String, List<ShoppingHistoryItem>>{};

    for (final item in items) {
      groupedItems.putIfAbsent(
        item.category,
            () => [],
      );

      groupedItems[item.category]!.add(item);
    }

    final categories = groupedItems.keys.toList()..sort();

    return categories.expand((category) {
      final categoryItems = groupedItems[category]!
        ..sort(
              (a, b) => a.name
              .toLowerCase()
              .compareTo(b.name.toLowerCase()),
        );

      return [
        Padding(
          padding: const EdgeInsets.only(
            top: 10,
            bottom: 7,
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
        ...categoryItems.map(
              (item) => _buildHistoryItemCard(
            context,
            item,
          ),
        ),
      ];
    }).toList();
  }

  Widget _buildHistoryItemCard(
      BuildContext context,
      ShoppingHistoryItem item,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final quantity =
        '${_formatQuantity(item.quantity)} ${item.unit}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
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
                  Text(
                    item.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.note.trim().isEmpty
                        ? quantity
                        : '$quantity • ${item.note}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(
                      color:
                      colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.sourceListName
                      .trim()
                      .isNotEmpty) ...[
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
                            item.sourceListName,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (item.totalPrice != null)
              Text(
                _formatCurrency(item.totalPrice!),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
      ShoppingHistoryEntry entry,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sourceNames = entry.sourceListNames.isEmpty
        ? 'Keine Listenangabe'
        : entry.sourceListNames.join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            _showEntryDetails(entry);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              8,
              16,
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    color:
                    colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(entry.completedAt),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTime(entry.completedAt)} '
                            '• ${entry.itemCount} Artikel',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(
                          color:
                          colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.list_alt,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              sourceNames,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: theme
                                  .textTheme
                                  .bodySmall
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
                if (entry.hasTotalAmount)
                  Padding(
                    padding:
                    const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatCurrency(
                        entry.totalAmount!,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                PopupMenuButton<_HistoryAction>(
                  tooltip: 'Optionen',
                  onSelected: (action) {
                    if (action ==
                        _HistoryAction.restore) {
                      _addEntryToList(entry);
                    } else {
                      _deleteEntry(entry);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _HistoryAction.restore,
                      child: Row(
                        children: [
                          Icon(Icons.playlist_add),
                          SizedBox(width: 12),
                          Text('Erneut hinzufügen'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _HistoryAction.delete,
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

  Widget _buildHeaderCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalItems = _history.fold<int>(
      0,
          (sum, entry) => sum + entry.itemCount,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.history_rounded),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '${_history.length} Einkäufe',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalItems gekaufte Artikel gespeichert',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(
                    color:
                    colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu laden',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.history_rounded,
            size: 38,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Noch keine Einkäufe',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall
              ?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Abgeschlossene Einkäufe erscheinen hier '
              'mit allen Artikeln und Listen.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkaufshistorie'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 12),
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
          if (_history.isNotEmpty)
            PopupMenuButton<_HistoryMenuAction>(
              onSelected: (action) {
                if (action ==
                    _HistoryMenuAction.clear) {
                  _clearHistory();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _HistoryMenuAction.clear,
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined),
                      SizedBox(width: 12),
                      Text('Historie leeren'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadHistory,
        child: _history.isEmpty
            ? _buildEmptyState()
            : ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            36,
          ),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 18),
            ..._history.map(
              _buildHistoryCard,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRestoreResult {
  const _HistoryRestoreResult({
    required this.listId,
  });

  final String listId;
}

enum _HistoryAction {
  restore,
  delete,
}

enum _HistoryMenuAction {
  clear,
}
