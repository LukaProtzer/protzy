import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shopping_list.dart';
import 'shopping_list_mode_screen.dart';
import 'shopping_service.dart';

class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen> {
  final ShoppingService _service = ShoppingService();

  List<ShoppingList> _lists = [];
  bool _isLoading = true;
  bool _hasOpenedInitialList = false;

  @override
  void initState() {
    super.initState();
    _loadLists(openInitialList: true);
  }

  Future<void> _loadLists({
    bool openInitialList = false,
  }) async {
    final lists = await _service.loadLists();

    if (!mounted) return;

    setState(() {
      _lists = lists;
      _isLoading = false;
    });

    if (openInitialList &&
        !_hasOpenedInitialList &&
        lists.isNotEmpty) {
      _hasOpenedInitialList = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _openList(lists.first);
      });
    }
  }

  String _generateId() {
    final random = math.Random();

    return '${DateTime.now().millisecondsSinceEpoch}'
        '${random.nextInt(999999)}';
  }

  Future<void> _showListDialog([
    ShoppingList? list,
  ]) async {
    var name = list?.name ?? '';
    final isNewList = list == null;

    final wasSaved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isNewList
                ? 'Neue Einkaufsliste'
                : 'Liste umbenennen',
          ),
          content: TextFormField(
            initialValue: name,
            autofocus: true,
            textCapitalization:
            TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name der Liste',
              hintText: 'z. B. Wocheneinkauf',
            ),
            onChanged: (value) {
              name = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final cleanedName = name.trim();

                if (cleanedName.isEmpty) {
                  return;
                }

                final lists =
                await _service.loadLists();

                if (isNewList) {
                  lists.add(
                    ShoppingList(
                      id: _generateId(),
                      name: cleanedName,
                    ),
                  );
                } else {
                  final index = lists.indexWhere(
                        (shoppingList) =>
                    shoppingList.id == list.id,
                  );

                  if (index != -1) {
                    lists[index].name = cleanedName;
                  }
                }

                await _service.saveLists(lists);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    if (wasSaved == true) {
      await _loadLists();
    }
  }

  Future<void> _deleteList(
      ShoppingList list,
      ) async {
    if (_lists.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mindestens eine Einkaufsliste muss bestehen bleiben.',
          ),
        ),
      );

      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Einkaufsliste löschen?',
          ),
          content: Text(
            '„${list.name}“ und alle enthaltenen Artikel '
                'werden gelöscht.',
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

    if (shouldDelete != true) return;

    final lists = await _service.loadLists();

    lists.removeWhere(
          (shoppingList) => shoppingList.id == list.id,
    );

    await _service.saveLists(lists);
    await _loadLists();
  }

  Future<void> _openList(
      ShoppingList list,
      ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingListModeScreen(
          listId: list.id,
          listName: list.name,
        ),
      ),
    );

    await _loadLists();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkaufslisten'),
      ),
      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: () => _showListDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Neue Liste'),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadLists,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            110,
          ),
          children: [
            Text(
              'Wähle eine Liste für deinen Einkauf.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 12),
            ..._lists.map((list) {
              final openItems = list.items
                  .where((item) => !item.done)
                  .length;

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  onTap: () => _openList(list),
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons.shopping_cart_outlined,
                    ),
                  ),
                  title: Text(
                    list.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '$openItems offene '
                        '${openItems == 1 ? 'Sache' : 'Sachen'}',
                  ),
                  trailing:
                  PopupMenuButton<_ListAction>(
                    tooltip: 'Optionen',
                    onSelected: (action) {
                      switch (action) {
                        case _ListAction.rename:
                          _showListDialog(list);
                        case _ListAction.delete:
                          _deleteList(list);
                      }
                    },
                    itemBuilder: (context) =>
                    const [
                      PopupMenuItem(
                        value:
                        _ListAction.rename,
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                            ),
                            SizedBox(width: 12),
                            Text('Umbenennen'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value:
                        _ListAction.delete,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                            ),
                            SizedBox(width: 12),
                            Text('Löschen'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

enum _ListAction {
  rename,
  delete,
}