import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'default_product_suggestions.dart';
import 'shopping_history_entry.dart';
import 'shopping_item.dart';
import 'shopping_list.dart';
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

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

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

    final weekday = weekdays[localDate.weekday - 1];
    final month = months[localDate.month - 1];

    return '$weekday, ${localDate.day}. $month ${localDate.year}';
  }

  String _formatTime(DateTime date) {
    final localDate = date.toLocal();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

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

  String _generateId() {
    final random = math.Random();

    return '${DateTime.now().millisecondsSinceEpoch}'
        '${random.nextInt(999999)}';
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
                'wird dauerhaft aus der Historie entfernt.',
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
      ScaffoldMessenger.of(context).showSnackBar(
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

    final result = await showModalBottomSheet<_HistoryRestoreResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
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
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .outline,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Einkauf erneut hinzufügen',
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${entry.itemCount} Artikel werden als offene '
                          'Artikel zu einer Einkaufsliste hinzugefügt.',
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: selectedListId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Einkaufsliste',
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
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
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

        return Padding(
          padding: EdgeInsets.only(
            bottom: mediaQuery.viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: mediaQuery.size.height * 0.88,
              ),
              decoration: BoxDecoration(
                color: Theme.of(sheetContext)
                    .colorScheme
                    .surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .outline,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      12,
                      12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(entry.completedAt),
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(entry.completedAt),
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
                        24,
                      ),
                      children: [
                        _buildSummaryCard(
                          entry,
                        ),
                        const SizedBox(height: 16),
                        ..._buildGroupedHistoryItems(
                          sheetContext,
                          entry.items,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _addEntryToList(entry);
                            },
                            icon: const Icon(
                              Icons.playlist_add,
                            ),
                            label: const Text(
                              'Einkauf erneut hinzufügen',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
      ShoppingHistoryEntry entry,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${entry.itemCount} Artikel',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (entry.hasTotalAmount)
                  Text(
                    _formatCurrency(entry.totalAmount!),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            if (entry.sourceListNames.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.list_alt,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.sourceListNames.join(', '),
                    ),
                  ),
                ],
              ),
            ],
            if (entry.storeName != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(
                    Icons.store_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(entry.storeName!),
                  ),
                ],
              ),
            ],
            if (entry.note.trim().isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(entry.note),
                  ),
                ],
              ),
            ],
          ],
        ),
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
              (a, b) => a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          ),
        );

      return [
        Padding(
          padding: const EdgeInsets.only(
            top: 10,
            bottom: 6,
          ),
          child: Text(
            category,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...categoryItems.map(
              (item) => Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Text(
                _emojiForItem(item),
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(item.name),
              subtitle: Text(
                '${_formatQuantity(item.quantity)} ${item.unit}'
                    '${item.note.trim().isEmpty ? '' : ' • ${item.note}'}'
                    '${item.sourceListName.trim().isEmpty ? '' : '\nListe: ${item.sourceListName}'}',
              ),
              isThreeLine:
              item.sourceListName.trim().isNotEmpty,
              trailing: item.totalPrice == null
                  ? null
                  : Text(
                _formatCurrency(item.totalPrice!),
              ),
            ),
          ),
        ),
      ];
    }).toList();
  }

  Widget _buildHistoryCard(
      ShoppingHistoryEntry entry,
      ) {
    final sourceNames = entry.sourceListNames.isEmpty
        ? 'Keine Listenangabe'
        : entry.sourceListNames.join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          _showEntryDetails(entry);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(entry.completedAt),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_formatTime(entry.completedAt)} '
                              '• ${entry.itemCount} Artikel',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<_HistoryAction>(
                    onSelected: (action) {
                      if (action ==
                          _HistoryAction.restore) {
                        _addEntryToList(entry);
                      } else if (action ==
                          _HistoryAction.delete) {
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
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.list_alt,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sourceNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entry.hasTotalAmount) ...[
                    const SizedBox(width: 12),
                    Text(
                      _formatCurrency(entry.totalAmount!),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.history,
          size: 72,
          color: Theme.of(context)
              .colorScheme
              .outline,
        ),
        const SizedBox(height: 20),
        Text(
          'Noch keine Einkäufe',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        const Text(
          'Abgeschlossene Einkäufe erscheinen hier '
              'mit allen Artikeln und beteiligten Listen.',
          textAlign: TextAlign.center,
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
            IconButton(
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Historie leeren',
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
            : ListView.builder(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            40,
          ),
          itemCount: _history.length,
          itemBuilder: (context, index) {
            return _buildHistoryCard(
              _history[index],
            );
          },
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
