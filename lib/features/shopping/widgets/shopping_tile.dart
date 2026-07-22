import 'package:flutter/material.dart';

import '../shopping_item.dart';

class ShoppingTile extends StatelessWidget {
  const ShoppingTile({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
    required this.onFavorite,
  });

  final ShoppingItem item;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            item.favorite ? Icons.star : Icons.star_border,
            color: item.favorite ? Colors.amber : Colors.grey,
          ),
          onPressed: onFavorite,
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration:
            item.done ? TextDecoration.lineThrough : TextDecoration.none,
            fontWeight:
            item.favorite ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          "${item.quantity} ${item.unit} • ${item.category}",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: item.done,
              onChanged: onChanged,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}