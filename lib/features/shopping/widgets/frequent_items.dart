import 'package:flutter/material.dart';

import '../shopping_item.dart';

class FrequentItems extends StatelessWidget {
  const FrequentItems({
    super.key,
    required this.items,
    required this.onTap,
  });

  final List<ShoppingItem> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final frequent = [...items]
      ..removeWhere((item) => item.purchaseCount == 0)
      ..sort(
            (a, b) => b.purchaseCount.compareTo(a.purchaseCount),
      );

    final topItems = frequent.take(8).toList();

    if (topItems.isEmpty) {
      return const Text(
        "Noch keine häufig gekauften Artikel vorhanden.",
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: topItems.map((item) {
        return ActionChip(
          avatar: const Icon(Icons.history),
          label: Text(
            "${item.name} (${item.purchaseCount}×)",
          ),
          onPressed: () => onTap(item.name),
        );
      }).toList(),
    );
  }
}